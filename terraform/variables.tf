variable "pve_host" {
  type        = string
  description = "pve's Tailscale hostname, used for the Proxmox API endpoint and SSH snippet upload"
  sensitive   = true
}
