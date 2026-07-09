# Mediacenter VM — Implementation Notes

`terraform/` now provisions the `mediacenter` VM (Jellyfin + arr stack) on
`pve`, and `.github/workflows/terraform-plan.yml` / `terraform-apply.yml`
implement the plan-on-PR / apply-on-merge model from `ci-cd.md`. This has not
been applied yet — see Remaining manual steps below before the first real
`apply` run.

## Disk layout

One disk per storage pool, not a separate downloads-scratch disk:

- `fast-store` (SSD): the cloned OS disk (`scsi0`), resized to 850 GB —
  most of the ~931 GiB pool, leaving headroom for ZFS COW/snapshot overhead
  rather than literally 100%. Downloads and transcode scratch live in
  folders on this same disk, not a separate virtual disk — user's explicit
  call, overriding the earlier plan (see [[project_jellyfin_vm]]) of a
  second fast-store disk.
- `bulk-store` (mirrored HDD): one new disk (`scsi1`), 4500 GB — most of
  the ~4.55 TiB mirror capacity, same headroom reasoning, for the Jellyfin
  media library.

Both sizes are `terraform/modules/mediacenter/variables.tf` defaults
(`os_disk_size_gb`, `media_disk_size_gb`), not hardcoded in the resource.

## CPU / memory

- Memory: 30720 MiB dedicated, no ballooning (`floating` unset/0) — a
  static reservation, not a dynamic balloon split, leaving 2 GiB for `pve`
  itself. Decided previously (see [[project_jellyfin_vm]]).
- CPU: all 4 cores/threads (`cpu.cores = 4`), `type = "host"` for best
  passthrough compatibility with `intel-igpu`. Not explicitly discussed
  with the user — CPU isn't statically partitioned like memory, so
  allocating all cores to the only VM on the host is a low-risk default,
  unlike the disk-size question.

## SSH access from Terraform to `pve` (untested assumption)

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

This chain hasn't been exercised end-to-end yet. If the first real
`terraform plan`/`apply` run fails at the snippet-upload step, the likely
fix is switching to a real persisted keypair (public key in `pve`'s
`~/.ssh/authorized_keys`, private key as a new GitHub Actions secret)
rather than the ephemeral-key approach.

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
