# Caddy — Reverse Proxy via Ansible

Caddy install and config on `rpi` (internal) and `vps` (external) are managed by
`ansible/playbooks/caddy.yml`, mirroring the old repo's approach adapted to this
repo's public/no-vault constraints.

## Layout

- `inventory/hosts.yaml` — `caddy` group: `rpi`, `vps`.
- `inventory/group_vars/caddy.yaml` — record data. `internal_reverse_proxy_records`
  (served by `rpi`), `external_reverse_proxy_records` (served by `vps`).
- `playbooks/templates/reverse_proxy.caddy.j2` — renders records for the host.
- `playbooks/caddy.yml` — single play: installs Caddy (binary with the
  `caddy-dns/cloudflare` plugin, `caddy` user, systemd unit), writes the base
  Caddyfile, and templates `/etc/caddy/conf.d/reverse_proxy.caddy`, reloading on
  change.

## Design

- **Playbook fully owns the Caddyfile.** It overwrites `/etc/caddy/Caddyfile`
  with a fixed base (global DNS-01 ACME block + `import conf.d/*.caddy`) and owns
  `conf.d/reverse_proxy.caddy`. The old-repo hand-managed Caddyfile is discarded
  (backed up separately). Add records via `group_vars/caddy.yaml`.
- **Domain via GitHub Secret.** Records use `{{ domain_name }}`; the real base
  domain is injected at apply time from the `BASE_DOMAIN` secret
  (`--extra-vars`). The domain is never committed (repo is public).
- **Upstreams as tailnet MagicDNS.** `host.tailb3a7a.ts.net:port`. Caddy runs as
  a host systemd service and resolves MagicDNS, so no committed LAN IPs. The
  `ui` upstream is the exception — the Unifi console is on the LAN, so its IP is
  injected from the `UNIFI_CONSOLE_IP` secret as `{{ unifi_console_ip }}`.
- **TLS via Cloudflare DNS-01.** Caddy obtains certs with the `cloudflare` DNS
  plugin using `CLOUDFLARE_API_TOKEN`, written to `/etc/caddy/cloudflare_token`
  and loaded by the systemd unit as `EnvironmentFile`. The token is passed to the
  playbook as an env var (never committed, never on the command line).

## Secrets

- `BASE_DOMAIN` — base domain (e.g. `example.com`), injected via `--extra-vars`.
- `CLOUDFLARE_API_TOKEN` — Cloudflare token for DNS-01 ACME (shared with the
  Terraform `cloudflare` provider). See `.docs/catalog/plans/cloudflare.md`.
- `UNIFI_CONSOLE_IP` — Unifi console LAN IP, upstream for the `ui` record.

All wired into `ansible-apply.yml` and the `ansible-check.yml` preview step.

## Record list

- Internal (`rpi`): `pve` (`https://pve.tailb3a7a.ts.net:8006`), `portainer`
  (`https://mediacenter.tailb3a7a.ts.net:9443`), `ui`
  (`https://{{ unifi_console_ip }}:443`) — all `tls_skip_verify: true`.
- External (`vps`): `jellyfin` (`http://mediacenter.tailb3a7a.ts.net:8096`).

Set `tls_skip_verify: true` for HTTPS upstreams with self-signed certs. Grow the
lists as services are added.
