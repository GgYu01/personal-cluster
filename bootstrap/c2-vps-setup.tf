# bootstrap/c2-vps-setup.tf
resource "local_file" "etcd_docker_compose" {
  content = <<-EOT
  version: '3.8'
  services:
    etcd:
      image: bitnami/etcd:3.5
      container_name: core-etcd
      restart: always
      ports:
        - "127.0.0.1:2379:2379"
      volumes:
        - /opt/etcd/data:/bitnami/etcd
      environment:
        - ALLOW_NONE_AUTHENTICATION=yes
        - ETCD_ADVERTISE_CLIENT_URLS=http://127.0.0.1:2379
  EOT
  filename = "${path.module}/docker-compose.etcd.yml"
}

# 使用 null_resource 和 provisioner 来执行远程命令
resource "null_resource" "vps_setup" {
  # 触发器，确保文件先生成
  triggers = {
    compose_file_sha1 = sha1(local_file.etcd_docker_compose.content)
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(var.ssh_private_key_path)
  }

  # 步骤1: 安装Docker
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "if ! command -v docker &> /dev/null; then curl -fsSL https://get.docker.com | sh; sudo systemctl enable --now docker; fi",
      "if ! command -v docker-compose &> /dev/null; then sudo curl -L https://github.com/docker/compose/releases/download/v2.17.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose; sudo chmod +x /usr/local/bin/docker-compose; fi",
      "sudo mkdir -p /opt/etcd/data",
    ]
  }

  # 步骤2: 上传Docker Compose文件
  provisioner "file" {
    source      = local_file.etcd_docker_compose.filename
    destination = "/opt/etcd/docker-compose.yml"
  }

  # 步骤3: 启动etcd服务
  provisioner "remote-exec" {
    inline = [
      "cd /opt/etcd && sudo docker-compose up -d"
    ]
  }
}