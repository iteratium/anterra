provider "proxmox" {
  endpoint = "https://${var.pve_host}:8006/"
  insecure = true

  ssh {
    username = "root"

    node {
      name    = "pve"
      address = var.pve_host
    }
  }
}

provider "tailscale" {}
