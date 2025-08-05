# 02-apps/variables.tf

variable "gitops_repo_url" {
  description = "The URL of the Git repository for ArgoCD"
  type        = string
}

variable "cluster_base_domain" {
  description = "The base domain of the cluster (e.g., core01.prod.gglohh.top), passed from the infra stage."
  type        = string
}