# rclone

Hourly one-way mirror of FileBrowser's served files to Google Drive and
OneDrive. Deployed as a Portainer stack on mediacenter from
`terraform/portainer/stacks.tf`. First backup path in the repo.

## Status

PR #44 (ansible: rclone config directory) and a follow-up terraform PR cover
the deploy. Split into two PRs on purpose — the terraform-managed container
bind-mounts `/mnt/fast-store/app-data/rclone`, which ansible must create with
`docker:media 0700` ownership first, or Docker auto-creates it as root on
first container start. See
[[anterra-terraform-ansible-pr-race]] in memory for the general pattern.

One-time authorisation (`rclone config`, headless OAuth via `rclone
authorize` run locally) is a manual step after both PRs are merged and
applied — not yet done as of this writing.

## Layout

| Stack | Host | Mounts |
|---|---|---|
| `rclone` | mediacenter | `app-data/rclone` -> `/config/rclone`, `app-data/filebrowser/files` (ro) -> `/data` |

No public exposure: no DNS record, no Caddy vhost. The container's only job
is an outbound sync loop.

## Direction and safety rails

One-way push, FileBrowser -> Drive/OneDrive, never pulled back. `/data` is
mounted **read-only**, so rclone cannot modify or delete FileBrowser's files
regardless of flags.

`sync` mirrors the source, which means legitimate deletes on the FileBrowser
side do reach the remotes. Two rails on that:

- `--backup-dir "<remote>:.trash/$(date +%F)"` — removed/replaced files move
  to a dated trash folder on the remote instead of disappearing outright.
  `.trash/` sits at the remote root, not under `files/`, because a
  `--backup-dir` inside the sync destination makes rclone try to sync its own
  trash on the next run. `.trash/` is never pruned automatically; clear it
  manually when comfortable.
- `--max-delete 20` — hard stops the sync if more than 20 files would be
  removed in one run. A legitimate bulk delete (e.g. deleting a 50-file
  folder in FileBrowser) trips this and fails every subsequent run until
  resolved. That's the rail working, not a bug. Clear it with a one-off
  manual run raising the limit for that invocation only:
  ```
  docker exec rclone rclone sync /data gdrive:files \
    --backup-dir "gdrive:.trash/$(date +%F)" --track-renames --max-delete 100
  ```
  Do not raise the limit in the compose file itself.

## Renames

`--track-renames` matches source and destination by hash and issues a
server-side move instead of a delete-plus-reupload. This is the entire reason
the mirror moved from Papra to FileBrowser: Papra never wrote renames to
disk, so they never reached the remote. If a rename ever shows up in the logs
as a delete-plus-upload anyway, the file's content changed at the same time
as its name — hashes no longer match, so this is correct (if slower)
behaviour, not a bug.

## The `$$` escaping trap

The compose command block is double-interpolated: Terraform's
`templatefile()` leaves literal `$$` alone, then Portainer's compose deploy
collapses `$$` -> `$`, so the shell only ever sees `$remote`. Writing
`$remote` directly in the `.tpl` file gets eaten by compose interpolation
first and expands to empty — `rclone sync /data :files` silently syncs to a
destination with no remote name. Any edit to the sync command must preserve
the double `$$` on `$$remote`. `$(date +%F)` is not an interpolation pattern
for either layer and passes through unescaped.

## Google Drive scope: `drive.file`

Deliberately restrictive: rclone can only see files and folders it created
itself. A leaked token cannot see the rest of the Drive.

Consequence: a `drive.file` app cannot see folders it did not create, and
Drive allows duplicate folder names. Rclone creates its own `files/` on
first sync; if `files/` had been pre-created in the Drive web UI, the result
would be two folders both called `files`, with rclone only ever writing to
the one it made. `files/` must be left for rclone to create.

Verify the scope is actually working with `docker exec rclone rclone lsd
gdrive:` — it must list only what rclone created. If the rest of the Drive is
visible, redo the `gdrive` remote's `rclone config`.

## OneDrive scope: no equivalent, weaker guarantee

Microsoft has no `drive.file` analogue. The OneDrive backend requests
`Files.ReadWrite.All`, which grants access to the whole OneDrive. The token
never leaving mediacenter is the only mitigation short of registering a
dedicated Azure app with `Files.ReadWrite` (non-`.All`) — not done, since
throttling on the shared client hasn't appeared. Pre-creating `files/` on
OneDrive is harmless, unlike on Drive, since no scope restriction applies.

## Why a container rather than a host install

mediacenter's apt only offers rclone 1.60.1 (2022); the official
`rclone/rclone` image tracks current releases (1.75 as of this deploy) and is
amd64, so containerising avoids the staleness problem entirely.

## Why tokens never leave the host

rclone rewrites `rclone.conf` in place whenever it refreshes an access token.
Any ansible task that re-templates that file would clobber the live token, so
the file is inherently stateful — the opposite of FileBrowser's
`config.yaml`, which ansible does render because FileBrowser never writes to
it itself. Combined with not wanting to leak Drive/OneDrive access, rclone
tokens are never committed, never pass through chat, and never become GitHub
Secrets.

## Reauthorisation

Both providers' tokens can expire or be revoked:

- **OneDrive** refresh tokens die after 90 days of inactivity. Recover with
  `docker exec -it rclone rclone config reconnect onedrive:` (same headless
  flow as initial setup).
- **Google Drive** refresh tokens have no fixed lifetime, but Google revokes
  after 6 months without a successful refresh, or if the app's client
  exceeds 50 issued tokens. Hourly syncing means inactivity alone shouldn't
  trigger it. Recover with `docker exec -it rclone rclone config reconnect
  gdrive:`.
- **Shared client rate-limiting** on either provider is congestion from other
  rclone users on the same default app, not our own volume. Safe to defer
  fixing, since `sync` re-diffs from scratch every run — a throttled run just
  leaves files for the next hourly pass, nothing is lost. If it becomes
  persistent: reuse the existing Google Cloud project (the one behind the
  Zero Trust Google identity provider) for a second Drive OAuth client
  (`drive.file` scope, Desktop app type); for OneDrive there is no existing
  project to reuse, so a new Azure/Entra app would be needed.

The initial `rclone config` walkthrough (headless `rclone authorize`, run
locally) needs rclone installed locally — apt's 1.60.1 predates Google's
removal of the OAuth out-of-band flow that `rclone authorize` depends on, so
it was installed from the official `install.sh` instead.

## Out of scope: the SQLite DB

`database.sqlite` (FileBrowser's users, shares, access rules, API tokens) is
deliberately not synced. Copying a live SQLite file with `rclone sync` can
capture a torn write; doing it correctly needs `sqlite3 database.sqlite
".backup /path/snapshot.db"` on a schedule ahead of the sync. That's separate,
not-yet-started work. Until then, losing mediacenter means keeping every file
under a readable name in its original folder, but losing share links and
user settings.
