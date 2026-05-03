# AFClone

Forensic disk imaging live distro powered by ArchLinux.  
Boot from USB, image any drive, verify the hash — nothing more.

---

## Editions

| | Nano | Standard |
|---|---|---|
| Target RAM | 256–512 MB | ≤ 1024 MB |
| Output formats | EWF/E01, AFF4, Raw/DD | same |
| Destination | USB / local storage | + SFTP, NFS, iSCSI, S3, NBD |
| Network | SSH (management only) | Full wired + wireless |
| Shell | bash + vim + mc | same |
| Architecture | x86 / x86_64 | x86 / x86_64 |

**Supported source media:** NVMe, SATA, SAS, eMMC, NAND Flash (MTD), RAID (software md + hardware dmraid), UFS

**All storage devices are write-protected on boot.** Only the user-selected output device is unlocked, and only for the duration of the imaging session.

---

## How it works

1. Boot from USB (BIOS or UEFI, x86 or x86_64)
2. All storage devices are set read-only by `afclone-writeblock.service`
3. The AFClone TUI launches automatically on TTY1
4. Select source, destination, format, and enter case metadata
5. The engine hashes the source, images it, verifies, and writes a JSON case log
6. Output device is re-locked after the session

---

## Build

Requires Docker.

```bash
# Build Nano edition
make nano

# Build Standard edition
make standard

# Build both
make all

# Smoke-test without KVM (checks that key binaries are present in the ISO)
make smoke-nano
make smoke-standard

# Clean output
make clean
```

ISOs land in `out/nano/` and `out/standard/`.

Override the builder image:
```bash
MKARCHISO_IMAGE=myregistry/mkarchiso:tag make nano
```

---

## Repository layout

```
profiles/
  nano/           Nano edition ArchISO profile
  standard/       Standard edition ArchISO profile (superset of Nano)
  local-repo/     Local pacman repo for AFF4 and other AUR packages
afclone/          Original single-edition profile (kept as reference)
Makefile
```

---

## Case log

Every imaging session produces a JSON log alongside the image:

```json
{
  "examiner": "Jane Doe",
  "case_number": "CASE-2024-001",
  "evidence_number": "EVID-001",
  "acquisition_start": "2024-01-15T09:00:00+00:00",
  "acquisition_end":   "2024-01-15T09:47:13+00:00",
  "source_device": "/dev/nvme0n1",
  "source_size_bytes": 256060514304,
  "source_model": "Samsung SSD 980",
  "source_serial": "S5GXNX0T123456",
  "image_format": "ewf",
  "image_path": "/mnt/usb/CASE-2024-001_20240115_090000.E01",
  "hash_sha256_source": "a3f5...",
  "hash_sha256_image":  "a3f5...",
  "hash_md5_source":    "d41d...",
  "hash_md5_image":     "d41d...",
  "verified": true
}
```

---

## License

MIT — Copyright 2023 Sergey Golub / leitosama
