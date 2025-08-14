# 01-infra/c3-k3s-cluster.tf
# REFACTORED: This file now uses a robust wrapper script for K3s installation.

# Step 1: Create a robust, POSIX-compliant installation wrapper script locally.
resource "local_file" "k3s_install_script" {
  content = <<-EOT
    #!/bin/bash
    # MODIFIED: Changed shebang to #!/bin/bash to ensure compatibility
    # with commands like 'set -o pipefail', which are not supported by
    # the default /bin/sh (dash) on Debian systems.

    set -ef # Exit on error, exit on unset variable.
    
    LOG_FILE="/tmp/k3s-install-output.log"
    
    # Function for logging with timestamp
    log() {
      echo "[$(date -u --iso-8601=seconds)] - $1" | tee -a $LOG_FILE
    }
    
    # Start fresh log
    echo "--- K3s Installation Log ---" > $LOG_FILE
    
    log "Downloading K3s installer..."
    INSTALLER_SCRIPT=$(curl -sfL https://get.k3s.io)
    
    if [ -z "$INSTALLER_SCRIPT" ]; then
      log "FATAL: Failed to download K3s installer script."
      exit 1
    fi
    
    log "K3s installer downloaded successfully."
    log "Executing K3s installer with the following environment variables and arguments:"
    log "INSTALL_K3S_VERSION='${var.k3s_version}'"
    log "K3S_TOKEN='*****'" # Do not log the actual token
    log "INSTALL_K3S_EXEC='${local.k3s_install_args_string}'"

    # Execute the installer.
    # The subshell with 'set -o pipefail' is now compatible with bash.
    (
      set -o pipefail
      echo "$INSTALLER_SCRIPT" | INSTALL_K3S_VERSION='${var.k3s_version}' K3S_TOKEN='${var.k3s_cluster_token}' INSTALL_K3S_EXEC='${local.k3s_install_args_string}' sh -ex 2>&1 | tee -a $LOG_FILE
    )
    
    INSTALL_STATUS=$?
    if [ $INSTALL_STATUS -ne 0 ]; then
      log "FATAL: K3s installation command failed with exit code $INSTALL_STATUS."
      exit $INSTALL_STATUS
    fi
    
    log "K3s installation command executed. Waiting for kubeconfig file..."
    
    ATTEMPTS=0
    MAX_ATTEMPTS=60
    while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
      if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
        log "FATAL: Timed out waiting for /etc/rancher/k3s/k3s.yaml to be created."
        exit 1
      fi
      log "Waiting for kubeconfig... (attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS)"
      sleep 2
      ATTEMPTS=$((ATTEMPTS+1))
    done
    
    log "Kubeconfig found. Setting permissions."
    chmod 644 /etc/rancher/k3s/k3s.yaml
    
    log "--- K3s Installation Script Finished Successfully ---"
    exit 0
  EOT
  filename        = "${path.module}/generated-k3s-install-wrapper.sh"
  file_permission = "0755"
}

# Step 2: Upload and execute the wrapper script.
resource "terraform_data" "k3s_install" {
  depends_on = [terraform_data.vps_setup]

  triggers_replace = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.vps_ip
    private_key = file(pathexpand(var.ssh_private_key_path))
  }

  provisioner "file" {
    source      = local_file.k3s_install_script.filename
    destination = "/tmp/k3s-install-wrapper.sh"
  }

  # The chmod command from the previous fix is retained as good practice.
  provisioner "remote-exec" {
    inline = [
      "echo '==> [TF-K3S-INSTALL] Ensuring script is executable...'",
      "chmod +x /tmp/k3s-install-wrapper.sh",
      "echo '==> [TF-K3S-INSTALL] Executing the uploaded K3s installation wrapper script...'",
      "/tmp/k3s-install-wrapper.sh"
    ]
  }
}