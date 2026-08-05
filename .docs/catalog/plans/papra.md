# Papra

Document management. Deployed as a Portainer stack on mediacenter from
`terraform/portainer/stacks.tf`.

## Layout

| Stack | Host | Bind |
|---|---|---|
| `papra` | mediacenter | `<mediacenter-100.x>:1221` -> 1221 |

External exposure follows the `seerr`/`jellyfin` shape: DNS -> vps public IP
-> vps Caddy -> `http://mediacenter.tailb3a7a.ts.net:1221`. mediacenter is
not in the `caddy` group, so it has no Caddy of its own.

## Auth

Email/password login is disabled (`AUTH_PROVIDERS_EMAIL_IS_ENABLED=false`).
The only login path is Cloudflare Access, configured as a custom OIDC
provider named `cloudflare` in `AUTH_PROVIDERS_CUSTOMS`. Cloudflare Access
itself authenticates against Google (the IdP behind Cloudflare), gated by an
Access policy that allows only the intended email.

## Storage

Storage key pattern is flat: `{{document.name}}`. Documents land on disk
under their original, human-readable filename
(`/mnt/fast-store/app-data/papra/documents/`), so the tree stays browsable
without Papra — the whole point, since Drive/OneDrive sync (a later piece of
work) turns it into a searchable escape hatch if Papra is ever down.

Caveats, verified against Papra's source:

- `currentDate.*` placeholders resolve to upload time, not document date —
  this is why the pattern has no date folder.
- Renaming a document in Papra does not rename the file on disk; the storage
  key is computed once at upload. Get the filename right before uploading.
- Trashing leaves the file on disk; only a permanent delete removes it.
- `ensureSafeFileName` (`filenamify`) only strips `/ \ : * ? " < > |`,
  control characters and reserved names, and truncates around 100 bytes.
  Spaces, case and unicode survive.

The SQLite DB (tags, metadata, share links) is out of scope for the disk
mirror — it is not synced anywhere.

## Bootstrap ordering

`AUTH_PROVIDERS_EMAIL_IS_ENABLED=false` means the only way to create the
first account is OIDC login, but that is blocked while registration is
disabled. Two-phase deploy:

1. Apply with `papra_registration_enabled = "true"`.
2. Log in once via Cloudflare Access. `AUTH_FIRST_USER_AS_ADMIN` defaults to
   `true`, so that account becomes admin.
3. Flip `papra_registration_enabled` back to `"false"` in a follow-up PR and
   re-apply.

Doing it in one shot leaves no way in.

## Versions

Pinned to `26.6.1-rootless`, no Watchtower label. Papra runs SQLite
migrations on startup and this is a document store, so version bumps are a
deliberate one-line PR, same as `meili_version`.

## Portainer provider create race

See `.docs/catalog/plans/karakeep.md` — the provider can leave a freshly
created stack tainted with `failed to finalize stack creation
(prune/webhook)` even when the container deployed fine. If that happens to
`papra`, check the container before touching anything; if it is healthy,
dispatch `terraform-untaint.yml` with `portainer_stack.papra` rather than
re-applying.
