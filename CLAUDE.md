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

## Secrets

All secrets stored exclusively on Github Secrets

| Secret | Purpose |
|---|---|
| `PROXMOX_API_TOKEN_ID` | `terraform@pve!terraform-gh` — Proxmox provider auth |
| `PROXMOX_API_TOKEN_SECRET` | Proxmox provider auth |
| `TF_API_TOKEN` | HCP Terraform team token — backend auth |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client — mints the VM's join key |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth client — mints the VM's join key |
