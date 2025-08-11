#!/bin/bash

# ==============================================================================
#      The Final Orchestrator (v9.0 - The Last Stand)
# ==============================================================================
#
# v9.0 Philosophy:
# - THE REAL ROOT CAUSE: The K3s installation is now fixed to disable BOTH
#   conflicting default addons: `traefik` AND `servicelb`. The `servicelb`
#   component was the hidden culprit preventing our own Traefik from binding
#   to host ports.
# - ULTIMATE DEBUGGING: The debug dump now includes detailed `describe` and
#   `logs` output for the Traefik pod, which will reveal the exact reason
#   for any future failure.
#
# ==============================================================================

# --- Strict Mode & Initial Setup ---
set -e
set -o pipefail
LOG_FILE="deployment_v9.0_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${LOG_FILE}")
echo "### DEPLOYMENT ORCHESTRATOR (v9.0) INITIATED AT $(date) ###"

# --- Configuration ---
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_k3s_version="v1.33.3+k3s1"
export TF_VAR_k3s_cluster_token="admin"

ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="7.3.6"
ADMIN_USERNAME="admin"

# --- Calculated Variables ---
WILDCARD_NAME="*.${TF_VAR_site_code}.${TF_VAR_environment}"
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

dump_debug_info() {
    echo -e "\n\033[1;31m--- START OF ULTIMATE DEBUG INFORMATION ---\033[0m"
    
    echo -e "\n\033[1;33m[DEBUG] All ArgoCD Applications:\033[0m"
    kubectl get applications -A -o wide || echo "[DEBUG] Could not list applications."

    echo -e "\n\033[1;33m[DEBUG] Traefik Pod Description:\033[0m"
    kubectl describe pod -n traefik -l app.kubernetes.io/name=traefik || echo "[DEBUG] Could not describe Traefik pod."

    echo -e "\n\033[1;33m[DEBUG] Traefik Pod Logs:\033[0m"
    kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100 || echo "[DEBUG] Could not get Traefik pod logs."

    echo -e "\n\033[1;33m[DEBUG] All Pods in All Namespaces:\033[0m"
    kubectl get pods -A -o wide || echo "[DEBUG] Could not list pods."

    echo -e "\n\033[1;33m[DEBUG] All Events in 'traefik' namespace (last 10):\033[0m"
    kubectl get events -n traefik --sort-by='.lastTimestamp' | tail -n 10 || echo "[DEBUG] Could not get events from traefik namespace."
    
    echo -e "\n\033[1;31m--- END OF ULTIMATE DEBUG INFORMATION ---\033[0m"
}

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
            dump_debug_info
            exit 1
        fi
        echo -n "."
        sleep 10
    done
    echo -e "\n--> \033[0;32mSUCCESS:\033[0m '${description}' is ready."
}

# --- Deployment Steps ---
function main() {
    log_step "1" "Verifying Manual DNS Prerequisite"
    local FQDN_TO_TEST="check-$(date +%s).${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
    local RESOLVED_IP=$(dig @1.1.1.1 "${FQDN_TO_TEST}" +short +time=5)
    if [[ "${RESOLVED_IP}" != "${TF_VAR_vps_ip}" ]]; then
        echo "FATAL: DNS Prerequisite Not Met!" && exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."

    log_step "2" "Preparing Environment"
    rm -rf 01-infra/.terraform* 01-infra/terraform.tfstate* ~/.kube/config
    ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" 'if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi; if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down -v); fi; rm -rf /etc/rancher /var/lib/rancher /opt/etcd'

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
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=30s" "CoreDNS pods" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=30s" "metrics-server" 300
    echo "--> SUCCESS: Core cluster is healthy."
    
    log_step "5" "Bootstrapping GitOps with ArgoCD"
    kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f - || true
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true; helm repo update > /dev/null
    helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" -n "${ARGOCD_NS}" --set server.service.type=ClusterIP --wait --timeout 15m
    kubectl apply -f kubernetes/bootstrap/root.yaml

    log_step "6" "Final End-to-End Verification"
    echo "--> [6.1] Verifying Cert-Manager installation..."
    wait_for_command "kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s" "Cert-Manager deployment to be Available" 300
    echo "--> [6.2] Verifying Traefik installation..."
    wait_for_command "kubectl wait --for=condition=Available deployment/traefik -n traefik --timeout=300s" "Traefik deployment to be Available" 300
    echo "--> [6.3] Verifying Traefik is listening on host ports..."
    wait_for_command "${SSH_CMD} '${TF_VAR_ssh_user}@${TF_VAR_vps_ip}' \"ss -tlpn | grep -E ':(80|443)' | grep 'traefik'\"" "Traefik to be listening on host ports 80/443" 180
    echo "--> [6.4] Verifying Let's Encrypt Certificate and HTTPS access for ArgoCD..."
    wait_for_command "kubectl get secret argocd-server-tls-staging -n argocd" "Let's Encrypt Certificate for ArgoCD" 600
    wait_for_command "curl -s --fail -v https://${ARGOCD_FQDN} 2>&1 | grep -q 'issuer: C=US; O=(STAGING) Let'" "HTTPS access to ${ARGOCD_FQDN}" 180

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#               ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                       #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and GitOps is running."
    echo -e "\n\033[1;33mACTION REQUIRED: Get your initial admin password\033[0m"
    echo -e "Run: \033[1;36mkubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo\033[0m"
    echo -e "\nAccess UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (Username: ${ADMIN_USERNAME})"
}

main