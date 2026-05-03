# AFClone build system
# Requires Docker with the leitosama/mkarchiso image (or local mkarchiso).
#
# Targets:
#   make nano          Build the Nano edition ISO
#   make standard      Build the Standard edition ISO
#   make all           Build both editions
#   make aff4-pkg      Build the AFF4 package into profiles/local-repo/
#   make smoke-nano    Smoke-test the Nano ISO (no KVM needed)
#   make smoke-standard Smoke-test the Standard ISO (no KVM needed)
#   make clean         Remove out/

MKARCHISO_IMAGE ?= leitosama/mkarchiso:latest
OUT_DIR         := out
PROFILES_DIR    := profiles
LOCAL_REPO      := $(PROFILES_DIR)/local-repo

DOCKER_RUN = docker run --privileged --rm \
	-v "$(CURDIR)/$(LOCAL_REPO)":/local-repo \
	-v "$(CURDIR)/$(OUT_DIR)/$(1)":/out

.PHONY: all nano standard aff4-pkg smoke-nano smoke-standard clean pull

all: nano standard

# ── Pull latest builder image ─────────────────────────────────────────────────
pull:
	docker pull $(MKARCHISO_IMAGE)

# ── AFF4 package ──────────────────────────────────────────────────────────────
# Builds aff4l (lightweight AFF4 implementation) and stores .pkg.tar.zst in
# profiles/local-repo/ so both edition pacman.conf files can install it.
aff4-pkg: $(LOCAL_REPO)/aff4l.built

$(LOCAL_REPO)/aff4l.built:
	@echo "==> Building AFF4 package..."
	@mkdir -p $(LOCAL_REPO)
	docker run --rm \
		-v "$(CURDIR)/$(LOCAL_REPO)":/repo \
		-w /tmp \
		archlinux:latest \
		bash -c "\
			pacman -Sy --noconfirm base-devel git cmake openssl zlib libuuid && \
			git clone --depth 1 https://github.com/Velocidex/c-aff4.git && \
			cd c-aff4 && \
			cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr . && \
			make -j\$$(nproc) && \
			make DESTDIR=/tmp/aff4-pkg install && \
			tar -C /tmp/aff4-pkg -czf /repo/aff4l.tar.gz . && \
			repo-add /repo/afclone-local.db.tar.gz /repo/aff4l.tar.gz 2>/dev/null || true \
		"
	@touch $(LOCAL_REPO)/aff4l.built
	@echo "==> AFF4 package ready in $(LOCAL_REPO)/"

# ── ISO builds ────────────────────────────────────────────────────────────────
nano: pull
	@echo "==> Building AFClone Nano..."
	@mkdir -p $(OUT_DIR)/nano
	docker run --privileged --rm \
		-v "$(CURDIR)/$(PROFILES_DIR)/nano":/profile \
		-v "$(CURDIR)/$(LOCAL_REPO)":/profile/local-repo \
		-v "$(CURDIR)/$(OUT_DIR)/nano":/out \
		$(MKARCHISO_IMAGE)
	@echo "==> Nano ISO ready: $(OUT_DIR)/nano/"

standard: pull
	@echo "==> Building AFClone Standard..."
	@mkdir -p $(OUT_DIR)/standard
	docker run --privileged --rm \
		-v "$(CURDIR)/$(PROFILES_DIR)/standard":/profile \
		-v "$(CURDIR)/$(LOCAL_REPO)":/profile/local-repo \
		-v "$(CURDIR)/$(OUT_DIR)/standard":/out \
		$(MKARCHISO_IMAGE)
	@echo "==> Standard ISO ready: $(OUT_DIR)/standard/"

