terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    tailscale = {
      source = "tailscale/tailscale"
    }
  }
}
