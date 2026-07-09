# Servers

## Physical Servers

### India

#### pve - Dell OptiPlex 7060 Micro

Corrected from "3060 Micro" — `dmidecode -t system` reports `Product Name:
OptiPlex 7060`.

- CPU: Intel Core i3-8100T @ 3.10GHz, 4 cores / 4 threads
- RAM: 32 GiB
- OS: Proxmox VE 9.2.4 (Debian 13 "trixie" base), kernel 7.0.14-4-pve
- Boot/OS disk: Samsung MZNTY256HDHP-000L7 256GB SSD (238.5 GiB), LVM —
  `pve-root` 69.2G, `pve-data` thin pool 140.9G
- `fast-store` ZFS pool: Samsung SSD 860 EVO 1TB, single disk (see
  `setup/pve.md`)
- `bulk-store` ZFS pool: 2x Seagate One Touch 5TB USB, mirror (see
  `setup/pve.md`)

#### rpi - Raspberry Pi 4B

- Model: Raspberry Pi 4 Model B Rev 1.4
- CPU: ARM Cortex-A72 (Broadcom BCM2711), 4 cores @ 1.8GHz
- RAM: 8 GiB
- OS: Debian 13 (trixie), kernel 6.12.75+rpt-rpi-v8 (aarch64)
- Storage: Samsung SSD 840 EVO 120GB (111.8 GiB), USB-attached — boots from
  USB SSD, not the SD card slot

## Virtual Servers

### Singapore

#### vps - GreenCloud EPYCSGDC1-1

- CPU: 1 vCPU, AMD EPYC-Milan (virtualized), KVM hypervisor
- RAM: 2 GiB
- OS: Ubuntu 24.04.4 LTS, kernel 6.8.0-134-generic
- Storage: 25 GiB virtual disk (`vda`)