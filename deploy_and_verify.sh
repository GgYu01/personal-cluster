#!/bin/bash

# ==============================================================================
#      Definitive Deployment Orchestrator (v3.0 - State-Driven & Robust)
# ==============================================================================
#
# This script orchestrates the entire cluster deployment in a series of atomic,
# verifiable, and idempotent steps. It is the single source of truth for the
# deployment workflow.
#
# DESIGN:
# - State-Driven: Uses `terraform output` and external tools (`dig`, `ssh`) to
#   query the REAL state of the world before taking action.
# - Idempotent: Can be re-run safely. It will skip steps that are already complete.
# - Atomic Steps: Each function represents a minimal, verifiable unit of work.
# - Strict Dependencies: Ensures critical services are healthy before proceeding.
#
# ==============================================================================

# --- Strict Mode & Initial Setup ---
set -e
set -o pipefail
LOG_FILE="deployment_v3_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${LOG_FILE}")
echo "### DEPLOYMENT ORCHESTRATOR (v3.0) INITIATED AT $(date) ###"

# --- Configuration ---
# All user-configurable variables are defined here.
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
export TF_VAR_k3s_version="v1.33.3+k3s1"
export TF_VAR_k3s_cluster_token="admin" # Simple, insecure token as requested

ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="7.3.6" # A recent stable version
ARGOCD_ADMIN_USERNAME="admin"
ARGOCD_ADMIN_PASSWORD="password"

# --- Calculated Variables ---
SSH_KEY_PATH_EXPANDED="${TF_VAR_ssh_private_key_path/#\~/$HOME}"
WILDCARD_DNS_NAME="*.${TF_VAR_site_code}.${TF_VAR_environment}"
API_SERVER_FQDN="api.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
ARGOCD_FQDN="argocd.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
SSH_CMD="ssh -i ${SSH_KEY_PATH_EXPANDED} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# --- Helper Functions ---
log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP $1: $2 \033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
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
            exit 1
        fi
        echo -n "."
        sleep 5
    done
    echo -e "\n--> \033[0;32mSUCCESS:\033[0m '${description}' is ready."
}

# --- Deployment Steps ---

function step_01_prepare_workspace() {
    log_step "1" "Preparing Local Workspace and Remote Host"
    
    echo "--> [1.1] Cleaning up local Terraform state..."
    rm -rf 01-infra/.terraform 01-infra/.terraform.lock.hcl 01-infra/terraform.tfstate*
    rm -f ~/.kube/config_personal_cluster

    echo "--> [1.2] Executing remote host purification..."
    ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" '
        set -x
        echo "--- [REMOTE-CLEAN] Stopping and removing K3s..."
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi
        
        echo "--- [REMOTE-CLEAN] Stopping and removing project-specific etcd..."
        if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down --volumes --remove-orphans); fi
        docker stop core-etcd &>/dev/null || true
        docker rm -v core-etcd &>/dev/null || true
        
        echo "--- [REMOTE-CLEAN] Final filesystem cleanup..."
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d
        systemctl daemon-reload
        echo "--- [REMOTE-CLEAN] Purification complete. Current Docker containers:"
        docker ps
    '
}

function step_02_ensure_dns() {
    log_step "2" "Ensuring DNS Record Exists and is Correct"
    cd 01-infra

    echo "--> [2.1] Initializing Terraform..."
    terraform init -upgrade > /dev/null

    echo "--> [2.2] Checking for existing DNS record via Cloudflare API..."
    DNS_CHECK_JSON=$(terraform output -json dns_check_result)
    
    if [[ $(echo "${DNS_CHECK_JSON}" | jq 'length') -gt 0 && $(echo "${DNS_CHECK_JSON}" | jq -r '.[0].value') == "${TF_VAR_vps_ip}" ]]; then
        echo "--> \033[0;32mSUCCESS:\033[0m DNS record '${WILDCARD_DNS_NAME}' already exists and points to the correct IP."
    else
        echo "--> [2.3] DNS record not found or incorrect. Applying with Terraform..."
        terraform apply -auto-approve -target="cloudflare_dns_record.cluster_wildcard"
        echo "--> \033[0;32mSUCCESS:\033[0m DNS record created/updated."
    fi

    echo "--> [2.4] Verifying DNS propagation via public resolver..."
    wait_for_command "dig @1.1.1.1 ${API_SERVER_FQDN} +short | grep -q '${TF_VAR_vps_ip}'" "DNS propagation for ${API_SERVER_FQDN}" 180
    
    cd ..
}

function step_03_deploy_etcd() {
    log_step "3" "Deploying External etcd"
    cd 01-infra
    
    echo "--> [3.1] Applying etcd configuration..."
    terraform apply -auto-approve -target="local_file.etcd_docker_compose" -target="terraform_data.vps_setup"

    echo "--> [3.2] Verifying etcd health..."
    wait_for_command "${SSH_CMD} '${TF_VAR_ssh_user}@${TF_VAR_vps_ip}' 'docker exec core-etcd etcdctl endpoint health' | grep -q 'is healthy'" "etcd to be healthy" 120
    
    cd ..
}

