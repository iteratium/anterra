locals {
  internal_services = toset([
    "portainer",
    "pve",
    "ui",
  ])

  external_services = {
    jellyfin = { proxied = false }
  }
}

resource "cloudflare_dns_record" "internal" {
  for_each = local.internal_services

  zone_id = var.cloudflare_zone_id
  name    = "${each.value}.${var.domain_name}"
  content = var.rpi_tailscale_ip
  type    = "A"
  proxied = false
  ttl     = 1
  comment = "Managed by Terraform"
}

resource "cloudflare_dns_record" "external" {
  for_each = local.external_services

  zone_id = var.cloudflare_zone_id
  name    = "${each.key}.${var.domain_name}"
  content = var.vps_public_ip
  type    = "A"
  proxied = try(each.value.proxied, true)
  ttl     = 1
  comment = "Managed by Terraform"
}
