# TRMNL BYOS (Terminus)

Self-hosted TRMNL "Bring Your Own Server" for the Kindle e-ink dashboard. The
Kindle-side half lives in `kindle-tools` (`plans/dashboard-plan.md`); this is
the server half (`plans/anterra-plan.md` there).

Flavor: [Terminus](https://github.com/usetrmnl/terminus) (official,
TRMNL-maintained). Deployed as a Portainer stack (`trmnl`) from
`terraform/portainer/stacks.tf`, on `mediacenter`.

## Layout

| Containers | Host | Bind | Exposure |
|---|---|---|---|
| trmnl (web), trmnl-worker, trmnl-database (Postgres), trmnl-keyvalue (Valkey), trmnl-init-certificates | mediacenter | `<mediacenter-100.x>:2300` (web only) | internal (rpi Caddy), `trmnl.ketwork.in` |

Only the web container publishes a port, and only on mediacenter's tailnet
IP — same reasoning as karakeep-backend (`karakeep.md`): the port itself
stays off the LAN. Postgres and Valkey are not published at all; web and
worker reach them over the compose-internal network.

## Addressing

Two separate paths reach the same `web` container, same as arr's apps
(`arr-stack.md`):

- **Device (Kindle) polling**: direct tailnet, `http://mediacenter:2300`
  (bare MagicDNS name, unencrypted). `API_URI` is set to this exact string —
  it must match what the KOReader plugin dials (`kindle-tools`), which
  resolves it through the Kindle's tailscaled SOCKS5/HTTP proxy.
- **Human admin access**: `https://trmnl.ketwork.in`, internal DNS record
  (Cloudflare A -> `rpi_tailscale_ip`, not proxied) + rpi Caddy reverse-proxy
  to `http://mediacenter.tailb3a7a.ts.net:2300` (`group_vars/caddy.yaml`),
  same pattern as `radarr`/`sonarr`/etc. Only reachable from the tailnet or
  LAN, since the A record content isn't a publicly routable address; TLS
  comes from Caddy's Cloudflare DNS-01 ACME.

**Unverified**: whether Terminus/Hanami rejects requests whose `Host` header
(`trmnl.ketwork.in`) doesn't match `API_URI`'s host (`mediacenter`) — no
allowed-hosts config was found in `config/app.rb`, so it's expected to work,
but confirm by actually loading the admin UI through the new domain before
relying on it.

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
4. `curl -sm8 https://trmnl.ketwork.in/` from a tailnet/LAN host returns the
   app with a valid cert; confirms the Caddy reverse-proxy path and rules out
   the Host-header risk noted above.
