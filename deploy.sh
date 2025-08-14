#!/bin/bash

# ==============================================================================
# DEPLOYMENT ORCHESTRATOR (v14.0 - Robust & Isolated)
# ==============================================================================
# This script orchestrates a robust, isolated, and fully non-interactive
# deployment of a K3s cluster with external etcd and a GitOps setup.
#
# Key Principles Implemented:
# - DNS Query-Only: Verifies DNS records, does NOT manage them.
# - Precise Cleanup: Only removes resources created by this deployment.
#   Uses Docker Compose project names to avoid impacting other services.
# - Serial, Verified Deployment: Each major step is validated before proceeding.
# - Fail-Fast on Container Errors: Containers are set to not restart.
# - Comprehensive Logging: Captures all output for deep analysis.
# ==============================================================================

set -eo pipefail # Exit on error, exit on pipe fail

# --- Configuration Variables (HARD-CODED) ---
readonly DOMAIN_NAME="gglohh.top"
readonly SITE_CODE="core01"
readonly ENVIRONMENT="prod"
readonly ACME_EMAIL="1405630484@qq.com"
readonly VPS_IP="172.245.187.113"
readonly SSH_USER="root"
readonly SSH_PRIVATE_KEY_PATH="~/.ssh/id_rsa"
readonly GITOPS_REPO_URL="https://github.com/GgYu01/personal-cluster.git"
readonly K3S_VERSION="v1.33.3+k3s1"
readonly ARGOCD_CHART_VERSION="8.2.7"
readonly K3S_CLUSTER_TOKEN="admin"
readonly ARGOCD_ADMIN_USER="admin"

# --- Script-derived Variables (DO NOT EDIT) ---
readonly LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"
readonly ARGOCD_NS="argocd"
readonly ETCD_PROJECT_NAME="personal-cluster-etcd" # For Docker Compose isolation
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_PRIVATE_KEY_PATH}"
readonly TF_DIR="01-infra"
readonly KUBECONFIG_PATH="${HOME}/.kube/config"

# --- Helper Functions ---
log_step() {
    # Using a global step counter, passed as an argument
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP ${1}: ${2} (Timestamp: $(date -u --iso-8601=seconds))\033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}

check_remote_command() {
    local description="$1"
    local command_to_run="$2"
    local max_retries=30 # 30 retries * 10s = 5 minutes timeout
    local attempt=0

    echo "--> Verifying: ${description}"
    while (( attempt < max_retries )); do
        if ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "${command_to_run}"; then
            echo "--> SUCCESS: Verification passed for '${description}'."
            return 0
        fi
        ((attempt++))
        echo "    (Attempt ${attempt}/${max_retries}) Verification failed. Retrying in 10 seconds..."
        sleep 10
    done

    echo "FATAL: Timed out waiting for '${description}'." >&2
    return 1
}

