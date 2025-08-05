# bootstrap/c3-k3s-cluster.tf
resource "null_resource" "k3s_install" {
  # 依赖于etcd启动完成
  depends_on = [null_resource.vps_setup]

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(var.ssh_private_key_path)
  }

  # 安装K3s Server
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --datastore-endpoint=http://127.0.0.1:2379 --disable=traefik --tls-san=${var.vps_ip}' sh -",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml" # 确保可读
    ]
  }

  # 获取kubeconfig并保存到本地
  provisioner "local-exec" {
    command = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${var.vps_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${var.vps_ip}/' > ${path.module}/k3s.yaml"
  }
}