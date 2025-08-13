#!/bin/bash

# ==============================================================================
#      Definitive Deployment Orchestrator (v10.0)
# ==============================================================================
#
# v10.0 Philosophy:
# - Clean Slate: Rigorously cleans the remote host and local state before every run.
# - Sequential & Verified: Each major step is executed and its success is verified
#   before proceeding to the next, preventing cascading failures.
# - Robust Checks: Uses a powerful `wait_for_command` function with timeouts
#   to handle real-world latencies in DNS, pod scheduling, and service availability.
# - Debuggability: On failure, automatically triggers a comprehensive diagnostic
#   script to capture the exact state of the failure.
#
# ==============================================================================

# --- Strict Mode & Initial Setup ---
set -e
set -o pipefail
DEPLOY_LOG_FILE="deployment_v10.0_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${DEPLOY_LOG_FILE}")
echo "### DEPLOYMENT ORCHESTRATOR (v10.0) INITIATED AT $(date) ###"

# --- Configuration ---
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_k3s_version="v1.33.3+k3s1"
export TF_VAR_k3s_cluster_token="admin"

ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="7.3.6"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="password" # As requested, for simplicity.

# --- Calculated Variables ---
API_SERVER_FQDN="api.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
ARGOCD_FQDN="argocd.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
SSH_KEY_PATH_EXPANDED="${TF_VAR_ssh_private_key_path/#\~/$HOME}"
SSH_CMD="ssh -i ${SSH_KEY_PATH_EXPANDED} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# --- Helper Functions ---
log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP $1: $2 \033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}

# This function will be called on any script error or exit
# It triggers the detailed diagnostic collection script
trigger_diagnostics() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n\033[1;31mDeployment script failed with exit code $exit_code. Running diagnostics...\033[0m\n"
        # Ensure the diagnostic script is executable and run it
        if [ -f ./collect_diagnostics.sh ]; then
            chmod +x ./collect_diagnostics.sh
            ./collect_diagnostics.sh
        else
            echo "collect_diagnostics.sh not found. Cannot run diagnostics."
        fi
    fi
}
trap trigger_diagnostics EXIT

wait_for_command() {
    local cmd_to_run=$1
    local description=$2
    local timeout_seconds=$3
    local start_time=$(date +%s)
    echo "--> WAITING for: ${description} (timeout: ${timeout_seconds}s)..."
    until eval "${cmd_to_run}" &> /dev/null; do
        if (( $(date +%s) - start_time > timeout_seconds )); then
            echo -e "\n\033[0;31mFATAL: Timed out waiting for '${description}'.\033[0m" >&2
            echo "--- Last command output for debugging ---"
            eval "${cmd_to_run}"
            echo "---------------------------------------"
            # The trap will handle the full diagnostic dump
            exit 1
        fi
        echo -n "."
        sleep 5
    done
    echo -e "\n--> \033[0;32mSUCCESS:\033[0m '${description}' is ready."
}

# --- Deployment Steps ---
main() {
    log_step "1" "Verifying Manual DNS Prerequisite"
    wait_for_command "dig @1.1.1.1 '*.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}' +short | grep -qxF '${TF_VAR_vps_ip}'" "Wildcard DNS record to be propagated" 300
    echo "--> SUCCESS: DNS prerequisite is met."

    log_step "2" "Preparing Environment (Enhanced Cleanup)"
    rm -rf 01-infra/.terraform* 01-infra/terraform.tfstate* ~/.kube/config
    ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" '
        set -x
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down -v --remove-orphans); fi
        # Force stop and remove any lingering etcd container
        docker ps -a -q --filter name=core-etcd | xargs -r docker stop
        docker ps -a -q --filter name=core-etcd | xargs -r docker rm -v
        # Comprehensive cleanup
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d
        # Clean K3s journal logs for this boot cycle to ensure clean diagnostics
        echo "Rotating journald logs for k3s service..."
        journalctl --rotate --unit=k3s
        journalctl --vacuum-time=1s --unit=k3s
        systemctl daemon-reload
    '
    echo "--> SUCCESS: Environment prepared."

    log_step "3" "Applying Core Infrastructure (etcd & K3s)"
    cd 01-infra
    terraform init -upgrade >/dev/null
    terraform apply -auto-approve
    cd ..

    log_step "4" "Verifying Cluster Health and Setting up Kubeconfig"
    KUBECONFIG_PATH=~/.kube/config
    RAW_KUBECONFIG=$(${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
    mkdir -p ~/.kube && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    wait_for_command "kubectl get nodes --no-headers | grep -q ' Ready'" "K3s node readiness" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=5s" "CoreDNS pods" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=5s" "metrics-server" 300
    echo "--> SUCCESS: Core cluster is healthy."
    
    log_step "5" "Bootstrapping GitOps with ArgoCD"
    kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f - || true
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true; helm repo update > /dev/null
    helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" -n "${ARGOCD_NS}" --set server.service.type=ClusterIP --wait --timeout 15m
    kubectl apply -f kubernetes/bootstrap/root.yaml

    log_step "6" "Final End-to-End Verification"
    echo "--> [6.1] Verifying Cert-Manager installation..."
    wait_for_command "kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=5s" "Cert-Manager deployment to be Available" 300
    
    echo "--> [6.2] Verifying Traefik installation..."
    wait_for_command "kubectl wait --for=condition=Available daemonset/traefik -n traefik --timeout=5s" "Traefik DaemonSet to be Available" 300

    echo "--> [6.3] Verifying Traefik is listening on host ports..."
    wait_for_command "${SSH_CMD} '${TF_VAR_ssh_user}@${TF_VAR_vps_ip}' \"ss -tlpn | grep -E ':(80|443)' | grep 'traefik'\"" "Traefik to listen on host ports 80/443" 180
    
    echo "--> [6.4] Verifying Let's Encrypt Certificate and HTTPS access for ArgoCD..."
    wait_for_command "kubectl get secret argocd-server-tls-staging -n argocd" "Let's Encrypt Certificate for ArgoCD" 600
    wait_for_command "curl -s --fail -v https://${ARGOCD_FQDN} 2>&1 | grep -q 'issuer: C=US; O=(STAGING) Let'" "HTTPS access to ${ARGOCD_FQDN}" 180

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#               ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                       #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and GitOps is running."
    ARGOCD_INITIAL_PASSWORD=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo -e "\n\033[1;33mArgoCD Login Details:\033[0m"
    echo -e "Access UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m"
    echo -e "Username:  \033[1;36m${ADMIN_USERNAME}\033[0m"
    echo -e "Initial Password: \033[1;36m${ARGOCD_INITIAL_PASSWORD}\033[0m"
    
    # Disable the exit trap since we succeeded
    trap - EXIT
}

# Execute main function
main