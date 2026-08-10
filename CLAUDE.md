# Anterra

This repo is a clean rewrite of the previous anterra repo (https://github.com/N28M/anterra)

# Documentation

Documentation stored in .docs
- `.docs/catalog/servers.md` - Inventory
- `.docs/catalog/setup` - Initial state setup documents. 
- `.docs/catalog/plans` - Planned changes, discussions etc.

# Infrastructure

- Dell Optiplex 7060 Micro (pve)
- Raspberry Pi 4B (rpi)
- GreenCloud EPYCSGDC1-1 (vps)

# Facts

- The intention is for all changes to go through GitHub Actions for managing and deploying services to our infrastructure.
- SSH config on this machine allows direct ssh access to rpi, pve and vps. This ssh access can be used by claude or the user.
- Tailscale SSH has also been set up on all the servers.
- This repo is public. Never commit secrets, internal hostnames/IPs, or anything sensitive.

## Working conventions

- Never let secrets (tokens, passwords) pass through chat or a tool-call transcript — have the user enter them directly in their own terminal.
- No emoji in documentation, code, or commits.
- Don't run state-changing commands (`tailscale up` with role-affecting flags, and eventually `terraform apply` / `ansible-playbook`) without explicit permission. Read-only inspection is always fine.
- Create a topic branch for changes; don't commit directly to `main`.
- Keep discussion and documentation terse. State facts and decisions plainly; skip preamble, restatement, and "why" explanations unless the reasoning is non-obvious.

## Behavior

Behavioral guidelines to reduce common LLM coding mistakes.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Secrets

All secrets stored exclusively on Github Secrets

| Secret | Purpose |
|---|---|
| `PROXMOX_API_TOKEN_ID` | `terraform@pve!terraform-gh` — Proxmox provider auth |
| `PROXMOX_API_TOKEN_SECRET` | Proxmox provider auth |
| `TF_API_TOKEN` | HCP Terraform team token — backend auth |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client, scoped to `tag:ci-runner` — joins the GitHub Actions runner to the tailnet |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth client, scoped to `tag:ci-runner` — joins the GitHub Actions runner to the tailnet |
| `TS_OAUTH_MEDIACENTER_CLIENT_ID` | Tailscale OAuth client, scoped to `tag:mediacenter` — mints the mediacenter VM's join key |
| `TS_OAUTH_MEDIACENTER_CLIENT_SECRET` | Tailscale OAuth client, scoped to `tag:mediacenter` — mints the mediacenter VM's join key |
| `PVE_TAILSCALE_HOST` | `pve`'s Tailscale MagicDNS hostname — Proxmox provider `endpoint` and SSH target, kept out of committed `.tf` files |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token — Caddy DNS-01 ACME (rpi, vps) and Terraform `cloudflare` provider |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID — Terraform DNS record management |
| `BASE_DOMAIN` | Base domain — Ansible Caddy records and Terraform DNS record names |
| `RPI_TAILSCALE_IP` | rpi Tailscale IP — Terraform A-record target for internal services |
| `VPS_PUBLIC_IP` | vps public IP — Terraform A-record target for external services |
| `UNIFI_CONSOLE_IP` | Unifi console LAN IP — Caddy upstream for the `ui` record (Ansible) |
| `PORTAINER_API_KEY` | Portainer API access token — `portainer` provider auth (Terraform portainer workspace) |
| `WIREGUARD_PRIVATE_KEY` | AirVPN WireGuard private key — gluetun (arr stack) |
| `WIREGUARD_PRESHARED_KEY` | AirVPN WireGuard preshared key — gluetun (arr stack) |
| `WIREGUARD_ADDRESSES` | AirVPN WireGuard interface addresses — gluetun (arr stack) |
| `AIRVPN_FORWARDED_PORT` | AirVPN forwarded port — qbittorrent inbound via gluetun |
| `MEDIACENTER_TAILSCALE_IP` | mediacenter Tailscale IP — karakeep-backend bind address, dialled by karakeep-web |
| `VPS_TAILSCALE_IP` | vps Tailscale IP — karakeep-web bind address |
| `KARAKEEP_NEXTAUTH_SECRET` | Karakeep `NEXTAUTH_SECRET` — session JWT signing |
| `MEILI_MASTER_KEY` | Meilisearch master key — shared by the karakeep-backend and karakeep-web stacks |
