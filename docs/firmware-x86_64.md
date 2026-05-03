# Firmware selection — x86_64

AFClone uses targeted firmware split-packages instead of the `linux-firmware`
meta-package. Since June 2025 (`linux-firmware ≥ 20250613.12fe085f-5`) the
meta-package pulls in everything including GPU, ARM, and audio firmware blobs
that are irrelevant on a forensic imager.

## Included packages

| Category | Firmware needed? | Package |
|----------|-----------------|---------|
| NVMe | No blobs — in-kernel driver | — |
| SATA / AHCI | No blobs — in-kernel driver | — |
| SAS HBAs (mpt3sas, megaraid_sas) | Occasionally | `linux-firmware-other` |
| Intel NICs (e1000e, i40e, igc) | Yes — SSH management | `linux-firmware-intel` |
| Broadcom NICs (bnx2, tg3) | Yes | `linux-firmware-broadcom` |
| Realtek NICs | Yes | `linux-firmware-realtek` |
| Marvell NICs | Yes | `linux-firmware-marvell` |
| Mellanox NICs (mlx5 — enterprise) | Yes | `linux-firmware-mellanox` |
| WHENCE license file | Required by all above | `linux-firmware-whence` |

## Excluded packages

| Category | Reason excluded |
|----------|----------------|
| `linux-firmware-amdgpu` / `linux-firmware-radeon` | GPU — not needed |
| `linux-firmware-nvidia` | GPU — not needed |
| `linux-firmware-qcom` | Qualcomm / ARM-only |
| `linux-firmware-cirrus` | Audio — not needed |
| `linux-firmware-liquidio` | Specialized NIC, niche |

## Standard edition only (wireless)

| Category | Package |
|----------|---------|
| Atheros WiFi | `linux-firmware-atheros` |
| MediaTek WiFi | `linux-firmware-mediatek` |
| Broadcom WiFi | included in `linux-firmware-broadcom` |

## Adding hardware support

If a specific NIC or storage controller is missing firmware at boot, identify
the kernel module with `dmesg | grep firmware` and add the corresponding
split package to the relevant `packages.x86_64`. Do not revert to the
meta-package — add only the specific package needed.
