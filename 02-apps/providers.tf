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
  }
}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_host
    cluster_ca_certificate = var.cluster_ca_certificate
    client_certificate     = var.client_certificate
    client_key             = var.client_key
  }
}

provider "kubectl" {
  host                   = var.cluster_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  load_config_file       = false
}
