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
    server_countries        = var.server_countries
    outbound_subnets        = var.outbound_subnets
    vpn_input_port          = var.airvpn_forwarded_port
    wireguard_private_key   = var.wireguard_private_key
    wireguard_preshared_key = var.wireguard_preshared_key
    wireguard_addresses     = var.wireguard_addresses
    profilarr_pat           = var.profilarr_pat
    git_user_name           = var.git_user_name
    git_user_email          = var.git_user_email
  })
}
