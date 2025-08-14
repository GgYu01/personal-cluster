#!/bin/bash

# ==============================================================================
# DIAGNOSTIC DEPLOYMENT SCRIPT (v1.0)
#
# PURPOSE: To execute the deployment process with maximum verbosity and state
#          capture for deep analysis. This script is NOT the final solution.
#
# FEATURES:
# - Full command tracing (set -x).
# - Comprehensive logging of stdout and stderr to a file.
# - Detailed state dumps at critical checkpoints.
# - Sequential execution with error checking (set -eo pipefail).
# ==============================================================================

# --- Configuration ---
# Ensure all variables are set correctly before running.
# These are identical to your original script for consistency.

# --- Domain & Naming ---
readonly DOMAIN_NAME="gglohh.top"
readonly SITE_CODE="core01"
readonly ENVIRONMENT="prod"
readonly ACME_EMAIL="1405630484@qq.com"

# --- Host & SSH ---
readonly VPS_IP="172.245.187.113"
readonly SSH_USER="root"
readonly SSH_PRIVATE_KEY_PATH="~/.ssh/id_rsa"

# --- GitOps ---
readonly GITOPS_REPO_URL="https://github.com/GgYu01/personal-cluster.git"

# --- Software Versions ---
readonly K3S_VERSION="v1.33.3+k3s1"
readonly ARGOCD_CHART_VERSION="8.2.7"

# --- Security ---
readonly K3S_CLUSTER_TOKEN="admin"
readonly ARGOCD_ADMIN_USER="admin"

# --- Script Internals ---
readonly LOG_FILE="deployment-diag-$(date +%Y%m%d-%H%M%S).log"
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_PRIVATE_KEY_PATH}"
readonly TF_DIR="01-infra"

# --- Global Script Setup ---
# Redirect all stdout/stderr to a log file and also to the console.
# The 'exec' command makes this apply to the entire script.
exec &> >(tee -a "$LOG_FILE")

set -exo pipefail # Exit on error, print commands, exit on pipe fail

# --- Helper Functions ---
log_step() {
    # Using a global step counter
    echo -e "\n\n# ============================================================================== #"
    echo -e "# STEP ${step_counter}: ${1} (Timestamp: $(date -u --iso-8601=seconds))"
    echo -e "# ============================================================================== #\n"
    ((step_counter++))
}

