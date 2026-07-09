# Servers

## Physical Servers

#### pve - Dell OptiPlex 7060 Micro - India

- CPU: Intel Core i3-8100T @ 3.10GHz, 4 cores / 4 threads
- RAM: 32 GiB DDR4
- OS: Proxmox VE 9.2.4 (Debian 13 "trixie" base), kernel 7.0.14-4-pve
- Boot/OS disk: Samsung MZNTY256HDHP-000L7 256GB SSD (238.5 GiB)
- NIC: Intel I219-LM [8086:15bb], driver `e1000e`
- GPU: Intel UHD Graphics 630 (integrated)
- `fast-store` ZFS pool: Samsung SSD 860 EVO 1TB, single disk
- `bulk-store` ZFS pool: 2x Seagate One Touch 5TB USB, mirror

#### rpi - Raspberry Pi 4B - India

- Model: Raspberry Pi 4 Model B Rev 1.4
- CPU: ARM Cortex-A72 (Broadcom BCM2711), 4 cores @ 1.8GHz
- RAM: 8 GiB LPDDR4
- OS: Debian 13 (trixie), kernel 6.12.75+rpt-rpi-v8 (aarch64)
- Boot/OS disk: Samsung SSD 840 EVO 120GB (111.8 GiB), USB-attached — boots from USB SSD

## Virtual Servers

#### vps - GreenCloud EPYCSGDC1-1 - Singapore

- CPU: 1 vCPU, AMD EPYC-Milan (virtualized), KVM hypervisor
- RAM: 2 GiB
- OS: Ubuntu 24.04.4 LTS, kernel 6.8.0-134-generic
- Storage: 25 GiB virtual disk (`vda`)