resource "portainer_stack" "arr" {
  name            = "arr"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.mediacenter_endpoint_id

  stack_file_content = templatefile("${path.module}/compose-files/arr.yaml.tpl", {
    docker_user_puid        = var.docker_user_puid
    docker_user_pgid        = var.docker_user_pgid
    docker_timezone         = var.docker_timezone
    docker_config_path      = var.config_path
    docker_downloads_path   = var.downloads_path
    docker_media_path       = var.media_path
    domain_name             = var.domain_name
    server_countries        = var.server_countries
    outbound_subnets        = var.outbound_subnets
    vpn_input_port          = var.airvpn_forwarded_port
    wireguard_private_key   = var.wireguard_private_key
    wireguard_preshared_key = var.wireguard_preshared_key
    wireguard_addresses     = var.wireguard_addresses
  })
}

resource "portainer_stack" "karakeep_backend" {
  name            = "karakeep-backend"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.mediacenter_endpoint_id

  stack_file_content = templatefile("${path.module}/compose-files/karakeep-backend.yaml.tpl", {
    mediacenter_tailscale_ip = var.mediacenter_tailscale_ip
    meili_master_key         = var.meili_master_key
    meili_version            = var.meili_version
  })
}

resource "portainer_stack" "kindle_dashboard" {
  name            = "kindle-dashboard"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.rpi_endpoint_id

  stack_file_content = file("${path.module}/compose-files/kindle-dashboard.yaml")
}

resource "portainer_stack" "karakeep_web" {
  name            = "karakeep-web"
  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.vps_endpoint_id

  stack_file_content = templatefile("${path.module}/compose-files/karakeep-web.yaml.tpl", {
    domain_name              = var.domain_name
    vps_tailscale_ip         = var.vps_tailscale_ip
    mediacenter_tailscale_ip = var.mediacenter_tailscale_ip
    nextauth_secret          = var.karakeep_nextauth_secret
    meili_master_key         = var.meili_master_key
  })
}
