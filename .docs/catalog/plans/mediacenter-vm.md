# Mediacenter VM — Implementation Notes

`terraform/` now provisions the `mediacenter` VM (Jellyfin + arr stack) on
`pve`, and `.github/workflows/terraform-plan.yml` / `terraform-apply.yml`
implement the plan-on-PR / apply-on-merge model from `ci-cd.md`. This has not
been applied yet — see Remaining manual steps below before the first real
`apply` run.

## Proxmox provider TLS

`terraform/providers.tf` sets `insecure = true` on the `proxmox` provider —
`pve`'s API uses Proxmox's default self-signed certificate, and nothing in
`setup/pve.md` provisions a real one. Acceptable because `pve` is reachable
only over Tailscale (see `setup/tailscale.md`), not exposed to the public
internet — user confirmed explicitly when this was flagged.

## Disk layout

One disk per storage pool, not a separate downloads-scratch disk:

- `fast-store` (SSD): the cloned OS disk (`scsi0`), resized to 850 GB —
  most of the ~931 GiB pool, leaving headroom for ZFS COW/snapshot overhead
  rather than literally 100%. Downloads and transcode scratch live in
  folders on this same disk, not a separate virtual disk — user's explicit
  call, overriding the earlier plan (see [[project_jellyfin_vm]]) of a
  second fast-store disk.
- `bulk-store` (mirrored HDD): one new disk (`scsi1`), 4300 GB (was 4500,
  see below) — for the Jellyfin media library.

Both sizes are `terraform/modules/mediacenter/variables.tf` defaults
(`os_disk_size_gb`, `media_disk_size_gb`), not hardcoded in the resource.

**4500 GB failed on the real apply** — `zfs error: cannot create
'bulk-store/vm-100-disk-0': out of space`. `zpool list` reported 4.55T free,
but that's pool-wide free space before ZFS's slop-space reservation
(~1/32 of pool size, ~130GB here); `zfs list`'s `AVAIL` column (4.42 TiB /
4526 GiB) is the real ceiling for new zvols, and zvol creation has its own
overhead on top of the raw `size`. Dropped to 4300 GB for real margin.
Lesson: check `zfs list <pool>` (not `zpool list`) for actual available
capacity when sizing disks against ZFS-backed Proxmox storage.

## CPU / memory

- Memory: 30720 MiB dedicated, no ballooning (`floating` unset/0) — a
  static reservation, not a dynamic balloon split, leaving 2 GiB for `pve`
  itself. Decided previously (see [[project_jellyfin_vm]]).
- CPU: all 4 cores/threads (`cpu.cores = 4`), `type = "host"` for best
  passthrough compatibility with `intel-igpu`. Not explicitly discussed
  with the user — CPU isn't statically partitioned like memory, so
  allocating all cores to the only VM on the host is a low-risk default,
  unlike the disk-size question.

## SSH access from Terraform to `pve` (still untested)

Cloud-init `user_data_file_id` requires uploading a snippet file, and the
`bpg/proxmox` provider only supports snippet upload over SSH (not the
Proxmox API). Both workflows generate a throwaway ed25519 keypair at
runtime (`ssh-keygen`, never persisted) and configure
`ssh { username = "root" }` with no matching `authorized_keys` entry
anywhere.

This relies on Tailscale SSH's behavior: when the tailnet ACL's `ssh` rule
uses `action: accept` (already the case — see `setup/tailscale.md`),
`tailscaled` authenticates and authorizes the connection using the peer's
tailnet identity before the SSH auth phase even runs, and doesn't validate
the client-offered key. The Go SSH client HashiCorp's provider uses still
needs *some* auth method configured to attempt the handshake, hence the
throwaway key — its content is never actually checked.

This still hasn't been exercised — the first PR's plan run never got past
the runner joining the tailnet (see next section). If it fails at the
snippet-upload step once that's fixed, the likely fallback is a real
persisted keypair (public key in `pve`'s `~/.ssh/authorized_keys`, private
key as a new GitHub Actions secret) instead of the ephemeral-key approach.

## First plan run failure: OAuth client scoped to 2 tags

The first PR's `terraform-plan` run failed before Terraform even started —
`tailscale/github-action` couldn't bring the runner up:
`Status: 400, Message: "requested tags [tag:ci-runner] are invalid or not
permitted"`.

Root cause: `TS_OAUTH_CLIENT_ID`/`SECRET` was originally one OAuth client
scoped to both `tag:mediacenter` and `tag:ci-runner`. Tailscale has a bug
where an OAuth client scoped to 2+ tags rejects a request for only a subset
of them — see
[tailscale/terraform-provider-tailscale#437](https://github.com/tailscale/terraform-provider-tailscale/issues/437).
Neither caller here ever requests both tags together (the GitHub Action
requests `tag:ci-runner` only; Terraform's `tailscale_tailnet_key` requests
`tag:mediacenter` only), so it always hit the bug.

Fixed by splitting into two single-tag OAuth clients: `TS_OAUTH_CLIENT_ID`/
`SECRET` now scoped to `tag:ci-runner` only, and a new
`TS_OAUTH_MEDIACENTER_CLIENT_ID`/`SECRET` scoped to `tag:mediacenter` only.
Both workflows updated so the `tailscale/github-action` step uses the
former and the `TAILSCALE_OAUTH_CLIENT_ID`/`SECRET` env vars (Terraform's
own provider auth) use the latter. See `setup/tailscale.md`
(`OAuth clients` section).

## Remaining manual steps

1. **Tailnet ACL** — done. `tag:ci-runner` got its own `ssh` rule (couldn't
   share the `group:fleet-admins` rule — `autogroup:self` in `dst` only
   works when `src` is exclusively users/groups), and `pve`/`rpi` were
   tagged `tag:fleet-host` so that rule can reach them. See
   `setup/tailscale.md`.
2. **Enable snippets on the `local` datastore** — done (`local` is a
   directory-backed datastore on `pve`; `Snippets` content type enabled via
   `Datacenter` → `Storage` → `local`).
3. **GitHub `production` environment** — done. Created under `Settings` →
   `Environments` with a required reviewer, so `terraform-apply.yml`'s
   `environment: production` gate pauses for approval before applying (see
   `setup/github.md`).
4. **Branch protection** — done. `plan` added as a required status check on
   `main` (see `setup/github.md`).

All four manual steps are done. Next real step is opening a PR into `main`
with this `terraform/` + workflow content to exercise the plan job for
real, including the untested SSH-over-Tailscale assumption above.

## Not in scope for this pass

Ansible wiring (inventory entry for `mediacenter`, `site.yml` targeting it)
was explicitly deferred — this pass covered Terraform + the GitHub Actions
workflows only.

Terraform attaches the `bulk-store` disk (`scsi1`) raw — it is not
partitioned, formatted, or mounted, and no folder layout exists on either
disk. Downloads/transcode-scratch folders on the OS disk and the media
library folder(s) on the mounted `bulk-store` disk are also not created yet.
All of this — formatting/mounting `scsi1`, creating the folder layout, and
installing/configuring Jellyfin + the arr stack against those paths — is
follow-on Ansible work, not yet started.
