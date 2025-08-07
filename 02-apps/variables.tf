# 02-apps/variables.tf

variable "gitops_repo_url" {
  type        = string
  description = "The URL of the Git repository for ArgoCD."
}
