# ntfy

Push notification server. Deployed as a Portainer stack on vps from
`terraform/portainer/stacks.tf`.

## Status

Deployed. Merged via #40, applied to vps, and bootstrapped:

| File | Change |
|---|---|
| `terraform/portainer/compose-files/ntfy.yaml.tpl` | new, stack definition |
| `terraform/portainer/stacks.tf` | `portainer_stack.ntfy` on `vps_endpoint_id` |
| `terraform/portainer/variables.tf` | `ntfy_version`, `cloudflare_edge_ranges` |
| `terraform/cloudflare/cloudflare.tf` | `ntfy = { proxied = true }` |
| `ansible/inventory/group_vars/caddy.yaml` | external record -> `vps:9722` |

No new GitHub Secrets were needed for the stack itself. The first `terraform
apply` after merge hit a transient Portainer 409 ("deployment already in
progress") on stack creation, which left `portainer_stack.ntfy` needing
`terraform untaint` (run via the `terraform-untaint.yml` workflow) before a
clean re-apply; the stack itself came up fine on the Portainer side.

Bootstrap (below) is complete: admin and `publisher` users created, and the
`publisher` token is stored as the `NTFY_PUBLISH_TOKEN` GitHub Secret. Phone
app logged in as admin and confirmed notifications deliver correctly through
the Cloudflare proxy.

`NTFY_PUBLISH_TOKEN` is consumed by Seerr's built-in ntfy notification agent
(server URL + token + notification types set in the Seerr UI directly, no
generic webhook needed) — confirmed working with a test notification for
media-available alerts.

Remaining: none. Future publishers (mediacenter/pve/rpi scripts) can reuse the
same token.

## Layout

| Stack | Host | Bind |
|---|---|---|
| `ntfy` | vps | `<vps-100.x>:9722` -> 80 |

Exposure follows the `keep` shape: DNS -> vps public IP -> vps Caddy ->
`http://vps.tailb3a7a.ts.net:9722`. Caddy and the container both live on vps,
so the tailnet hop is a local loopback.

## Placement

vps, not rpi. The receiving side is a long-lived stream from the phone; on vps
it terminates at the public edge with no dependency on the home WAN. Hosting it
at home would mean a home outage kills both publish and receive — the one alert
most worth having. Publishers (mediacenter, pve, rpi) POST over the tailnet;
small, infrequent requests, so the Singapore RTT is irrelevant in that
direction.

## DNS

`proxied = true` (orange-cloud), matching `keep`/`seerr`/`papra`.

This is a public endpoint on a 1 vCPU / 2 GiB box with little spare RAM.
Cloudflare filters L7 DDoS, bot traffic and known-bad IPs at the edge, so that
load never reaches the origin — worth more here than on a machine with
headroom, and ntfy's login endpoint is a standard scanner target. Origin-IP
concealment is not the motivation and would not work anyway: `jellyfin`
grey-clouds the same `vps_public_ip`, so the address is already public.

The cost is an extra hop in `X-Forwarded-For`. Cloudflare forwards the real
client IP, but Caddy then appends its own peer, so ntfy sees
`realClient, cfEdgeIP`. `NTFY_PROXY_TRUSTED_HOSTS` carries Cloudflare's edge
ranges (`var.cloudflare_edge_ranges`) so the edge hop is stripped and the real
client IP survives. Without it, ntfy rate limits every visitor as if they were
one — the failure its docs call out explicitly.

Refresh those ranges from `cloudflare.com/ips-v4` and `ips-v6` if they ever
change; they are stable over years, not months.

## Auth

`NTFY_AUTH_DEFAULT_ACCESS=deny-all` — anonymous access to every topic is
refused, read and write. `NTFY_ENABLE_SIGNUP=false`, so the public endpoint
cannot mint accounts; users are created on the box with the ntfy CLI.

Two principals:

- an admin user, used by the phone/desktop apps to subscribe
- a `publisher` user with write-only access, whose token the servers use

## Bootstrap

There is no admin web UI — user provisioning is CLI-only. The web app at
`https://ntfy.{{ domain }}` handles login, subscribing and self-service account
management, but cannot create or manage other users.

After the stack is up, run on vps (enter the passwords directly — they must not
pass through a tool transcript):

```
docker exec -it ntfy ntfy user add --role=admin <admin-name>
docker exec -it ntfy ntfy user add publisher
docker exec -it ntfy ntfy access publisher '*' write-only
docker exec -it ntfy ntfy token add --label="servers" publisher
```

`user add` prompts for the password and confirms it, hence `-it`. The admin
user needs no `ntfy access` entry; the admin role implies read-write on all
topics. No chicken-and-egg despite `deny-all` and signup being off: the CLI
writes to the auth DB directly and does not authenticate. It finds the right DB
because `NTFY_AUTH_FILE` is set on the container and `docker exec` inherits the
container environment.

The last command prints a `tk_...` token. That becomes the `NTFY_PUBLISH_TOKEN`
GitHub Secret when the first publisher is wired up; nothing in this repo
consumes it yet.

### Declarative provisioning — deferred

ntfy also supports provisioning via `auth-users` / `auth-access` /
`auth-tokens`, taking `<user>:<bcrypt-hash>:<role>` entries (hash from
`ntfy user hash`). Better fit for this repo — users in version control,
reproducible if the volume is lost. Deferred for two reasons:

- Bcrypt hashes start with `$2a$10$...` and Portainer interpolates `$` in
  compose stacks, so every hash needs `$$` doubling through the
  terraform-template -> Portainer -> compose chain. Untestable without a
  running stack.
- Config-provisioned users are marked as such, and removing one from the config
  **deletes it from the database** on restart, taking its tokens with it.

Revisit once the transport is proven and the escaping can be checked against a
live stack.

## iOS

`NTFY_UPSTREAM_BASE_URL=https://ntfy.sh` is set, which is required for iOS push:
ntfy.sh holds the APNs certificate, so a self-hosted server has to ask it to
wake the device. The forwarded poll request carries a SHA256 of the topic name
and nothing else — no message body, title, or priority. The phone then fetches
the actual message from this server directly.

Drop this line if iOS ever leaves the picture; Android and desktop do not use
it.

## Attachments

Disabled — `attachment-cache-dir` is left unset. vps has ~16 G free and no
reason to become a file host.

## Versions

Image tag pinned via `var.ntfy_version`, no Watchtower label. Upgrades are a
deliberate PR, since bumps can migrate the auth and cache DBs.

## Verify after deploy

Instant delivery through the Cloudflare proxy is the one claim not settled by
documentation — ntfy's docs do not mention Cloudflare at all. Subscriptions are
held-open streams and edge compression is known to buffer SSE in some
configurations; ntfy's 45s keepalive is designed for exactly this and will
probably be fine.

Test: subscribe on the phone, publish from another machine, confirm arrival is
immediate rather than delayed or batched. If it misbehaves, in order:

1. the WebSocket endpoint (`/topic/ws`), not subject to compression buffering
2. a Cloudflare rule disabling compression for the hostname
3. grey-cloud as the fallback, accepting the loss of edge filtering

Also inherited from the proxy: Cloudflare's free-plan 100 MB request body cap.
Irrelevant while attachments are off; remember it if they are ever enabled.