# --- Main Execution Logic ---
main() {
    local step_counter=1
    trap 'echo -e "\nFATAL: Diagnostic script failed at STEP $((step_counter - 1)). See ${LOG_FILE} for full details." >&2' ERR

    echo "### DIAGNOSTIC SCRIPT INITIATED ###"
    echo "Full log will be saved to: ${LOG_FILE}"

    log_step "DNS Prerequisite Verification"
    echo "--> Verifying wildcard DNS record '*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}' points to ${VPS_IP}..."
    local resolved_ip
    resolved_ip=$(dig @"1.1.1.1" "test-wildcard.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}" +short)
    if [[ "${resolved_ip}" != "${VPS_IP}" ]]; then
        echo "FATAL: DNS Query failed or incorrect. Expected '${VPS_IP}', but got '${resolved_ip}'." >&2
        exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."

    log_step "Remote Host Preparation (Precise Cleanup & System Prep)"
    echo "--> Performing targeted cleanup on ${VPS_IP}..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" '
        set -x # Enable command tracing within the SSH session

        echo "--> [CLEANUP] Stopping and disabling AppArmor (if active)..."
        if systemctl is-active --quiet apparmor; then systemctl stop apparmor; fi
        if systemctl is-enabled --quiet apparmor; then systemctl disable apparmor; fi
        echo "--> AppArmor status check:"
        systemctl status apparmor || true

        echo "--> [CLEANUP] Stopping and removing K3s service..."
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; else echo "k3s-uninstall.sh not found, skipping."; fi

        echo "--> [CLEANUP] Stopping and removing standalone etcd container..."
        if [ -f /opt/etcd/docker-compose.yml ]; then
            docker-compose -f /opt/etcd/docker-compose.yml down -v --remove-orphans
        else
            echo "No etcd compose file found, skipping."
        fi
        
        echo "--> [CLEANUP] Removing residual files and directories..."
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d /tmp/k3s-install.sh

        echo "--> [CLEANUP] Clearing old journald logs for k3s and etcd..."
        journalctl --rotate
        journalctl --vacuum-time=1s
        
        echo "--> [SYSTEM] Reloading systemd daemon to apply changes..."
        systemctl daemon-reload
        
        echo "--> [DIAGNOSTIC] Listing active docker containers and images before deployment..."
        docker ps -a
        docker images
    '
    echo "--> SUCCESS: Remote host is prepared."

    log_step "Terraform Infrastructure Provisioning (etcd & K3s)"
    echo "--> Applying infrastructure with Terraform..."
    (
        cd "${TF_DIR}" || exit 1
        terraform init -upgrade
        terraform apply -auto-approve \
            -var="vps_ip=${VPS_IP}" \
            -var="ssh_user=${SSH_USER}" \
            -var="ssh_private_key_path=${SSH_PRIVATE_KEY_PATH}" \
            -var="domain_name=${DOMAIN_NAME}" \
            -var="site_code=${SITE_CODE}" \
            -var="environment=${ENVIRONMENT}" \
            -var="k3s_version=${K3S_VERSION}" \
            -var="k3s_cluster_token=${K3S_CLUSTER_TOKEN}" \
            -var="gitops_repo_url=${GITOPS_REPO_URL}"
    )
    echo "--> SUCCESS: Terraform apply command completed."

    log_step "Post-Terraform Verification"
    echo "--> [DIAGNOSTIC] Retrieving full etcd container logs..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "docker logs --tail 500 core-etcd"
    echo "--> Verifying etcd is running on host with an increased timeout..."
    # Increased timeout to 180s to mitigate race conditions
    timeout 180s bash -c "until ${SSH_CMD} ${SSH_USER}@${VPS_IP} \"docker ps | grep -q 'core-etcd' && docker logs core-etcd | grep -q 'ready to serve client requests'\" ; do echo -n '.'; sleep 5; done"
    echo -e "\n--> SUCCESS: Standalone etcd is confirmed running via log inspection."
    echo "--> [DIAGNOSTIC] Retrieving K3s service logs immediately after installation..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "journalctl -u k3s --no-pager -n 500"

    log_step "Local Kubeconfig Setup & Cluster Health Check"
    KUBECONFIG_PATH="${HOME}/.kube/config"
    echo "--> Fetching and configuring local kubeconfig..."
    RAW_KUBECONFIG=$(${SSH_CMD} "${SSH_USER}@${VPS_IP}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/" | sed "s/default/personal-cluster/")
    mkdir -p "$(dirname "${KUBECONFIG_PATH}")" && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    echo "--> [DIAGNOSTIC] Displaying final kubeconfig:"
    cat "${KUBECONFIG_PATH}"
    
    echo "--> Waiting for K3s node to become Ready..."
    kubectl wait --for=condition=Ready node --all --timeout=300s
    echo "--> Waiting for CoreDNS to be available..."
    kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=300s

    echo "--> [DIAGNOSTIC] Dumping cluster state before ArgoCD installation:"
    kubectl get nodes -o wide
    kubectl get all --all-namespaces -o wide
    echo "--> SUCCESS: Cluster is healthy and kubeconfig is set up."

    log_step "GitOps Bootstrap (ArgoCD)"
    echo "--> Installing ArgoCD via Helm..."
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true
    helm repo update > /dev/null
    helm upgrade --install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" \
        -n "argocd" --create-namespace \
        --set server.service.type=ClusterIP \
        --wait --timeout=15m

    echo "--> [DIAGNOSTIC] Dumping ArgoCD state after helm install:"
    kubectl get all -n argocd -o wide

    echo "--> Applying root Application to bootstrap GitOps..."
    kubectl apply -f kubernetes/bootstrap/root.yaml
    
    echo "--> [DIAGNOSTIC] Waiting 60 seconds for ArgoCD to process applications..."
    sleep 60

    echo "--> [DIAGNOSTIC] Dumping state of all ArgoCD applications:"
    kubectl get applications -n argocd -o yaml
    
    echo "--> [DIAGNOSTIC] Describing root application for events and status:"
    kubectl describe application root -n argocd

    echo "--> SUCCESS: ArgoCD installation initiated."
    
    log_step "Final State Capture"
    echo "--> Waiting up to 10 minutes for full GitOps sync and capturing state periodically."
    for i in {1..20}; do
      echo -e "\n--- State Capture Iteration ${i} at $(date -u --iso-8601=seconds) ---"
      kubectl get pods,svc,ingressroute,clusterissuer,certificate --all-namespaces
      echo "--- ArgoCD Application Status ---"
      kubectl get applications -n argocd
      sleep 30
    done
    
    echo -e "\n\n### DIAGNOSTIC SCRIPT COMPLETED ###"
    echo "Please provide me with the generated log file: ${LOG_FILE}"
    echo "Also provide the requested documentation links."
    
    trap - EXIT
}

# --- Script Entry Point ---
main "$@"