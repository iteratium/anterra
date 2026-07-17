# TRMNL BYOS (Terminus)

Self-hosted TRMNL "Bring Your Own Server" for the Kindle e-ink dashboard. The
Kindle-side half lives in `kindle-tools` (`plans/dashboard-plan.md`); this is
the server half (`plans/anterra-plan.md` there).

Flavor: [Terminus](https://github.com/usetrmnl/terminus) (official,
TRMNL-maintained). Deployed as a Portainer stack (`trmnl`) from
`terraform/portainer/stacks.tf`, on `mediacenter`.

## Layout

| Containers | Host | Bind |
|---|---|---|
| trmnl (web), trmnl-worker, trmnl-database (Postgres), trmnl-keyvalue (Valkey), trmnl-init-certificates | mediacenter | `<mediacenter-100.x>:2300` (web only) |

Only the web container publishes a port, and only on mediacenter's tailnet
IP — same reasoning as karakeep-backend (`karakeep.md`): the admin UI is
unauthenticated on the tailnet. Postgres and Valkey are not published at all;
web and worker reach them over the compose-internal network.

## Addressing

`API_URI` is `http://mediacenter:2300` — the bare MagicDNS name, matching the
Kindle KOReader plugin's configured server URL (`kindle-tools`). The Kindle
resolves this through its tailscaled SOCKS5/HTTP proxy, not a direct route.

No DNS record, no Caddy entry: this stack is deliberately tailnet-only, never
proxied externally (unlike `keep.<domain>`).

## Versions

`ghcr.io/usetrmnl/terminus:latest` (web, worker, init-certificates) —
Watchtower label set. Postgres (`18.4-alpine`) and Valkey (`9.1-alpine`) are
pinned, no Watchtower label — same rationale as karakeep's meilisearch: a
backing data store needs manual care on upgrade.

## Data

Named volumes: `database-data` (Postgres), `keyvalue-data` (Valkey — cache,
rebuildable), `web-fonts`, `web-uploads`, `certificates`. `database-data`
holds device registrations, plugin config, and the battery/RSSI check-in
history — the one volume worth backing up.

## Bootstrap

1. `TRMNL_APP_SECRET`, `TRMNL_DATABASE_PASSWORD`, `TRMNL_KEYVALUE_PASSWORD` —
   generate and store as GitHub secrets before the first apply (see CLAUDE.md
   secrets table). Losing/changing `DATABASE_PASSWORD` or `KEYVALUE_PASSWORD`
   after the volumes exist locks the app out of its own data — see
   Terminus's own docker docs on this.
2. After first deploy, register the Kindle as a device in the admin UI. The
   issued device token goes into the `kindle-tools` plugin config — the one
   value that crosses from this stack into that repo.
3. Configure plugins: Weather (built-in, lat/lon), F1 (import
   `kindle-tools/trmnl/f1/` as a private/polling plugin), Battery (device
   reports it automatically, surfaced on the dashboard). Assemble into the
   device's playlist — the 600x800 screen fits ~2-3 panels.

## Tailnet ACL

No change needed: the live policy's catch-all `grants` entry already permits
every tailnet member to reach every port on every other member, so
`tag:kindle` can already reach `tag:mediacenter:2300` — see `tag:kindle` in
`setup/tailscale.md`.

## Verification

1. `curl -sm8 http://mediacenter:2300/` from another tailnet host returns the
   app; from mediacenter's LAN IP it does not (bind check).
2. `ssh root@kindle 'curl -sm8 --socks5-hostname 127.0.0.1:1055 http://mediacenter:2300/'`
   proves the ACL grant + proxy path end-to-end.
3. Device shows up registered in the admin UI, battery/RSSI check-ins logging.
