# bootstrap/c2-vps-setup.tf
resource "local_file" "etcd_docker_compose" {
  content  = <<-EOT
  version: '3.8'
  services:
    etcd:
      image: bitnami/etcd:3.6.4
      container_name: core-etcd
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

# Use terraform_data as the modern replacement for null_resource.
resource "terraform_data" "vps_setup" {
  # Trigger re-provisioning if the compose file content changes.
  triggers_replace = {
    compose_file_sha1 = sha1(local_file.etcd_docker_compose.content)
   # DEFINITIVE FIX: Add a timestamp to force re-provisioning on every run.
   # This ensures that if the remote state was cleaned up by the script,
   # Terraform will always re-apply the setup steps.
   rerun_on_apply = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  # Provisioner Step 1: Clean up previous installation for idempotency.
  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-ETCD-CLEANUP] Ensuring /opt/etcd directory exists...'",
      "mkdir -p /opt/etcd",
      "echo '==> [TF-ETCD-CLEANUP] Stopping and removing any existing etcd container...'",
      "if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down --remove-orphans); fi || true",
      "echo '==> [TF-ETCD-CLEANUP] Purging old etcd data...'",
      "rm -rf /opt/etcd/data"
    ]
  }

  # Provisioner Step 2: Create directory and set permissions.
  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-ETCD-SETUP] Creating data directory...'",
      "mkdir -p /opt/etcd/data",
      "echo '==> [TF-ETCD-SETUP] Setting ownership for Bitnami non-root user (1001)...'",
      "chown -R 1001:1001 /opt/etcd/data"
    ]
  }

  # Provisioner Step 3: Upload compose file and start the service.
  provisioner "file" {
    source      = local_file.etcd_docker_compose.filename
    destination = "/opt/etcd/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-ETCD-DEPLOY] Starting etcd service via docker-compose...'",
      "cd /opt/etcd && docker-compose up -d"
    ]
  }
}
