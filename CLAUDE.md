# Anterra

IaC, state, and docs for a 3-site home server (India compute · Singapore
gateway · Japan clients), Tailscale-bridged. This repo is a **clean rewrite**
of the previous `anterra` repo (https://github.com/N28M/anterra, now under
`home-server/anterra/` on this machine) — not a fork or migration. Treat that
old repo as historical reference only; don't port/copy its playbooks, Terraform
modules, Portainer stacks, or vault secrets into this one.

**Reused from the old setup**: only the physical/virtual machines and their
already-installed OS — `pve` (Dell Optiplex 3060 Micro, India), `rpi`
(Raspberry Pi 4B, India), `vps` (GreenCloud EPYCSGDC1-1, Singapore). All three
are remote, so "fresh start" means the guest/config layer, not bare metal.
Everything else (Ansible, Terraform, CI, docs) starts from scratch here.

## Docs map

- `.docs/catalog/servers.md` — fleet inventory (physical + virtual hosts by
  site). Intentionally has no "clients" section — Japan clients are out of
  scope for this catalog.
- `.docs/catalog/setup/{pve,rpi,vps}.md` — manual, one-time per-host setup
  steps completed so far (ZFS pools, Tailscale `up` invocations and their
  host-specific gotchas). Read before assuming a host's state.
- `.docs/catalog/setup/tailscale.md` — fleet-wide Tailscale ACL policy (SSH
  access via `group:fleet-admins`, `tag:peer-relay` for `vps`, key-expiry
  decision). Not duplicated per host.
- `.docs/catalog/ci-cd.md` — the planned CI/CD design (not yet built): no
  control node, GitHub-hosted runners joining the tailnet ephemerally,
  GitHub Actions secrets only (no Bitwarden/vault), Terraform Cloud for
  state, single `site.yml` Ansible entrypoint, auto-plan/check on PR with
  approval-gated apply on merge, GitHub Flow branching. Read this in full
  before discussing or building automation — it has the reasoning behind
  each choice, not just the choice.

## Key fleet facts worth knowing up front

- `vps` is a Tailscale **Peer Relay** and is **tag-owned** (`tag:peer-relay`),
  not user-owned — ACL rules scoped to `autogroup:self` don't reach it.
- `rpi` is the India LAN's subnet router (`10.0.0.0/22`) and exit node.
  Any host directly on that LAN (`pve`) must run
  `tailscale up --accept-routes=false` explicitly, or it will accept `rpi`'s
  advertised route and break its own local LAN reachability.
- Tailscale key expiry is disabled for `pve`, `rpi`, `vps` — Tailscale SSH is
  the primary access path, so an expired key means total lockout with no
  fallback.

## Working conventions

- Never let secrets (tokens, passwords) pass through chat or a tool-call
  transcript — have the user enter them directly in their own terminal.
- No emoji in documentation, code, or commits.
- Don't run state-changing commands (`tailscale up` with role-affecting
  flags, and eventually `terraform apply` / `ansible-playbook`) without
  explicit permission. Read-only inspection is always fine.
