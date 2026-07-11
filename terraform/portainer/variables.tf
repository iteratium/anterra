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