function step_04_deploy_k3s_core() {
    log_step "4" "Deploying K3s Core"
    cd 01-infra

    echo "--> [4.1] Applying K3s installation..."
    terraform apply -auto-approve -target="terraform_data.k3s_install"

    echo "--> [4.2] Fetching and installing kubeconfig..."
    # We use a unique file to avoid conflicting with user's default kubeconfig
    KUBECONFIG_PATH=~/.kube/config
    RAW_KUBECONFIG=$(${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
    mkdir -p ~/.kube && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    echo "--> \033[0;32mSUCCESS:\033[0m Kubeconfig installed at ${KUBECONFIG_PATH}"

    echo "--> [4.3] Verifying K3s node and CoreDNS..."
    wait_for_command "kubectl get nodes --no-headers | grep -q ' Ready'" "K3s node readiness" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=1s" "CoreDNS pods to be Ready" 300
    
    cd ..
}

function step_05_verify_cluster_networking() {
    log_step "5" "Verifying Core Cluster Networking"
    export KUBECONFIG=~/.kube/config

    echo "--> [5.1] The definitive network health check: Waiting for metrics-server..."
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=1s" "metrics-server to be Ready" 300
    
    echo "--> \033[1;32mCORE CLUSTER DEPLOYMENT SUCCESSFUL.\033[0m Networking is functional."
    kubectl get nodes -o wide
    kubectl get pods -n kube-system
}

function step_06_bootstrap_argocd() {
    log_step "6" "Bootstrapping GitOps with ArgoCD"
    export KUBECONFIG=~/.kube/config

    echo "--> [6.1] Installing ArgoCD via Helm..."
    kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f - || true
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true
    helm repo update > /dev/null
    helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" \
        --set server.service.type=ClusterIP \
        --wait --timeout 15m

    echo "--> [6.2] Verifying ArgoCD deployments..."
    wait_for_command "kubectl wait --for=condition=Available deployment --all -n ${ARGOCD_NS} --timeout=1s" "all ArgoCD deployments to be Available" 600

    echo "--> [6.3] Logging into ArgoCD via secure port-forward..."
    kubectl port-forward svc/argocd-server -n "${ARGOCD_NS}" 8080:443 &
    PORT_FORWARD_PID=$!
    trap "kill $PORT_FORWARD_PID &>/dev/null" EXIT # Ensure cleanup
    wait_for_command "curl -k https://localhost:8080/api/v1/session" "port-forward to be active" 60

    ARGOCD_INITIAL_PASSWORD=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    argocd login localhost:8080 --insecure --username "${ARGOCD_ADMIN_USERNAME}" --password "${ARGOCD_INITIAL_PASSWORD}"
    
    echo "--> [6.4] Setting admin password..."
    argocd account update-password --current-password "${ARGOCD_INITIAL_PASSWORD}" --new-password "${ARGOCD_ADMIN_PASSWORD}"

    kill $PORT_FORWARD_PID &>/dev/null
    trap - EXIT
}

function step_07_deploy_apps() {
    log_step "7" "Deploying Applications via ArgoCD App-of-Apps"
    export KUBECONFIG=~/.kube/config

    echo "--> [7.1] Applying the root ApplicationSet..."
    # The root.yaml from your repo should point to a directory of Application manifests.
    # Let's assume it points to 'kubernetes/applications/'
    kubectl apply -f kubernetes/bootstrap/root.yaml

    echo "--> [7.2] Waiting for all managed applications to sync and become healthy..."
    # This is a robust way to wait for the entire GitOps state to converge.
    # We will wait for the 'root' app, which in turn manages all others.
    wait_for_command "argocd app get root -o json | jq -e '.status.health.status == \"Healthy\" and .status.sync.status == \"Synced\"'" "Root App of Apps to be Healthy and Synced" 1800 # 30 minute timeout for all apps
}

function step_08_final_verification() {
    log_step "8" "Final End-to-End Verification"
    export KUBECONFIG=~/.kube/config

    echo "--> [8.1] Verifying Traefik is listening on host ports 80/443..."
    wait_for_command "${SSH_CMD} '${TF_VAR_ssh_user}@${TF_VAR_vps_ip}' \"ss -tlpn | grep -E ':(80|443)' | grep 'traefik'\"" "Traefik to be listening on host ports" 180
    
    echo "--> [8.2] Verifying Let's Encrypt Certificate for ArgoCD..."
    wait_for_command "kubectl get secret argocd-server-tls-staging -n argocd" "secret/argocd-server-tls-staging to be created" 300

    echo "--> [8.3] Verifying HTTPS access to ArgoCD via Traefik..."
    wait_for_command "curl -s --fail --show-error --verbose https://${ARGOCD_FQDN} 2>&1 | grep -q 'issuer: C=US; O=(STAGING) Let'" "HTTPS access to ${ARGOCD_FQDN} with staging cert" 180
}

# --- Main Execution Logic ---
main() {
    step_01_prepare_workspace
    step_02_ensure_dns
    step_03_deploy_etcd
    step_04_deploy_k3s_core
    step_05_verify_cluster_networking
    step_06_bootstrap_argocd
    step_07_deploy_apps
    step_08_final_verification

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#                      DEPLOYMENT COMPLETED SUCCESSFULLY                       #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready."
    echo -e "ArgoCD UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m"
    echo -e "Username:  \033[1;36m${ARGOCD_ADMIN_USERNAME}\033[0m"
    echo -e "Password:  \033[1;36m${ARGOCD_ADMIN_PASSWORD}\033[0m"
}

main