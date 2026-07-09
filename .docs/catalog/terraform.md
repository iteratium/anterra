# Terraform — External Setup

Manual, one-time steps completed in HCP Terraform (Terraform Cloud), Proxmox,
and Tailscale, ahead of writing the `terraform/` configs themselves. This is
the external-service counterpart to `setup/pve.md` — state that lives outside
the repo but that Terraform depends on.

## HCP Terraform

- Org: `prodigal4176`
- Project: `anterra` (already existed before this work)
- Workspace: `github-actions` — CLI-driven workflow, shared across all future
  Terraform changes rather than one workspace per stack/VM
- **Execution Mode: Local** — set explicitly; HCP Terraform defaults new
  workspaces to Remote execution, which would run `plan`/`apply` inside
  HCP Terraform's own environment instead of GitHub Actions. Local means the
  workspace only holds state; the actual runs happen on the GitHub-hosted
  runner (see `ci-cd.md` for why there's no persistent control node).
- Auth: a Team API token (`owners` team), not a personal user token — keeps
  the CI credential independent of any one person's account. Stored as
  `TF_API_TOKEN` in GitHub Actions secrets.

## Providers

- **`bpg/proxmox`**, not `Telmate/proxmox` — actively maintained, covers far
  more of the Proxmox API, and specifically supports referencing a PCI
  resource mapping by name (the `mapping` attribute on a `hostpci` block)
  instead of a raw per-node PCI address. That's exactly what the `intel-igpu`
  resource mapping (see `setup/pve.md`) is for, so this was close to a
  required choice, not just a preference.
- **`tailscale/tailscale`** (official provider) — used only for the
  `tailscale_tailnet_key` resource, to mint a fresh join key on every
  `apply` rather than storing a static long-lived auth key. Tailscale auth
  keys have a hard 90-day expiry cap; generating one at apply-time and
  consuming it immediately avoids a recurring manual-rotation task.

Version pins to use once `terraform/` is scaffolded (current as of this
writing — check for newer before pinning if significant time has passed):
`bpg/proxmox` v0.111.1, `tailscale/tailscale` v0.29.2.

## Proxmox

See `setup/pve.md` for the full detail: `terraform@pve` user, scoped
permissions (`PVEVMAdmin`/`PVEDatastoreUser`/`PVEMappingUser`), the
`terraform-gh` API token, and the cloud-init template (VMID 9000, Ubuntu
26.04 minimal, OVMF/q35).

## Tailscale

See `setup/tailscale.md` (`tag:mediacenter` section) for the ACL policy
changes. Summary of the join-key design: a Tailscale OAuth client, scoped to
`Auth Keys: Write` and restricted to `tag:mediacenter`, lets the
`tailscale_tailnet_key` Terraform resource mint a key that is non-ephemeral
(this is a persistent VM, not a CI-style ephemeral runner), single-use
(`reusable = false` — a fresh one is minted per apply rather than reused),
and pre-authorized (skips the manual admin-console approval step a headless
join would otherwise need).

Disabling key expiry on the device itself is still a manual, per-device
admin-console step that has to happen after the VM's first boot — it has no
ACL-policy or auth-key equivalent.

## Secrets summary (GitHub Actions)

| Secret | Purpose |
|---|---|
| `PROXMOX_API_TOKEN_ID` | `terraform@pve!terraform-gh` — Proxmox provider auth |
| `PROXMOX_API_TOKEN_SECRET` | Proxmox provider auth |
| `TF_API_TOKEN` | HCP Terraform team token — backend auth |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client — mints the VM's join key |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth client — mints the VM's join key |

All of the above were entered directly into GitHub Actions secrets by hand;
none were pasted through chat or committed to the repo.
