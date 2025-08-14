#!/bin/bash

# ==============================================================================
# DEPLOYMENT ORCHESTRATOR (v16.0 - The True Finale)
# ==============================================================================
# This script orchestrates a robust, isolated, and fully non-interactive
# deployment of a K3s cluster with external etcd and a GitOps setup.
#
# v16.0 Changelog:
# - Added capture of PREVIOUS container logs to the failure_dump, allowing us
#   to see the final logs of crashing containers (like Traefik).
# - This version, combined with the fix in traefik.yaml, aims to be the
#   definitive solution.
#
# Key Principles Implemented:
# - Precise & Synchronized Cleanup.
# - Serial, Verified Deployment with NATIVE health checks.
# - Ultimate-level diagnostics on failure, including crash logs.
# ==============================================================================

set -eo pipefail

# --- Configuration Variables ---
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

# --- Script-derived Variables ---
readonly LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"
readonly ARGOCD_NS="argocd"
readonly ETCD_PROJECT_NAME="personal-cluster-etcd"
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${SSH_PRIVATE_KEY_PATH}"
readonly TF_DIR="01-infra"
readonly KUBECONFIG_PATH="${HOME}/.kube/config"

# --- Helper Functions ---
log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP ${1}: ${2} (Timestamp: $(date -u --iso-8601=seconds))\033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}

# UPGRADED: Now captures logs from previously crashed containers
failure_dump() {
    echo -e "\n\033[1;31m# ============================================================================== #\033[0m"
    echo -e "\033[1;31m#                      CAPTURING KUBERNETES FAILURE DUMP                       #\033[0m"
    echo -e "\033[1;31m# ============================================================================== #\033[0m\n"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    echo ">>> [DUMP] Checking kubectl connectivity..."
    kubectl version || echo "kubectl connection failed."

    echo "\n>>> [DUMP] Getting all resources in all namespaces..."
    kubectl get all -A -o wide

    echo "\n>>> [DUMP] Describing all pods in all namespaces..."
    kubectl describe pod -A

    echo "\n>>> [DUMP] Getting all ArgoCD Applications..."
    kubectl get applications -A -o yaml

    echo "\n>>> [DUMP] CRASH LOGS: Previous logs from Traefik pod..."
    kubectl logs -n traefik -l app.kubernetes.io/instance=traefik-traefik --previous || echo "No previous Traefik logs found."

    echo "\n>>> [DUMP] Getting cluster events (last 30)..."
    kubectl get events -A --sort-by='.lastTimestamp' | tail -n 30
    
    echo -e "\n\033[1;31m# ============================================================================== #\033[0m"
    echo -e "\033[1;31m#                            FAILURE DUMP COMPLETE                             #\033[0m"
    echo -e "\033[1;31m# ============================================================================== #\033[0m\n"
}

check_remote_command() {
    local description="$1"
    local command_to_run="$2"
    local max_retries=18
    local attempt=0
    echo "--> Verifying: ${description}"
    while (( attempt < max_retries )); do
        set +e
        output=$(${SSH_CMD} "${SSH_USER}@${VPS_IP}" "${command_to_run}" 2>&1)
        local exit_code=$?
        set -e
        if [ ${exit_code} -eq 0 ]; then
            echo "--> SUCCESS: Verification passed for '${description}'."
            echo "${output}"
            return 0
        fi
        ((attempt++))
        echo "    (Attempt ${attempt}/${max_retries}) Verification failed with exit code ${exit_code}. Output:"
        echo "${output}"
        sleep 10
    done
    echo "FATAL: Timed out waiting for '${description}'." >&2
    return 1
}

# --- Main Execution Logic ---
main() {
    exec &> >(tee -a "$LOG_FILE")
    local step_counter=1
    trap 'echo -e "\n\033[0;31mFATAL: Deployment script failed at STEP $((step_counter - 1)). See ${LOG_FILE} for full details.\033[0m" >&2; failure_dump' ERR

    echo "### DEPLOYMENT ORCHESTRATOR (v16.0) INITIATED AT $(date) ###"
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

    log_step $step_counter "Remote Host Preparation (Simplified & Sequential Cleanup)"
    echo "--> Performing targeted and serialized cleanup on ${VPS_IP}..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" << 'EOF'
        set -ex
        echo '--> [SUB-STEP 2.1] Uninstalling K3s if it exists...'
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        pkill -9 -f "k3s|containerd" || echo "No lingering K3s processes to kill."

        echo '--> [SUB-STEP 2.2] Stopping and removing all Docker containers...'
        if command -v docker &> /dev/null; then
            docker rm -f $(docker ps -aq) || echo "No containers to remove."
        fi
        
        echo '--> [SUB-STEP 2.3] Removing residual files and directories...'
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d /tmp/k3s-install.sh

        echo '--> [SUB-STEP 2.4] Reloading systemd daemon...'
        systemctl daemon-reload
EOF
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
    check_remote_command "etcd service is healthy and responsive via etcdctl" \
        "docker exec core-etcd sh -c 'ETCDCTL_API=3 etcdctl endpoint health'"
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

    trap - EXIT # Disable the trap on successful exit
    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    
    echo -e "\nYour personal cluster is ready and GitOps is running."
    echo -e "\n\033[1;33mArgoCD Login Details:\033[0m"
    echo -e "Access UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (accept the staging certificate)"
    echo -e "Username:  \033[1;36m${ARGOCD_ADMIN_USER}\033[0m"
    echo -e "Password:  \033[1;36m${ARGOCD_PASSWORD}\033[0m"
}

# --- Script Entry Point ---
main "$@"