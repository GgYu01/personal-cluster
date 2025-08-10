# bootstrap/c3-k3s-cluster.tf

# --- K3s Pre-configuration: Create a clean resolv.conf ---
# This step is the definitive fix for persistent cluster DNS issues.
# It creates a pristine resolv.conf file on the host that K3s will use
# for all pods, completely bypassing any potentially broken host DNS configuration
# (like systemd-resolved).
resource "terraform_data" "k3s_pre_config" {
  # DEFINITIVE FIX: Force re-run to ensure resolv.conf is always created after cleanup.
  triggers_replace = {
    rerun_on_apply = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-K3S-PRE-CONFIG] Creating a clean, isolated resolv.conf for K3s...'",
      "mkdir -p /etc/rancher/k3s",
      "echo 'nameserver 8.8.8.8' | tee /etc/rancher/k3s/resolv.conf"
    ]
  }
}

# --- K3s Installation and Configuration ---
resource "terraform_data" "k3s_install" {
  # This now depends on the pre-configuration step.
  depends_on = [terraform_data.vps_setup, terraform_data.k3s_pre_config]

  triggers_replace = {
    k3s_version   = var.k3s_version
    cluster_token = var.k3s_cluster_token
   # DEFINITIVE FIX: Add a timestamp to force re-provisioning on every run.
   rerun_on_apply = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    # Using 'join' to correctly handle multi-line shell command in HCL
    inline = [
      "echo '==> [TF-K3S-INSTALL] Installing K3s with explicit DNS configuration...'",
      join(" \\\n  ", [
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server",
        "--disable traefik",
        "--tls-san ${local.api_server_fqdn}",
        "--tls-san ${var.vps_ip}",
        "--datastore-endpoint=http://127.0.0.1:2379",
        "--resolv-conf=/etc/rancher/k3s/resolv.conf",
        "--cluster-dns=10.43.0.10",
        "--token='${var.k3s_cluster_token}'"
      ]),
      "echo '==> [TF-K3S-VERIFY] Waiting for k3s.yaml to be created...'",
      "timeout 60s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done'",
      "echo '==> [TF-K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}
