# bootstrap/variables.tf

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
  description = "Path to the SSH private key for VPS access. The ~ will be expanded."
  type        = string
  default     = "~/.ssh/id_rsa" # 用户仍然可以输入~，但我们会在使用时处理它
}

variable "cf_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true # 尽管硬编码，标记为sensitive可以在UI输出中隐藏
}

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
  default     = "v1.33.3+k3s1" # Pinning to a specific stable version
}

# -- GitOps 输入 --
variable "gitops_repo_url" {
  description = "The URL of the Git repository for ArgoCD"
  type        = string
}

variable "manage_dns_record" {
  description = "If set to true, Terraform will manage the wildcard DNS A record in Cloudflare. Set to false to skip DNS management if the record already exists or is managed externally."
  type        = bool
  default     = false # 默认关闭DNS管理，以避免因记录已存在而报错
}
