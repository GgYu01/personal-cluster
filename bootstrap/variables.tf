# bootstrap/variables.tf
variable "vps_ip" {
  description = "Public IP of the VPS"
  type        = string
  default     = "172.245.187.113"
}

variable "domain_name" {
  description = "Your root domain name"
  type        = string
  default     = "gglohh.top"
}

variable "ssh_user" {
  description = "SSH user for the VPS"
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for VPS access"
  type        = string
  default     = "~/.ssh/id_rsa"
}