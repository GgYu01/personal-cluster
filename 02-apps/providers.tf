# 02-apps/providers.tf

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

# Configure providers dynamically using credentials from the infra remote state.
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.cluster_host
  cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.infra.outputs.client_certificate
  client_key             = data.terraform_remote_state.infra.outputs.client_key
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.infra.outputs.cluster_host
    cluster_ca_certificate = data.terraform_remote_state.infra.outputs.cluster_ca_certificate
    client_certificate     = data.terraform_remote_state.infra.outputs.client_certificate
    client_key             = data.terraform_remote_state.infra.outputs.client_key
  }
}