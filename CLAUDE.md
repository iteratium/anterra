# Anterra

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

- Deploy only via GitHub Actions; never run `terraform apply` or `ansible-playbook` locally.
- rpi, pve and vps are reachable via ssh from this machine (plain and Tailscale SSH), by Claude or the user.
- This repo is public. Never commit secrets, internal hostnames/IPs, or anything sensitive.
- All secrets live in GitHub Secrets; the `env:` blocks in `.github/workflows/` list them.

## Working conventions

- Never let secrets (tokens, passwords) pass through chat or a tool-call transcript — have the user enter them directly in their own terminal.
- No emoji in documentation, code, or commits.
- Don't run state-changing commands (e.g. `tailscale up` with role-affecting flags) without explicit permission. Read-only inspection is always fine.
- Create a topic branch for changes; don't commit directly to `main`.
- Touch only what the request needs; mention unrelated issues instead of fixing them.
- Keep discussion and documentation terse. State facts and decisions plainly; skip preamble, restatement, and "why" explanations unless the reasoning is non-obvious.
