# Terraform — External Setup

Manual, one time steps completed in [HCP Terraform](https://app.terraform.io)

## HCP Terraform

- Org: `prodigal4176`
- Project: `anterra`
- Workspaces: `github-actions` (infra), `github-actions-cloudflare`, `github-actions-portainer`
- **Execution Mode: Local on every workspace** — set explicitly. Remote runs execute on
  HCP's servers, which are not on the tailnet, so any apply that must reach pve or an
  internal service (e.g. the Portainer stack endpoint) fails from Remote mode.
- Auth: a Team API token (`owners` team). Stored as `TF_API_TOKEN` in GitHub Actions secrets.

### Providers

- **`bpg/proxmox`**
- **`tailscale/tailscale`** (official provider)

Pin providers to latest version. Plan updates to newer versions every 6 months.
