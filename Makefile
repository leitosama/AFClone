# AFClone build system
# Requires Docker with the leitosama/mkarchiso image (or local mkarchiso).
#
# Targets:
#   make nano           Build the Nano edition ISO
#   make standard       Build the Standard edition ISO
#   make all            Build both editions
#   make aff4-pkg       Build the AFF4 package into profiles/local-repo/
#   make smoke-nano     Smoke-test the Nano ISO (no KVM needed)
#   make smoke-standard Smoke-test the Standard ISO (no KVM needed)
#   make clean          Remove out/
#
# AFF4 is optional. Run `make aff4-pkg` before `make nano/standard` to include
# it. Without it the ISO builds fine; AFF4 imaging is simply unavailable.

MKARCHISO_IMAGE ?= leitosama/mkarchiso:latest
OUT_DIR         := out
PROFILES_DIR    := profiles
LOCAL_REPO      := $(PROFILES_DIR)/local-repo

.PHONY: all nano standard aff4-pkg smoke-nano smoke-standard clean pull help

all: nano standard

# ── Pull latest builder image ─────────────────────────────────────────────────
pull:
	docker pull $(MKARCHISO_IMAGE)

# ── Local repo bootstrap ──────────────────────────────────────────────────────
# Create an empty-but-valid pacman db so [afclone-local] in pacman.conf never
# fails, even before `make aff4-pkg` has been run.
$(LOCAL_REPO)/afclone-local.db.tar.gz:
	@mkdir -p $(LOCAL_REPO)
	@tar czf $@ --files-from /dev/null
	@ln -sf afclone-local.db.tar.gz $(LOCAL_REPO)/afclone-local.db

# ── AFF4 package (optional) ───────────────────────────────────────────────────
aff4-pkg: $(LOCAL_REPO)/afclone-local.db.tar.gz
	@echo "==> Building AFF4 package..."
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
			cd /tmp && \
			fakeroot -- tar -C aff4-pkg -czf /repo/aff4l-1.0-1-x86_64.pkg.tar.zst . && \
			repo-add /repo/afclone-local.db.tar.gz /repo/aff4l-1.0-1-x86_64.pkg.tar.zst \
		"
	@echo "==> AFF4 package ready in $(LOCAL_REPO)/"

# ── ISO builds ────────────────────────────────────────────────────────────────
nano: pull $(LOCAL_REPO)/afclone-local.db.tar.gz
	@echo "==> Building AFClone Nano..."
	@mkdir -p $(OUT_DIR)/nano
	docker run --privileged --rm \
		-v "$(CURDIR)/$(PROFILES_DIR)/nano":/profile \
		-v "$(CURDIR)/$(LOCAL_REPO)":/profile/local-repo \
		-v "$(CURDIR)/$(OUT_DIR)/nano":/out \
		$(MKARCHISO_IMAGE)
	@echo "==> Nano ISO ready: $(OUT_DIR)/nano/"

standard: pull $(LOCAL_REPO)/afclone-local.db.tar.gz
	@echo "==> Building AFClone Standard..."
	@mkdir -p $(OUT_DIR)/standard
	docker run --privileged --rm \
		-v "$(CURDIR)/$(PROFILES_DIR)/standard":/profile \
		-v "$(CURDIR)/$(LOCAL_REPO)":/profile/local-repo \
		-v "$(CURDIR)/$(OUT_DIR)/standard":/out \
		$(MKARCHISO_IMAGE)
	@echo "==> Standard ISO ready: $(OUT_DIR)/standard/"

# ── Smoke tests (no KVM required) ─────────────────────────────────────────────
smoke-nano:
	@echo "==> Smoke-testing Nano ISO..."
	@iso=$$(ls $(OUT_DIR)/nano/AFClone-Nano-*.iso 2>/dev/null | head -1); \
	[ -n "$$iso" ] || { echo "ERROR: No Nano ISO found in $(OUT_DIR)/nano/"; exit 1; }; \
	tmp=$$(mktemp -d /tmp/afclone-smoke-XXXXXX); \
	isoinfo -R -i "$$iso" -x /arch/x86_64/airootfs.sfs > "$$tmp/airootfs.sfs" 2>/dev/null; \
	unsquashfs -d "$$tmp/fs" "$$tmp/airootfs.sfs" >/dev/null 2>&1; \
	echo "Checking binaries..."; \
	ok=0; fail=0; \
	for bin in \
		usr/local/bin/afclone \
		usr/local/bin/afclone-engine \
		usr/local/bin/afclone-writeblock \
		usr/bin/ewfacquire \
		usr/bin/ddrescue \
		usr/bin/nvme \
		usr/sbin/mdadm; \
	do \
		if [ -f "$$tmp/fs/$$bin" ]; then echo "  OK: $$bin"; ok=$$((ok+1)); \
		else echo "  MISSING: $$bin"; fail=$$((fail+1)); fi; \
	done; \
	rm -rf "$$tmp"; \
	echo "==> $$ok OK, $$fail missing."; \
	[ $$fail -eq 0 ]

smoke-standard:
	@echo "==> Smoke-testing Standard ISO..."
	@iso=$$(ls $(OUT_DIR)/standard/AFClone-Standard-*.iso 2>/dev/null | head -1); \
	[ -n "$$iso" ] || { echo "ERROR: No Standard ISO found in $(OUT_DIR)/standard/"; exit 1; }; \
	tmp=$$(mktemp -d /tmp/afclone-smoke-XXXXXX); \
	isoinfo -R -i "$$iso" -x /arch/x86_64/airootfs.sfs > "$$tmp/airootfs.sfs" 2>/dev/null; \
	unsquashfs -d "$$tmp/fs" "$$tmp/airootfs.sfs" >/dev/null 2>&1; \
	echo "Checking binaries..."; \
	ok=0; fail=0; \
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
		if [ -f "$$tmp/fs/$$bin" ]; then echo "  OK: $$bin"; ok=$$((ok+1)); \
		else echo "  MISSING: $$bin"; fail=$$((fail+1)); fi; \
	done; \
	rm -rf "$$tmp"; \
	echo "==> $$ok OK, $$fail missing."; \
	[ $$fail -eq 0 ]

# ── Housekeeping ──────────────────────────────────────────────────────────────
clean:
	rm -rf $(OUT_DIR)

help:
	@echo "AFClone build targets:"
	@echo "  make nano           Build Nano edition ISO (target RAM: 256-512 MB)"
	@echo "  make standard       Build Standard edition ISO (target RAM: <=1024 MB)"
	@echo "  make all            Build both editions"
	@echo "  make aff4-pkg       Pre-build AFF4 package (optional, enables AFF4 format)"
	@echo "  make smoke-nano     Verify Nano ISO contents (no KVM needed)"
	@echo "  make smoke-standard Verify Standard ISO contents (no KVM needed)"
	@echo "  make clean          Remove build output"
	@echo ""
	@echo "Override builder: MKARCHISO_IMAGE=myregistry/mkarchiso:tag make nano"
