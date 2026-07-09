terraform {
  required_version = "~> 1.13"

  cloud {
    organization = "prodigal4176"

    workspaces {
      name = "github-actions"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.111.1"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.2"
    }
  }
}
