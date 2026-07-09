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
| `/storage/local` | `PVEDatastoreAdmin` |
| `/mapping/pci/intel-igpu` | `PVEMappingUser` |
| `/sdn/zones/localnetwork/vmbr0` | `SDNUser` (custom) |

`/storage/local` was added after the fact — needed once the mediacenter VM's
cloud-init snippet started uploading to the `local` datastore (see
`plans/mediacenter-vm.md`), missed in the original grant since `local` isn't
one of the two storage pools set up above. `PVEDatastoreAdmin`, not
`PVEDatastoreUser` — snippet upload needs `Datastore.Allocate` (create
volumes), which `PVEDatastoreUser` doesn't grant (that role only covers
`Datastore.AllocateSpace`/`Datastore.Audit`, enough for VM disks on
`fast-store`/`bulk-store` but not for the snippet content type).

`/sdn/zones/localnetwork/vmbr0` was also added after the fact — Proxmox
gates VM network-device attachment behind an `SDN.Use` privilege even for a
plain bridge like `vmbr0`, treating it as an implicit SDN zone
(`localnetwork`). No default role includes `SDN.Use` (not even
`PVEVMAdmin`), so it needs a custom role: `Datacenter` → `Permissions` →
`Roles` → `Create`, name `SDNUser`, single privilege `SDN.Use`.

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