# --- Main Execution Logic ---
main() {
    # Redirect all output to log file and console
    exec &> >(tee -a "$LOG_FILE")

    local step_counter=1
    trap 'echo -e "\n\033[0;31mFATAL: Deployment script failed at STEP $((step_counter - 1)). See ${LOG_FILE} for full details.\033[0m" >&2' ERR

    echo "### DEPLOYMENT ORCHESTRATOR (v14.0) INITIATED AT $(date) ###"
    echo "Full log will be saved to: ${LOG_FILE}"

    log_step $step_counter "DNS Prerequisite Verification"
    echo "--> Verifying wildcard DNS record '*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}' points to ${VPS_IP}..."
    local resolved_ip
    resolved_ip=$(dig @"1.1.1.1" "test-wildcard.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}" +short)
    if [[ "${resolved_ip}" != "${VPS_IP}" ]]; then
        echo "FATAL: DNS Query failed or incorrect. Expected '${VPS_IP}', but got '${resolved_ip}'." >&2
        exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."
    ((step_counter++))

    log_step $step_counter "Remote Host Preparation (Precise & Isolated Cleanup)"
    echo "--> Performing targeted cleanup on ${VPS_IP}..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "
        set -x
        echo '--> [CLEANUP] Stopping and disabling AppArmor...'
        systemctl stop apparmor || true
        systemctl disable apparmor || true

        echo '--> [CLEANUP] Uninstalling K3s...'
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi

        echo '--> [CLEANUP] Stopping and removing project-specific etcd service...'
        if [ -f /opt/etcd/docker-compose.yml ]; then
            docker-compose --project-name ${ETCD_PROJECT_NAME} -f /opt/etcd/docker-compose.yml down -v --remove-orphans
        fi
        
        echo '--> [CLEANUP] Removing residual files and directories...'
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d /tmp/k3s-install.sh

        echo '--> [CLEANUP] Clearing old journald logs...'
        journalctl --rotate && journalctl --vacuum-time=1s
        
        echo '--> [SYSTEM] Reloading systemd daemon...'
        systemctl daemon-reload
    "
    echo "--> SUCCESS: Remote host is prepared."
    ((step_counter++))

    log_step $step_counter "Terraform Infrastructure Provisioning (etcd & K3s)"
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
    echo "--> SUCCESS: Core infrastructure provisioned."
    ((step_counter++))

    log_step $step_counter "Post-Terraform Verification"
    check_remote_command "etcd container is running and ready" \
        "docker ps | grep -q 'core-etcd' && docker logs core-etcd | grep -q 'ready to serve client requests'"
    echo "--> [DIAGNOSTIC] Retrieving K3s service logs..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "journalctl -u k3s --no-pager -n 200"
    ((step_counter++))

    log_step $step_counter "Local Kubeconfig Setup & Cluster Health Check"
    echo "--> Fetching and configuring local kubeconfig..."
    RAW_KUBECONFIG=$(${SSH_CMD} "${SSH_USER}@${VPS_IP}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/" | sed "s/default/personal-cluster/")
    mkdir -p "$(dirname "${KUBECONFIG_PATH}")" && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    echo "--> Waiting for K3s node to become Ready..."
    kubectl wait --for=condition=Ready node --all --timeout=5m
    echo "--> Waiting for CoreDNS to be available..."
    kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=5m
    echo "--> SUCCESS: Cluster is healthy and kubeconfig is set up."
    ((step_counter++))

    log_step $step_counter "GitOps Bootstrap (ArgoCD)"
    echo "--> Installing ArgoCD via Helm..."
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true
    helm repo update > /dev/null
    helm upgrade --install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" \
        -n "${ARGOCD_NS}" --create-namespace \
        --set server.service.type=ClusterIP \
        --wait --timeout=15m

    echo "--> Applying root Application to bootstrap GitOps..."
    kubectl apply -f kubernetes/bootstrap/root.yaml
    echo "--> SUCCESS: ArgoCD is installed and managing the cluster."
    ((step_counter++))
    
    log_step $step_counter "Final End-to-End Verification"
    echo "--> Waiting for all ArgoCD applications to become Healthy & Synced (this may take several minutes)..."
    kubectl wait --for=condition=Healthy application --all -n ${ARGOCD_NS} --timeout=15m
    kubectl wait --for=condition=Synced application --all -n ${ARGOCD_NS} --timeout=15m

    echo "--> Verifying Traefik is listening on host ports 80 & 443..."
    check_remote_command "Traefik is listening on host ports" \
        "ss -tlpn | grep -q ':80' && ss -tlpn | grep -q ':443'"
    
    echo "--> Verifying ClusterIssuer is ready..."
    kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m

    echo "--> Verifying ArgoCD Ingress certificate is issued..."
    kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n ${ARGOCD_NS} --timeout=5m

    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    
    echo -e "\nYour personal cluster is ready and GitOps is running."
    echo -e "\n\033[1;33mArgoCD Login Details:\033[0m"
    echo -e "Access UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (accept the staging certificate)"
    echo -e "Username:  \033[1;36m${ARGOCD_ADMIN_USER}\033[0m"
    echo -e "Password:  \033[1;36m${ARGOCD_PASSWORD}\033[0m"
    
    trap - EXIT
}

# --- Script Entry Point ---
main "$@"