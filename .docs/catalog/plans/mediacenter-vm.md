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

- OS disk (`scsi0`, `efidisk0`, and the cloud-init drive) moved off
  `fast-store` onto `local-lvm` (the host's LVM-thin pool on the boot SSD),
  sized 100 GB — was 850 GB direct on `fast-store`. `local-lvm` has ~140 GB
  free in the thin pool, is already thin-provisioned (no ZFS
  refreservation-vs-actual-usage confusion), and this frees `fast-store`
  entirely for app-data/downloads/whatever comes up later, instead of
  reserving most of the pool for the OS disk upfront. User's call — found
  after the first real apply, see the ZFS reservation note below (which
  explains why `fast-store` looked 95%+ full for an empty disk).
- `bulk-store` (mirrored HDD): one disk (`scsi1`), 4300 GB (was 4500,
  see below) — for the Jellyfin media library.
- `fast-store` (SSD): one disk (`scsi2`), 850 GB — for app-data/downloads/
  transcode scratch. Same reasoning as `bulk-store`: attach the disk now
  even though nothing is provisioned on it yet, rather than leaving it
  undefined until Ansible needs it. 850 GB chosen over the initially
  requested 900 GB — see the slop-space note below; 900 GB left ~0 real
  margin on this pool given the same ZFS reservation behavior that bit
  `bulk-store` at 4500 GB.

All three sizes are `terraform/modules/mediacenter/variables.tf` defaults
(`os_disk_size_gb`, `media_disk_size_gb`, `appdata_disk_size_gb`), not
hardcoded in the resource.

**4500 GB failed on the real apply** — `zfs error: cannot create
'bulk-store/vm-100-disk-0': out of space`. `zpool list` reported 4.55T free,
but that's pool-wide free space before ZFS's slop-space reservation
(~1/32 of pool size, ~130GB here); `zfs list`'s `AVAIL` column (4.42 TiB /
4526 GiB) is the real ceiling for new zvols, and zvol creation has its own
overhead on top of the raw `size`. Dropped to 4300 GB for real margin.
Lesson: check `zfs list <pool>` (not `zpool list`) for actual available
capacity when sizing disks against ZFS-backed Proxmox storage.

**ZFS zvols are thick-provisioned by default** — `refreservation` is set
equal to `volsize` at creation, so `zfs list`'s `USED` column shows the
full declared disk size immediately, regardless of how much data is
actually written (`REFER` is the real figure). A freshly-created, empty
850 GB disk on a 928 GB pool legitimately shows ~95% `USED`. Not a bug,
just easy to misread from `zpool`/dashboard-level views — this is what
originally prompted moving the OS disk to `local-lvm` above.

## Cloud-init never ran on first real boot (no hostname, no network, no Tailscale)

After the first real apply, the VM booted fine (login prompt reachable over
serial) but `qemu-guest-agent` never came up, hostname stayed the image
default (`ubuntu`, not `mediacenter`), and the VM sent zero network traffic
ever — no DHCP, no ARP. It never joined the tailnet as a result (`runcmd`
in the cloud-init user-data, which installs the agent and runs
`tailscale up`, never executed).

