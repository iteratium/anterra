variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token for the cloudflare provider"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for the managed domain"
  sensitive   = true
}

variable "domain_name" {
  type        = string
  description = "Base domain, used to build DNS record names"
  sensitive   = true
}

variable "rpi_tailscale_ip" {
  type        = string
  description = "rpi Tailscale IP, A-record target for internal services"
  sensitive   = true
}

variable "vps_public_ip" {
  type        = string
  description = "vps public IP, A-record target for external services"
  sensitive   = true
}
