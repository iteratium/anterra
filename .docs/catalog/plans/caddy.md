# Caddy — Reverse Proxy via Ansible

Caddy is installed and running on `rpi` (internal) and `vps` (external). Config
is managed by `ansible/playbooks/caddy.yml`, mirroring the old repo's approach
adapted to this repo's public/no-vault constraints.

## Layout

- `inventory/hosts.yaml` — `caddy` group: `rpi`, `vps`.
- `inventory/group_vars/caddy.yaml` — record data. `internal_reverse_proxy_records`
  (served by `rpi`), `external_reverse_proxy_records` (served by `vps`).
- `playbooks/templates/reverse_proxy.caddy.j2` — renders records for the host.
- `playbooks/caddy.yml` — ensures `import conf.d/*.caddy` in the Caddyfile,
  templates `/etc/caddy/conf.d/reverse_proxy.caddy`, reloads on change.

## Design

- **Managed via import, not the Caddyfile.** The playbook adds a single
  `import /etc/caddy/conf.d/*.caddy` line to the existing Caddyfile (additive,
  non-destructive) and owns only `conf.d/reverse_proxy.caddy`. Existing manual
  routes keep working; migrate them into the record list incrementally.
- **Domain via GitHub Secret.** Records use `{{ domain_name }}`; the real base
  domain is injected at apply time from the `CADDY_DOMAIN` secret
  (`--extra-vars`). The domain is never committed (repo is public).
- **Upstreams as tailnet MagicDNS.** `host.tailb3a7a.ts.net:port`. Caddy runs as
  a host systemd service and resolves MagicDNS, so no committed LAN IPs.

## Secret

Add `CADDY_DOMAIN` to GitHub Actions secrets — the base domain (e.g.
`example.com`). Wired into `ansible-apply.yml` and the `ansible-check.yml`
preview step.

## Record list

Seeded with confirmed records only (`portainer`, `pve`, `jellyfin`). Grow
`group_vars/caddy.yaml` as services are migrated off the hand-written Caddyfile;
set `tls_skip_verify: true` for HTTPS upstreams with self-signed certs.
