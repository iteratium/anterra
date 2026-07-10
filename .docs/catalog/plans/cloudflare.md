# Cloudflare — DNS via Terraform

Cloudflare holds the DNS records; Caddy (see `caddy.md`) holds the reverse-proxy
routes. Records are managed in the root Terraform config, applied by the existing
`terraform-apply.yml` / `terraform-plan.yml` workflows (single HCP workspace).

No state import: the old repo's records were deleted from Cloudflare, so
Terraform creates them fresh.

## Layout

- `terraform/cloudflare.tf` — `internal_services` / `external_services` locals and
  the two `cloudflare_dns_record` resources.
- `terraform/providers.tf` — `cloudflare` provider, `api_token = var.cloudflare_api_token`.
- `terraform/variables.tf` — `cloudflare_api_token`, `cloudflare_zone_id`,
  `domain_name`, `rpi_tailscale_ip`, `vps_public_ip` (all sensitive).

## Design

- **Internal services -> rpi Tailscale IP**, `proxied = false`. Reachable only on
  the tailnet; Cloudflare provides DNS + TLS (DNS-01), not proxying.
- **External services -> vps public IP**, `proxied = true` by default. Publicly
  reachable through the Cloudflare edge. Per-service `{ proxied = false }` opts a
  record into DNS-only (required for media/streaming per Cloudflare ToS, e.g.
  `jellyfin`).
- **Record names built from `domain_name`.** `name = "<sub>.${domain_name}"`,
  domain injected from the `BASE_DOMAIN` secret. Nothing domain- or IP-specific
  is committed (repo is public).
- **Adding a service is two edits:** the Caddy record in
  `ansible/inventory/group_vars/caddy.yaml` and the entry here. They are separate
  pipelines with no shared source of truth.

## Record list

Seeded to match Caddy: internal `portainer`, `pve`, `ui` (-> rpi Tailscale IP);
external `jellyfin` (-> vps public IP, DNS-only per Cloudflare media ToS). Grow
the locals as services are added.

## Secrets

- `CLOUDFLARE_API_TOKEN` — provider auth (shared with Caddy DNS-01).
- `CLOUDFLARE_ZONE_ID` — the managed zone.
- `BASE_DOMAIN` — base domain for record names (shared with Ansible).
- `RPI_TAILSCALE_IP` — internal A-record target.
- `VPS_PUBLIC_IP` — external A-record target.

Wired as `TF_VAR_*` in `terraform-apply.yml` and `terraform-plan.yml`.
