# 01-infra/providers.tf

terraform {
  required_providers {
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

# The 'cloudflare' provider block has been completely removed.
