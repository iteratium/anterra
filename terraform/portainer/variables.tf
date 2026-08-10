variable "portainer_api_key" {
  type        = string
  description = "Portainer API access token"
  sensitive   = true
}

variable "domain_name" {
  type        = string
  description = "Base domain, used to build the Portainer API endpoint"
  sensitive   = true
}

variable "mediacenter_endpoint_id" {
  type        = number
  description = "Portainer endpoint id for the mediacenter (local) environment"
  default     = 2
}

variable "vps_endpoint_id" {
  type        = number
  description = "Portainer endpoint id for the vps environment"
  default     = 4
}

variable "rpi_endpoint_id" {
  type        = number
  description = "Portainer endpoint id for the rpi environment"
  default     = 3
}

variable "mediacenter_tailscale_ip" {
  type        = string
  description = "mediacenter Tailscale IP, bind address for the karakeep backend and the address karakeep-web dials"
  sensitive   = true
}

variable "vps_tailscale_ip" {
  type        = string
  description = "vps Tailscale IP, bind address for karakeep-web"
  sensitive   = true
}

variable "karakeep_nextauth_secret" {
  type        = string
  description = "Karakeep NEXTAUTH_SECRET, signs JWT session tokens"
  sensitive   = true
}

variable "meili_master_key" {
  type        = string
  description = "Meilisearch master key, shared by the karakeep-backend and karakeep-web stacks"
  sensitive   = true
}

variable "meili_version" {
  type        = string
  description = "Meilisearch image tag, pinned because upgrades need a manual dump/restore"
  default     = "v1.41.0"
}

variable "filebrowser_version" {
  type        = string
  description = "FileBrowser Quantum image tag; minor-floating on the v2 beta channel so Watchtower applies 2.0.x fixes, while a 2.1/3.x move stays a deliberate PR"
  default     = "2.0-beta"
}

variable "ntfy_version" {
  type        = string
  description = "ntfy image tag, pinned so auth/cache DB migrations happen on a deliberate bump"
  default     = "v2.27.0"
}

variable "cloudflare_edge_ranges" {
  type        = list(string)
  description = "Cloudflare edge IP ranges, stripped from X-Forwarded-For so ntfy sees the real client IP. Source: cloudflare.com/ips-v4 and ips-v6"
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
    "2400:cb00::/32",
    "2606:4700::/32",
    "2803:f800::/32",
    "2405:b500::/32",
    "2405:8100::/32",
    "2a06:98c0::/29",
    "2c0f:f248::/32",
  ]
}

variable "docker_timezone" {
  type        = string
  description = "TZ for the arr containers"
  default     = "Etc/UTC"
}

variable "docker_user_puid" {
  type        = number
  description = "PUID for the arr containers (owns app-data/downloads/media on the host)"
  default     = 1500
}

variable "docker_user_pgid" {
  type        = number
  description = "PGID for the arr containers (media group on the host)"
  default     = 1500
}

variable "config_path" {
  type        = string
  description = "Host base path for container config (fast-store SSD)"
  default     = "/mnt/fast-store/app-data"
}

variable "downloads_path" {
  type        = string
  description = "Host downloads path (fast-store SSD)"
  default     = "/mnt/fast-store/downloads"
}

variable "media_path" {
  type        = string
  description = "Host media library path (bulk-store HDD)"
  default     = "/mnt/bulk-store/media"
}

variable "server_countries" {
  type        = string
  description = "gluetun SERVER_COUNTRIES for AirVPN server selection"
  default     = "Netherlands"
}

variable "outbound_subnets" {
  type        = string
  description = "gluetun FIREWALL_OUTBOUND_SUBNETS: subnets allowed to bypass the VPN killswitch (tailnet + docker bridge) so the WebUIs stay reachable"
  default     = "100.64.0.0/10,172.16.0.0/12"
}

variable "wireguard_private_key" {
  type        = string
  description = "AirVPN WireGuard private key"
  sensitive   = true
}

variable "wireguard_preshared_key" {
  type        = string
  description = "AirVPN WireGuard preshared key"
  sensitive   = true
}

variable "wireguard_addresses" {
  type        = string
  description = "AirVPN WireGuard interface addresses (CIDR)"
  sensitive   = true
}

variable "airvpn_forwarded_port" {
  type        = string
  description = "AirVPN forwarded port for qbittorrent inbound connections"
  sensitive   = true
}
