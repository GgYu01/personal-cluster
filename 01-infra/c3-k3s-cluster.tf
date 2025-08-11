# 01-infra/c3-k3s-cluster.tf (The Corrected and Final Version)

resource "terraform_data" "k3s_install" {
  depends_on = [terraform_data.vps_setup]

  triggers_replace = {
    k3s_version    = var.k3s_version
    cluster_token  = var.k3s_cluster_token
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
      "echo '==> [MINIMAL-PREP] Enabling kernel IP forwarding...'",
      "sysctl -w net.ipv4.ip_forward=1 || true",
      "sysctl -w net.ipv6.conf.all.forwarding=1 || true",

      "echo '==> [MINIMAL-PREP] Creating isolated resolv.conf for K3s...'",
      "mkdir -p /etc/rancher/k3s",
      "echo 'nameserver 8.8.8.8' | tee /etc/rancher/k3s/resolv.conf",

      "echo '==> [K3S-INSTALL] Installing K3s with conflicting addons DISABLED...'",
      join(" \\\n  ", [
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server",

        # Explicitly define the network interface for Flannel.
        "--flannel-iface=eth0",

        # DEFINITIVE FIX: Disable BOTH conflicting default addons.
        "--disable traefik",
        "--disable servicelb", # THIS IS THE CRITICAL FIX.

        # Isolate K3s from the host's Docker daemon.
        "--docker=false",

        # Standard cluster configuration.
        "--tls-san ${local.api_server_fqdn}",
        "--tls-san ${var.vps_ip}",
        "--datastore-endpoint=http://127.0.0.1:2379",
        "--resolv-conf=/etc/rancher/k3s/resolv.conf",
        "--cluster-dns=10.43.0.10",
        "--token='${var.k3s_cluster_token}'"
      ]),

      "echo '==> [K3S-VERIFY] Waiting for k3s.yaml to be created...'",
      "timeout 120s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done'",
      "echo '==> [K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}
