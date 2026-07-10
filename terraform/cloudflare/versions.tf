terraform {
  required_version = "~> 1.13"

  cloud {
    organization = "prodigal4176"

    workspaces {
      name = "github-actions-cloudflare"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}
