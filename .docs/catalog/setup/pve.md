# pve — Manual Setup

This is a one time setup and everything else is built on top of this.

## ZFS Storage Pools

Changes made via Proxmox web UI.

`Disks` → `ZFS` → `Create: ZFS`.

### fast-store
- RAID Level: `Single Disk`
- Disk: Samsung SSD 860 EVO 1TB (serial `S4BDNE0M203600A`)
- Compression: `lz4`
- ashift: `12`
- mountpoint `/fast-store`

### bulk-store
- RAID Level: `Mirror`
- Disks: 2x Seagate One Touch 5TB USB (serials `NABV35F2`, `NABVCTAZ`)
- Compression: `lz4`
- ashift: `12`
- mountpoint `/bulk-store`

**`ashift`**: Sets the pool's assumed sector size (2^12 = 4K) and can't be changed after creation, 12 is correct for both the SSD and the USB HDDs, avoiding read-modify-write penalties. 
**`lz4`**: is the standard OpenZFS default: negligible cost on incompressible data (media) via early-abort, free savings on anything compressible, and fewer bytes written overall.

## Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --ssh --accept-routes=false
```

**`--accept-routes=false`**: rpi already manages this, setting accept-routes on this machine causes it to conflict with IP assignments.

## Terraform IaC User

`pve` (node) → `Datacenter` → `Permissions`, done by hand via the web UI.

**User**: `terraform@pve`, realm `pve` (`pam` is not required as this account does not need interactive login).

**Permissions** `Datacenter` → `Permissions` → `Add` → `User Permission`, scoped to least privilege rather than a single blanket role:

| Path | Role |
|---|---|
| `/vms` | `PVEVMAdmin` |
| `/storage/fast-store` | `PVEDatastoreUser` |
| `/storage/bulk-store` | `PVEDatastoreUser` |
| `/mapping/pci/intel-igpu` | `PVEMappingUser` |

**API token**: `terraform@pve!terraform-gh`, created via `Datacenter` → `Permissions` → `API Tokens`, with **Privilege Separation unchecked** 
The token inherits the user's ACL entries above directly instead of needing its own separate grants. Token secret lives only in GitHub Actions secrets.

## Cloud-Init Template (VM 9000)

Golden image for Terraform to clone: Everything specific to an actual VM (extra disks, real memory/CPU sizing, `hostpci` for `intel-igpu`, cloud-init user-data) is layered on by Terraform at clone time.

- Base image: Ubuntu 26.04 LTS "Resolute Raccoon", minimal cloud image (`ubuntu-26.04-minimal-cloudimg-amd64.img` from `cloud-images.ubuntu.com/minimal/releases/resolute/release/`)
- `--bios ovmf` — this image is UEFI/GPT-only, no legacy BIOS boot support
- `--machine q35` — not the Proxmox default `i440fx`; `q35` gives proper PCIe topology, which matters for `intel-igpu` passthrough on VMs cloned from this template
- `efidisk0` on `fast-store`, `pre-enrolled-keys=0` (Secure Boot key enrollment skipped — boot chain is managed via cloud-init, not signed images)
- Single OS disk on `fast-store`; `bulk-store` added per-VM by Terraform, not part of the shared template
- Built via `qm create`/`qm importdisk`/`qm template` over SSH, VMID `9000`
