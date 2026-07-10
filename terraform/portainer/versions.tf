terraform {
  required_version = "~> 1.13"

  cloud {
    organization = "prodigal4176"

    workspaces {
      name = "github-actions-portainer"
    }
  }

  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "~> 1.0"
    }
  }
}
