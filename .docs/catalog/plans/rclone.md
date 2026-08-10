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
authorize` run locally) is done for both `gdrive` and `onedrive`, using
dedicated OAuth clients rather than rclone's shared defaults — see "OAuth
clients" below for why. Verified: clean hourly syncs, `drive.file` scope
proof, read-only mount proof, rename-as-server-side-move proof, and
delete-into-`.trash` proof, all passing on both remotes.

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
never leaving mediacenter is the main mitigation. A dedicated Azure app (see
"OAuth clients" below) narrows the blast radius of a leaked token to just
this app's grant, but rclone's own documented permission set for the OneDrive
backend is `Files.Read`, `Files.ReadWrite`, `Files.Read.All`,
`Files.ReadWrite.All`, `offline_access`, `User.Read`, `Sites.Read.All`
together — there's no documented working path using only the non-`.All`
scopes, so this app requests the full set rather than guessing at a narrower
one. Pre-creating `files/` on OneDrive is harmless, unlike on Drive, since no
scope restriction applies.

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

## OAuth clients

Both remotes use **dedicated** OAuth clients, not rclone's shared defaults.
This wasn't the original plan — the original decision was to use the shared
clients and only register dedicated ones if throttling appeared. That changed
mid-setup: `rclone config` for `gdrive` warned that rclone's shared Google
Drive client is being retired during 2026, not merely throttled. Since a
dedicated client was needed for Google regardless, one was registered for
OneDrive too rather than wait to hit the same class of problem separately.

- **Google**: a second OAuth 2.0 Client in the same Google Cloud project that
  backs Cloudflare Zero Trust's Google identity provider (that pre-existing
  client is named `Global-Auth-Client` in the console, kept separate from
  this one). Type **Desktop app**, scope `drive.file` only. Publishing status
  is **In production** — Testing mode expires refresh tokens after 7 days.
- **OneDrive**: a new Azure/Entra app, since there was no existing project to
  reuse. Account type "Accounts in any organizational directory (multitenant)
  and personal Microsoft accounts", redirect URI `http://localhost:53682/`
  (Web platform), delegated permissions as listed above.
  **`disable_site_permission = true`** is set in the remote's advanced
  config — without it, authorising against a personal (non-work/school)
  Microsoft account failed with a generic `Auth Error: No code returned by
  remote server: server_error`, even though the Microsoft Authenticator
  approval succeeded. Root cause: `Sites.Read.All` is a SharePoint-oriented
  permission that personal accounts don't cleanly consent to, and the
  failure surfaces as an opaque server error rather than a scope-specific
  one. (The other common cause of that same error is copying the secret's
  "Secret ID" instead of its "Value" from the Azure portal — check that
  first if it recurs.)

The initial `rclone config` walkthrough (headless `rclone authorize`, run
locally) needs rclone installed locally — apt's 1.60.1 predates Google's
removal of the OAuth out-of-band flow that `rclone authorize` depends on, so
it was installed from the official `install.sh` instead.

## Credential renewal timeline

- **Google OAuth client secret**: does not expire. Google has no automatic
  expiration for Cloud Console OAuth client secrets — rotation is manual only
  (Google Auth Platform → Clients; max two live secrets at once, so rotating
  means adding a new one, migrating, then disabling the old one). No renewal
  deadline to track.
- **Google refresh token**: no fixed lifetime, but revoked after 6 months
  without a successful refresh, or if the client exceeds 50 issued tokens.
  Hourly syncing means inactivity alone shouldn't trigger this. Recover with
  `docker exec -it rclone rclone config reconnect gdrive:`.
- **Azure/Entra client secret**: **expires 2028-08-10** (24 months from
  creation on 2026-08-10). This is a hard deadline — unlike Google's secret,
  Azure client secrets always have a fixed expiry. Before then: Azure Portal
  → App registrations → the rclone app → Certificates & secrets → new client
  secret → copy the Value → update the `onedrive` remote (`docker exec -it
  rclone rclone config update onedrive client_secret <new-value>`, or redo
  `rclone config` for `onedrive`) → `docker restart rclone`. Missing this
  deadline breaks the OneDrive sync until redone.
- **OneDrive refresh token**: dies after 90 days of inactivity, independent
  of the client secret's own expiry. Recover with `docker exec -it rclone
  rclone config reconnect onedrive:` (same headless flow as initial setup).

## Out of scope: the SQLite DB

`database.sqlite` (FileBrowser's users, shares, access rules, API tokens) is
deliberately not synced. Copying a live SQLite file with `rclone sync` can
capture a torn write; doing it correctly needs `sqlite3 database.sqlite
".backup /path/snapshot.db"` on a schedule ahead of the sync. That's separate,
not-yet-started work. Until then, losing mediacenter means keeping every file
under a readable name in its original folder, but losing share links and
user settings.
