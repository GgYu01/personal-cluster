# bootstrap/c2-vps-setup.tf

resource "local_file" "etcd_docker_compose" {
  content  = <<-EOT
  version: '3.8'
  services:
    etcd:
      image: bitnami/etcd:3.6.4
      container_name: core-etcd
      # REFACTOR: Explicitly disable restart to prevent log spam on failure and ensure fail-fast behavior.
      restart: "no"
      ports:
        - "127.0.0.1:2379:2379"
      volumes:
        - /opt/etcd/data:/bitnami/etcd/data
      environment:
        - ALLOW_NONE_AUTHENTICATION=yes
        - ETCD_ADVERTISE_CLIENT_URLS=http://127.0.0.1:2379
  EOT
  filename = "${path.module}/docker-compose.etcd.yml"
}

resource "terraform_data" "vps_setup" {
  triggers_replace = {
    compose_file_sha1 = sha1(local_file.etcd_docker_compose.content)
    rerun_on_apply    = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-ETCD-CLEANUP] Ensuring /opt/etcd directory exists...'",
      "mkdir -p /opt/etcd",
      # REFACTOR: Use project name for precise cleanup, ensuring no impact on other docker-compose services.
      "echo '==> [TF-ETCD-CLEANUP] Stopping and removing project-specific etcd container...'",
      "if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose --project-name personal-cluster-etcd down --remove-orphans -v); fi || true",
      "echo '==> [TF-ETCD-CLEANUP] Purging old etcd data...'",
      "rm -rf /opt/etcd/data"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-ETCD-SETUP] Creating data directory...'",
      "mkdir -p /opt/etcd/data",
      # Bitnami etcd container runs as user 1001. This is crucial for non-root containers.
      "echo '==> [TF-ETCD-SETUP] Setting ownership for Bitnami non-root user (1001)...'",
      "chown -R 1001:1001 /opt/etcd/data"
    ]
  }

  provisioner "file" {
    source      = local_file.etcd_docker_compose.filename
    destination = "/opt/etcd/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      # REFACTOR: Use project name for isolated deployment.
      "echo '==> [TF-ETCD-DEPLOY] Starting isolated etcd service via docker-compose...'",
      "cd /opt/etcd && docker-compose --project-name personal-cluster-etcd up -d"
    ]
  }
}
