provider "portainer" {
  endpoint = "https://portainer.${var.domain_name}"
  api_key  = var.portainer_api_key
}
