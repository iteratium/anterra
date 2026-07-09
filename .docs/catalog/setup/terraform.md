# Terraform — External Setup

Manual, one time steps completed in [HCP Terraform](https://app.terraform.io)

## HCP Terraform

- Org: `prodigal4176`
- Project: `anterra`
- Workspace: `github-actions`
- **Execution Mode: Local** — set explicitly;
- Auth: a Team API token (`owners` team). Stored as `TF_API_TOKEN` in GitHub Actions secrets.

### Providers

- **`bpg/proxmox`**
- **`tailscale/tailscale`** (official provider)

Pin providers to latest version. Plan updates to newer versions every 6 months.
