# Mediacenter VM — Implementation Notes

`terraform/` provisions the `mediacenter` VM (Jellyfin + arr stack) on `pve`;
`terraform-plan.yml`/`terraform-apply.yml` implement the plan-on-PR /
apply-on-merge model (`ci-cd.md`). Applied and working as of 2026-07-09.

## Proxmox provider TLS

`providers.tf` sets `insecure = true` — `pve`'s API uses its default self-signed
cert. Acceptable: `pve` is reachable only over Tailscale, not the public
internet. User confirmed.

## Disk layout

Sizes are `modules/mediacenter/variables.tf` defaults, not hardcoded.

- OS disk (`scsi0`, `efidisk0`, cloud-init drive): `local-lvm`, 100 GB. Off
  `fast-store` so the SSD pool is free for app data; `local-lvm` is
  thin-provisioned, avoiding ZFS refreservation confusion.
- Media disk (`scsi1`): `bulk-store`, 4300 GB.
- App-data disk (`scsi2`): `fast-store`, 850 GB. Attached now though unused, so
  Ansible finds it later.

Size against `zfs list <pool>` `AVAIL`, not `zpool list` free: ZFS reserves
~1/32 of the pool (slop space) and zvols carry creation overhead. 4500 and 900
both failed `out of space`; dropped to 4300 / 850. ZFS zvols are
thick-provisioned by default (`refreservation = volsize`), so `zfs list` `USED`
shows the full declared size on an empty disk — read `REFER` for actual use.

## Cloud-init drive must be SCSI, not IDE

On first apply the VM booted but cloud-init never ran (image-default hostname,
no network, never joined the tailnet). `ds-identify` and cloud-init's datasource
search both run before the kernel enumerates the `ide2` CD-ROM — an upstream
race ([cloud-init#6304](https://github.com/canonical/cloud-init/issues/6304),
[LP#1940791](https://bugs.launchpad.net/bugs/1940791)) — and it silently falls
back to `DataSourceNone`. Two fixes, in the template (VM 9000) and Terraform:

1. `/etc/cloud/ds-identify.cfg`: `policy: search,found=all,maybe=all,notfound=enabled`.
2. Cloud-init drive on SCSI (`initialization.interface = "scsi3"`) — enumerates
   fast enough under `q35`.

See `setup/pve.md` (`Cloud-Init Template`) for the template-build steps.

## Apply issues (resolved)

- **Plan hung refreshing an agent-less VM.** `bpg/proxmox` polls
  `agent/network-get-interfaces` forever when the guest agent is enabled in the
  live VM's config but never came up; `agent.wait_for_ip.disabled = true`
  doesn't help (refresh reads the live `agent=1` flag, not the `.tf`). Cleared
  with `qm set 100 --agent enabled=0` on the old VM. Kept `wait_for_ip.disabled`
  in `main.tf` for the slow-agent (not absent-agent) case.
- **Disk changes planned in-place, not replace.** `bpg/proxmox` treats
  `datastore_id`/`size` changes as live move/resize, which keeps the broken OS
  disk. Forced a replace by tainting the VM via a one-off `workflow_dispatch`
  (`terraform-taint.yml`, since removed).
- **`local-lvm` had no ACL grant** for `terraform@pve` — added; see `setup/pve.md`.

## CPU / memory

- Memory: 24576 MiB dedicated, no ballooning. 30720 (2 GiB for host) triggered
  the host OOM killer under load — not enough headroom for host services + ZFS
  ARC. 24576 leaves ~7-8 GiB on the 32 GiB host.
- CPU: 4 cores, `type = "host"` for `intel-igpu` passthrough. Only VM on the
  host, so all cores is a safe default.

## SSH access from Terraform to `pve`

Cloud-init `user_data_file_id` needs a snippet upload, which `bpg/proxmox` does
only over SSH. Both workflows generate a throwaway ed25519 key at runtime and
set `ssh { username = "root" }` with no `authorized_keys` entry anywhere. This
relies on Tailscale SSH: with an `action: accept` rule (`setup/tailscale.md`),
`tailscaled` authorizes by tailnet identity before SSH auth runs and ignores the
offered key — the key only satisfies the Go SSH client's handshake.

Requires pinning the SSH target, else `bpg/proxmox` auto-detects each node's SSH
address via the API and picks `pve`'s LAN interface (its default gateway) over
Tailscale, hitting the real `sshd` where key auth fails:

```
ssh {
  username = "root"
  node {
    name    = "pve"
    address = var.pve_host
  }
}
```

`var.pve_host` also replaces a formerly-hardcoded Tailscale hostname in
`endpoint`; supplied via the `PVE_TAILSCALE_HOST` secret (`TF_VAR_pve_host`).
See `CLAUDE.md` secrets table.

## Tailnet join key expiry

`tailscale_tailnet_key.mediacenter` uses `expiry = 86400` (24h). At 3600 (1h)
the key expired before cloud-init used it, given apply-to-boot latency plus the
`production` approval gate.

## OAuth client

First plan run failed: a shared OAuth client scoped to both `tag:ci-runner` and
`tag:mediacenter` rejected the single-tag request. Split into two single-tag
clients — see `setup/tailscale.md` (`OAuth clients`).

## Manual setup (done)

- `Snippets` content type enabled on the `local` datastore (`Datacenter` →
  `Storage` → `local`) — required for the cloud-init snippet upload.
- Tailnet ACL, `production` environment, branch protection — see
  `setup/tailscale.md` and `setup/github.md`.

## Jellyfin

`ansible/playbooks/jellyfin.yml` (targets `mediacenter`) formats and mounts the
two data disks and installs Jellyfin with Intel iGPU transcoding:

- Disks are `ext4`, whole-disk, labeled and mounted by `LABEL=` (fstab). Device
  identity uses stable `/dev/disk/by-id/scsi-…drive-scsiN` paths — Linux `sdX`
  order is inverted vs the SCSI index. `scsi2` (850G SSD) -> `/mnt/fast-store`,
  `scsi1` (4.2T HDD) -> `/mnt/bulk-store`; map is in `host_vars/mediacenter.yaml`.
- Folders: `fast-store/{app-data,downloads}`, `bulk-store/media/{,movies,tv}`,
  created `root:root 0755`.
- iGPU: installs the Intel VAAPI/QSV drivers and adds the `jellyfin` user to
  `render`/`video`. Enable **VAAPI** once in Dashboard -> Playback -> Transcoding
  (device `/dev/dri/renderD128`) — not seeded by Ansible.
- Reverse proxy + DNS already route `jellyfin.<domain>` to `:8096` (see
  `caddy.md`, `cloudflare.md`); no changes needed there.

## Out of scope

- arr stack: storage ownership and the download/automation stack are covered in
  `arr-stack.md`.