# ── Smoke tests (no KVM required) ─────────────────────────────────────────────
# Unsquashfs the airootfs and verify that key binaries are present.
smoke-nano: $(OUT_DIR)/nano
	@echo "==> Smoke-testing Nano ISO..."
	@iso=$$(ls $(OUT_DIR)/nano/AFClone-Nano-*.iso 2>/dev/null | head -1); \
	[ -n "$$iso" ] || { echo "ERROR: No Nano ISO found in $(OUT_DIR)/nano/"; exit 1; }; \
	tmp=$$(mktemp -d /tmp/afclone-smoke-XXXXXX); \
	7z x "$$iso" -o"$$tmp/iso" arch/x86_64/airootfs.sfs >/dev/null 2>&1 || \
		isoinfo -R -i "$$iso" -x /arch/x86_64/airootfs.sfs > "$$tmp/airootfs.sfs" 2>/dev/null; \
	sfs=$$(find "$$tmp" -name airootfs.sfs | head -1); \
	unsquashfs -d "$$tmp/fs" "$$sfs" >/dev/null 2>&1; \
	echo "Checking binaries..."; \
	for bin in \
		usr/local/bin/afclone \
		usr/local/bin/afclone-engine \
		usr/local/bin/afclone-writeblock \
		usr/bin/ewfacquire \
		usr/bin/ddrescue \
		usr/bin/nvme \
		usr/sbin/mdadm; \
	do \
		if [ -f "$$tmp/fs/$$bin" ]; then echo "  OK: $$bin"; \
		else echo "  MISSING: $$bin"; fi; \
	done; \
	rm -rf "$$tmp"; \
	echo "==> Smoke test complete."

smoke-standard: $(OUT_DIR)/standard
	@echo "==> Smoke-testing Standard ISO..."
	@iso=$$(ls $(OUT_DIR)/standard/AFClone-Standard-*.iso 2>/dev/null | head -1); \
	[ -n "$$iso" ] || { echo "ERROR: No Standard ISO found in $(OUT_DIR)/standard/"; exit 1; }; \
	tmp=$$(mktemp -d /tmp/afclone-smoke-XXXXXX); \
	sfs=$$(find "$$tmp" -name airootfs.sfs | head -1); \
	7z x "$$iso" -o"$$tmp/iso" arch/x86_64/airootfs.sfs >/dev/null 2>&1 || \
		isoinfo -R -i "$$iso" -x /arch/x86_64/airootfs.sfs > "$$tmp/airootfs.sfs" 2>/dev/null; \
	sfs=$$(find "$$tmp" -name airootfs.sfs | head -1); \
	unsquashfs -d "$$tmp/fs" "$$sfs" >/dev/null 2>&1; \
	echo "Checking binaries..."; \
	for bin in \
		usr/local/bin/afclone \
		usr/local/bin/afclone-engine \
		usr/bin/ewfacquire \
		usr/bin/ddrescue \
		usr/bin/sshfs \
		usr/bin/lftp \
		usr/bin/rsync \
		usr/sbin/iscsiadm; \
	do \
		if [ -f "$$tmp/fs/$$bin" ]; then echo "  OK: $$bin"; \
		else echo "  MISSING: $$bin"; fi; \
	done; \
	rm -rf "$$tmp"; \
	echo "==> Smoke test complete."

# ── Housekeeping ──────────────────────────────────────────────────────────────
clean:
	rm -rf $(OUT_DIR)

help:
	@echo "AFClone build targets:"
	@echo "  make nano           Build Nano edition ISO (target RAM: 256-512 MB)"
	@echo "  make standard       Build Standard edition ISO (target RAM: <=1024 MB)"
	@echo "  make all            Build both editions"
	@echo "  make aff4-pkg       Pre-build AFF4 package for inclusion"
	@echo "  make smoke-nano     Verify Nano ISO contents (no KVM needed)"
	@echo "  make smoke-standard Verify Standard ISO contents (no KVM needed)"
	@echo "  make clean          Remove build output"
	@echo ""
	@echo "Override image: MKARCHISO_IMAGE=myregistry/mkarchiso:tag make nano"
