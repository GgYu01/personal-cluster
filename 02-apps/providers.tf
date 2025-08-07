# 02-apps/providers.tf (FINAL REVISION v5 - Corrected Encoding & Unified Logic)

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.infra.outputs.cluster_host
    cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
    client_certificate     = data.terraform_remote_state.infra.outputs.client_certificate
    client_key             = data.terraform_remote_state.infra.outputs.client_key
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_host
  # CORRECTED: Pass the raw PEM strings directly, without re-encoding.
  cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.infra.outputs.client_certificate
  client_key             = data.terraform_remote_state.infra.outputs.client_key
  load_config_file       = false
}