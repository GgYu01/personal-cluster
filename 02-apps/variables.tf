# 02-apps/variables.tf

variable "gitops_repo_url" {
  type        = string
  description = "The URL of the Git repository for ArgoCD."
}

variable "cluster_host" {
  description = "The FQDN of the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "The CA certificate for the Kubernetes cluster (PEM format)."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "The client certificate for authenticating to the cluster (PEM format)."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "The client key for authenticating to the cluster (PEM format)."
  type        = string
  sensitive   = true
}
