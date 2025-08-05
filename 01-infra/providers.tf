# bootstrap/providers.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.8.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    remote = {
      source  = "tenstad/remote"
      version = "0.2.1"
    }
  }
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

