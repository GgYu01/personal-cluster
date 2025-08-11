# 01-infra/outputs.tf

# Output the result of the DNS record check.
# The shell script will parse this JSON to determine if the record exists.
output "dns_check_result" {
  value     = data.cloudflare_records.wildcard_check.records
  sensitive = true
}

# Output the raw kubeconfig content for the shell script to consume.
output "kubeconfig_content" {
  value     = nonsensitive(resource.terraform_data.k3s_install.id) != "" ? tostring(trimsuffix(shell_script.fetch_kubeconfig[0].output, "\n")) : ""
  sensitive = true
}

# Use a data source to fetch the kubeconfig only after k3s_install is complete.
# This avoids running the command during 'plan' phase.
data "shell_script" "fetch_kubeconfig" {
  count = nonsensitive(resource.terraform_data.k3s_install.id) != "" ? 1 : 0

  lifecycle_commands {
    read = "ssh -i ${pathexpand(var.ssh_private_key_path)} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${var.vps_ip} 'cat /etc/rancher/k3s/k3s.yaml'"
  }
}
