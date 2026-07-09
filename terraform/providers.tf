provider "proxmox" {
  endpoint = "https://pve.tailb3a7a.ts.net:8006/"
  insecure = true

  ssh {
    username = "root"
  }
}

provider "tailscale" {}