Diagnosed by mounting the template's disk read-only (safe — templates
aren't running) and confirming it was genuinely pristine (`/var/lib/cloud/`
didn't exist, no stale semaphores), then cloning it to a throwaway
diagnostic VM (`9001`, no `hostpci0`, cloud-init payload with an injected
SSH key so it was actually loggable-into) to reproduce and instrument the
failure directly. Root cause: `ds-identify` (cloud-init's systemd
generator) and cloud-init's own datasource search both run early enough in
boot that the `ide2` CD-ROM cloud-init drive isn't enumerated by the
kernel yet — a known upstream race
([cloud-init#6304](https://github.com/canonical/cloud-init/issues/6304),
[LP#1940791](https://bugs.launchpad.net/bugs/1940791)). The generator
silently disables `cloud-init.target` for that boot; even when forced
enabled, cloud-init's own search still falls back to the no-op
`DataSourceNone`. No error surfaces anywhere persisted to disk — the
generator's log lives in `/run` (tmpfs), gone by shutdown.

Fix, applied directly to the template (VM 9000) and going forward via
Terraform:
1. `/etc/cloud/ds-identify.cfg` on the template disk:
   `policy: search,found=all,maybe=all,notfound=enabled`.
2. Cloud-init drive moved from Proxmox's default `ide2` to SCSI
   (`initialization.interface = "scsi3"` in `main.tf`) — SCSI enumerates
   fast enough under `q35` that the race doesn't happen. Verified on the
   throwaway VM: `ide2` took 4+ minutes and still used the empty fallback
   datasource; `scsi` had hostname/network/packages all correct within 20
   seconds.

See `setup/pve.md` (`Cloud-Init Template` section) for the reproducible
template-build steps including this fix. Confirmed working on the real
apply that recreated `mediacenter` (VM 100) — see below for the apply
itself, which needed a few more fixes to actually get there.

## Getting the actual apply through: three more issues

The disk-layout PR's `terraform plan` hung indefinitely (well past 15
minutes) every time, always at the same point: refreshing
`proxmox_virtual_environment_vm.mediacenter`. Diagnosed by temporarily
adding `TF_LOG=DEBUG` to `terraform-plan.yml` (logged straight to stdout,
not a file/artifact — this repo is public, and GitHub's secret redaction
only covers text streamed through the log viewer, not separately-uploaded
files). The debug log showed the `bpg/proxmox` provider stuck in a tight
loop, roughly once a second: `GET
/api2/json/nodes/pve/qemu/100/agent/network-get-interfaces`, every time
getting `500 QEMU guest agent is not running`, retrying forever — no
backoff, no giveup. `agent.wait_for_ip.disabled = true` (the documented
fix for this in the provider's own docs) did *not* stop it: refresh reads
the `agent: enabled=1` flag directly off the live VM's actual Proxmox
config, independent of anything in the `.tf` file. Since VM 100's agent
had never come up (see above), this was going to hang on every single
plan/apply against the existing broken VM, forever, regardless of the
`wait_for_ip` setting.

Unblocked by directly setting `qm set 100 --agent enabled=0` on the live
(about-to-be-destroyed) VM — took the refresh from hanging indefinitely to
completing in ~20s. `agent.wait_for_ip.disabled = true` was still added in
`main.tf` since it's correct/documented behavior for any *future* case
where the agent is slow rather than completely absent.

Along the way, found `/storage/local-lvm` had no ACL grant at all for
`terraform@pve` — added `PVEDatastoreUser`, matching the existing
`fast-store`/`bulk-store` grants (see `setup/pve.md`).

Second issue: once the plan ran, it showed the disk-layout changes as an
**in-place update** (`0 to add, 1 to change, 0 to destroy`), not a
replace. `bpg/proxmox` treats `datastore_id`/`size` changes on an existing
disk as move/resize operations Proxmox can do live, rather than forcing
recreation. That's usually the right call, but here the whole point was a
fresh clone from the now-fixed template — an in-place move keeps the
existing (broken, already-marked-done-with-DataSourceNone) OS disk
content untouched, so cloud-init still wouldn't have run correctly.
Forced a real replace by tainting the VM resource via a one-off
`workflow_dispatch` workflow (`terraform-taint.yml`, added temporarily and
removed once used — `workflow_dispatch` triggers only work for workflow
files that exist on the default branch, so this had to be merged before
it could even be run). `terraform apply` then correctly showed
`1 added, 0 changed, 1 destroyed`.

Third issue: the recreated VM booted correctly this time (hostname
`mediacenter`, guest agent up, `DataSourceNoCloud` detected) but
`runcmd`'s `tailscale up` failed: `backend error: invalid key: API key ...
not valid`. `tailscale_tailnet_key.mediacenter` had `expiry = 3600` (1
hour) and `reusable = false` — the key had been sitting unused in
Terraform state since an earlier apply attempt, and by the time cloud-init
actually got far enough to use it (after all the plan-hang debugging
above), it had expired. Fixed by bumping `expiry` to `86400` (24h), enough
slack for realistic apply-to-boot latency including a stuck
`production`-environment approval gate. This forced a fresh key on the
next apply; the already-running VM re-ran the join manually against that
new key rather than being recreated again.

## CPU / memory

- Memory: 24576 MiB dedicated (was 30720), no ballooning (`floating`
  unset/0) — a static reservation, not a dynamic balloon split. The
  original 30720 (leaving 2 GiB for `pve`) failed on the real apply: the
  host's OOM killer killed the VM's QEMU process outright
  (`Out of memory: Killed process ... (kvm)`) once actually running, since
  2 GiB wasn't enough real headroom for host services plus ZFS ARC across
  both pools under load. 24576 leaves ~7-8 GiB of real headroom on the
  32 GiB host.
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
