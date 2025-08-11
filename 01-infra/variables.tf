# 01-infra/variables.tf

# -- 基础架构输入 --
variable "vps_ip" {
  description = "Public IP of the VPS"
  type        = string
}

variable "domain_name" {
  description = "Your root domain name"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for the VPS"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for VPS access."
  type        = string
  default     = "~/.ssh/id_rsa"
}

# The 'cf_api_token' variable has been removed.

# -- 逻辑集群与环境输入 --
variable "site_code" {
  description = "A code for the physical or logical site (e.g., core01, us-west)"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., prod, dev)"
  type        = string
}

# -- K3s 版本输入 --
variable "k3s_version" {
  description = "The specific version of K3s to install."
  type        = string
  default     = "v1.33.3+k3s1"
}

# -- GitOps 输入 --
variable "gitops_repo_url" {
  description = "The URL of the Git repository for ArgoCD"
  type        = string
}

# The 'manage_dns_record' variable has been removed.

variable "k3s_cluster_token" {
  description = "A shared secret for K3s servers to join the same cluster."
  type        = string
  sensitive   = true
  default     = "admin" # Using the simple token as requested
}
