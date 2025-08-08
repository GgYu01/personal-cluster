# bootstrap/c3-k3s-cluster.tf

# --- K3s Installation and Configuration ---
resource "terraform_data" "k3s_install" {
  depends_on = [terraform_data.vps_setup]

  triggers_replace = {
    # We only re-trigger on k3s version change.
    k3s_version = var.k3s_version
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> [K3S-INSTALL] Installing K3s via command-line arguments ONLY...'",
      # THE ONLY SOURCE OF TRUTH for K3s configuration
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server --disable traefik --disable servicelb --tls-san ${local.api_server_fqdn} --tls-san ${var.vps_ip}",

      "echo '==> [K3S-VERIFY] Waiting for k3s.yaml to be created...'",
      "timeout 60s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done'",

      "echo '==> [K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}
