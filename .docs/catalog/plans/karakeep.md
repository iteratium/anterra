# Karakeep

Bookmark manager, split across two hosts. Deployed as two Portainer stacks from
`terraform/portainer/stacks.tf`.

## Layout

| Stack | Host | Containers | Bind |
|---|---|---|---|
| `karakeep-web` | vps | karakeep | `<vps-100.x>:9721` -> 3000 |
| `karakeep-backend` | mediacenter | chrome, meilisearch | `<mediacenter-100.x>:9222`, `:7700` |

The web app reaches chrome and meilisearch directly over the tailnet. Both
backend containers bind to the tailnet IP only: chrome's CDP port is
unauthenticated and must not be on the LAN, and the vps has no firewall
(`ufw` inactive), so a `0.0.0.0` bind there would be world-reachable on 9721.

## Addressing

`BROWSER_WEB_URL` must use mediacenter's tailnet IP, not a hostname. Chrome's
debug endpoint rejects any `Host` header that is not `localhost` or a bare IP,
so both a DNS name and a MagicDNS name fail. This is also why there is no
`chrome.ketwork.in` record. Meilisearch has no record either; MagicDNS covers
the dashboard.

`keep` is the only DNS record: external, A -> vps public IP, proxied, served by
vps Caddy from `http://vps.tailb3a7a.ts.net:9721`.

It was bootstrapped as an internal record (rpi Caddy, A -> rpi tailnet IP) and
moved to external only after signups were disabled, so the app was never
publicly reachable while it accepted signups. `NEXTAUTH_URL` was set to the
final URL from the start, so the move needed no container change. Do the same
if signups are ever reopened.

The flip is split across two applies on purpose: `terraform-apply` runs the
cloudflare workspace before portainer, and `ansible-apply` fires concurrently
on the same merge, so disabling signups in the same commit as the record move
could publish the record before the container picks up the flag.

## Versions

- karakeep: `:release`, Watchtower label set.
- meilisearch: pinned. Upgrades need a manual dump/restore, so no Watchtower label.
- chrome: pinned to `alpine-chrome:124`, matching upstream's compose. No Watchtower label.

## Tailnet SSRF guard

Karakeep blocks worker-initiated requests resolving to private, loopback,
link-local, or Tailscale CGNAT addresses. If crawling or search indexing fails
against the 100.x backends, set `CRAWLER_ALLOWED_INTERNAL_HOSTNAMES=.` on
`karakeep-web`. If that does not resolve it, fall back to the
[minimal install](https://docs.karakeep.app/installation/minimal-install)
(no chrome, no meilisearch: no search, no screenshots).

## Disabled

AI tagging and summarization: no `OPENAI_API_KEY` set. Archival is off by
default (`CRAWLER_FULL_PAGE_ARCHIVE`, `CRAWLER_FULL_PAGE_SCREENSHOT`,
`CRAWLER_STORE_PDF`, `CRAWLER_VIDEO_DOWNLOAD`), which matters on the vps's
25 GiB disk. Viewport screenshots and banner caching stay on.

## Bootstrap

Done. `DISABLE_SIGNUPS=false` on first deploy, account created, then flipped to
`true`. Re-enable the same way to add users.

## Portainer provider create race

The provider fires an unconditional `PUT /stacks/{id}` right after create to
apply `prune`/`pullImage`/`webhook`, even when all three are at their defaults.
Portainer deploys asynchronously, so the PUT can land mid-deploy and get a 409;
the provider retries only on 5xx, so the stack ends up tainted despite having
deployed correctly. Both karakeep stacks hit this on first apply and had to be
untainted out of band. Only create is affected -- the update path issues a
single PUT.

If a new stack lands tainted with `failed to finalize stack creation
(prune/webhook)`, check the containers before touching anything: if they are
healthy and match the stack file, untaint rather than re-apply, since a tainted
resource makes every apply destroy and recreate the stack.

## Data

Docker named volumes: `data` on vps (SQLite DB + assets), `meilisearch` on
mediacenter. Meilisearch holds only a rebuildable index.
