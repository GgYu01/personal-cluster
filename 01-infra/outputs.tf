# 01-infra/outputs.tf

# Parse the raw kubeconfig content using yamldecode.
locals {
  kubeconfig_raw = yamldecode(data.remote_file.k3s_kubeconfig_remote.content)
}

# Output the API server endpoint.
output "cluster_host" {
  description = "The FQDN of the Kubernetes API server."
  value       = replace(local.kubeconfig_raw.clusters[0].cluster.server, "https://127.0.0.1:6443", "https://${local.api_server_fqdn}:6443")
}

# Output the cluster CA certificate.
output "cluster_ca_certificate" {
  description = "The CA certificate for the Kubernetes cluster."
  value       = base64decode(local.kubeconfig_raw.clusters[0].cluster.certificate-authority-data)
  sensitive   = true
}

# Output the client certificate.
output "client_certificate" {
  description = "The client certificate for authenticating to the cluster."
  value       = base64decode(local.kubeconfig_raw.users[0].user.client-certificate-data)
  sensitive   = true
}

# Output the client key.
output "client_key" {
  description = "The client key for authenticating to the cluster."
  value       = base64decode(local.kubeconfig_raw.users[0].user.client-key-data)
  sensitive   = true
}

output "cluster_base_domain" {
  description = "The full base domain of the cluster, for use in the apps stage."
  value       = local.cluster_base_domain
}

# For convenience, output a ready-to-use kubeconfig content
output "kubeconfig_content" {
  description = "Raw kubeconfig content for manual access."
  sensitive   = true
  value = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_host           = replace(local.kubeconfig_raw.clusters[0].cluster.server, "https://127.0.0.1:6443", "https://${local.api_server_fqdn}:6443")
    cluster_ca_certificate = local.kubeconfig_raw.clusters[0].cluster.certificate-authority-data
    client_certificate     = local.kubeconfig_raw.users[0].user.client-certificate-data
    client_key             = local.kubeconfig_raw.users[0].user.client-key-data
  })
}