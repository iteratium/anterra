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
