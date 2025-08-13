# 01-infra/c3-k3s-cluster.tf

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
      "echo '==> [K3S-INSTALL] Installing K3s with required arguments...'",
      join(" \\\n  ", [
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server",

        "--kube-apiserver-arg=disable-admission-plugins=PodSecurity",

        "--disable=traefik",
        "--disable=servicelb",

        "--flannel-iface=eth0",
        "--datastore-endpoint=http://127.0.0.1:2379",

        "--tls-san=${local.api_server_fqdn}",
        "--tls-san=${var.vps_ip}",
        "--token='${var.k3s_cluster_token}'",

        "--docker=false"
      ]),

      "echo '==> [K3S-VERIFY] Waiting for k3s.yaml to be created...'",
      "timeout 120s bash -c 'until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done'",
      "echo '==> [K3S-SETUP] Setting kubeconfig permissions...'",
      "chmod 644 /etc/rancher/k3s/k3s.yaml"
    ]
  }
}
