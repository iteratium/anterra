# pve — Manual Setup

This is a one time setup and everything else is built on top of this.

## ZFS Storage Pools

Host/ZFS-level steps done by hand on the Proxmox web UI.

Both created via `pve` (node) → `Disks` → `ZFS` → `Create: ZFS`.

### fast-store
- RAID Level: `Single Disk`
- Disk: Samsung SSD 860 EVO 1TB (serial `S4BDNE0M203600A`)
- Compression: `lz4`
- ashift: `12`
- Add Storage: checked — registers `zfspool: fast-store` in `storage.cfg`, mountpoint `/fast-store`

### bulk-store
- RAID Level: `Mirror`
- Disks: 2x Seagate One Touch 5TB USB (serials `NABV35F2`, `NABVCTAZ`)
- Compression: `lz4`
- ashift: `12`
- Add Storage: checked — registers `zfspool: bulk-store` in `storage.cfg`, mountpoint `/bulk-store`

If reusing disks that already carry a filesystem/pool signature, wipe each one first (`Disks` → select disk → `Wipe Disk`) or pool creation will fail.

**Why `ashift=12` + `lz4`**: `ashift` sets the pool's assumed sector size (2^12 = 4K) and can't be changed after creation — 12 is correct for both the 512e SSD and the USB HDDs, avoiding read-modify-write penalties. `lz4` is the standard OpenZFS default: negligible cost on incompressible data (media) via early-abort, free savings on anything compressible, and fewer bytes written overall.

## Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --ssh --accept-routes=false
```

No `sudo` needed on `pve`. `--ssh` enables Tailscale SSH (node-identity/ACL-based auth instead of key management) — needed since the planned CI execution model authenticates to fleet hosts this way instead of a stored SSH key.

`--accept-routes=false` is explicit, not just a default — Tailscale refuses to silently drop a previously-set flag on a later `tailscale up`, so it must be restated each time rather than just omitted. It matters here because `rpi` advertises `10.0.0.0/22` (this host's own LAN) as a subnet router; if `pve` accepts that route it conflicts with its own directly-connected LAN route and breaks local LAN reachability (confirmed live: `rpi` lost all LAN connectivity, even ICMP, to `pve` after `--accept-routes` was on, until this flag reset it).

First SSH via Tailscale SSH may require a one-time interactive browser approval (default tailnet `check` mode) — expected, not a hang. See `setup/tailscale.md` for the fleet-wide SSH ACL (`accept` mode, scoped to `group:fleet-admins`) and the key-expiry setting, both admin-console-level and shared across `pve`/`rpi`/`vps`.

Confirm the node joins the tailnet before continuing (`tailscale status`).

## Terraform IaC User

`pve` (node) → `Datacenter` → `Permissions`, done by hand via the web UI.

Replaces a leftover `tofu@pam` user from the pre-rewrite setup, which held the
built-in `Administrator` role at `/` (full admin, propagated everywhere) —
not carried forward; deleted rather than reused.

**User**: `terraform@pve`, realm `pve` (Proxmox's own built-in realm), not
`pam` — this is a pure API-token automation account with no interactive
login, so it doesn't need a backing Unix system account the way a `pam`-realm
user would.

**Permissions** (`Datacenter` → `Permissions` → `Add` → `User Permission`),
scoped to least privilege rather than a single blanket role:

| Path | Role |
|---|---|
| `/vms` | `PVEVMAdmin` |
| `/storage/fast-store` | `PVEDatastoreUser` |
| `/storage/bulk-store` | `PVEDatastoreUser` |
| `/mapping/pci/intel-igpu` | `PVEMappingUser` |

All three roles used here are Proxmox built-ins — no custom role needed.
`PVEMappingUser` (`Mapping.Use`) is granted specifically at
`/mapping/pci/intel-igpu`, not the parent `/mapping/pci` — the permission
check Proxmox actually runs (`PVE::QemuServer`, `PVE::API2::Qemu`) is against
`/mapping/pci/<mapping-name>`, and granting at the parent would hand out
every current and future PCI mapping on this node instead of just this one.
The web UI's path autocomplete only suggests the parent as a preset; the
full per-mapping path has to be typed in manually.

**API token**: `terraform@pve!terraform-gh`, created via `Datacenter` →
`Permissions` → `API Tokens`, with **Privilege Separation unchecked** so the
token inherits the user's ACL entries above directly instead of needing its
own separate grants. Token secret lives only in GitHub Actions secrets
(`PROXMOX_API_TOKEN_ID` / `PROXMOX_API_TOKEN_SECRET`) — never committed or
pasted into chat.
