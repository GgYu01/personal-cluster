# 01-infra/c3-k3s-cluster.tf

resource "terraform_data" "k3s_install" {
  depends_on = [terraform_data.vps_setup]

  # Trigger re-provisioning on every apply to ensure a consistent state
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
      "echo '==> [K3S-INSTALL] Installing K3s with required arguments...'",
      # The installer command is broken into multiple lines for readability
      join(" \\\n  ", [
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server",

        # --- ROOT CAUSE FIX 1: DISABLE POD SECURITY ADMISSION ---
        # LOGIC: Newer Kubernetes versions (and K3s) enable the 'PodSecurity' admission plugin by default.
        # This plugin enforces Pod Security Standards which, by default, FORBID pods from using host ports (<1024),
        # causing the 'permission denied' error for Traefik, even with NET_BIND_SERVICE capability.
        # Disabling this specific plugin is the definitive way to allow Traefik to bind to ports 80 and 443.
        "--kube-apiserver-arg=disable-admission-plugins=PodSecurity",

        # --- ROOT CAUSE FIX 2: DISABLE CONFLICTING K3S ADDONS ---
        # LOGIC: We must disable BOTH the default 'traefik' ingress and the 'servicelb' LoadBalancer.
        # 'servicelb' can claim host ports for LoadBalancer services, creating a conflict with our own Traefik DaemonSet.
        "--disable", "traefik",
        "--disable", "servicelb",

        # --- Standard and Networking Configuration ---
        "--flannel-iface=eth0",
        "--docker=false", # Isolate from host Docker
        "--tls-san ${local.api_server_fqdn}",
        "--tls-san ${var.vps_ip}",
        "--datastore-endpoint=http://127.0.0.1:2379",
        "--token='${var.k3s_cluster_token}'"
      ]),

      "echo '==> [K3S-VERIFY] Waiting for k3s.yaml to be created...'",
      "timeout 120s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done'",
      "echo '==> [K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}
