# 01-infra/c3-k3s-cluster.tf (CORRECTED)

# NOTE: All 'variable' blocks have been REMOVED from this file.
# The single source of truth for variable declarations is now 'variables.tf'.

# This resource depends on the etcd setup from c2-vps-setup.tf
# It is responsible for installing K3s with the correct parameters.
resource "terraform_data" "k3s_install" {
  depends_on = [terraform_data.vps_setup]

  # Rerun this resource on every 'apply' to ensure the latest configuration is enforced.
  triggers_replace = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    # --- Final K3s Installation Logic ---
    # Rationale: AppArmor is disabled at the OS level by the deploy.sh script.
    # PodSecurity admission controller is disabled to allow Traefik port binding.
    inline = [
      "echo '==> [K3S-INSTALL] Step 1: Downloading K3s installer script...'",
      "curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh",
      "chmod +x /tmp/k3s-install.sh",
      "echo '==> [K3S-INSTALL] Step 2: Executing K3s installer with external etcd and correct arguments...'",
      format(
        # Using the latest K3s version as requested
        "INSTALL_K3S_VERSION='%s' K3S_TOKEN='%s' INSTALL_K3S_EXEC='%s' /tmp/k3s-install.sh",
        var.k3s_version,
        var.k3s_cluster_token,
        join(" ", [
          "server",
          "--kube-apiserver-arg=disable-admission-plugins=PodSecurity",
          "--disable=traefik",
          "--disable=servicelb",
          "--flannel-iface=eth0",
          "--datastore-endpoint=http://127.0.0.1:2379",
          "--tls-san=${local.api_server_fqdn}", # Using local variable for consistency
          "--tls-san=${var.vps_ip}",
          "--docker=false"
        ])
      ),
      "echo '==> [K3S-SETUP] Waiting for kubeconfig to be created...'",
      "timeout 120s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do echo -n .; sleep 2; done'",
      "echo ''", # Newline for cleaner logs
      "echo '==> [K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}