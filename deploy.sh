#!/bin/bash

# ==============================================================================
# DEPLOYMENT ORCHESTRATOR (v25.0 - Security Module Hardening)
# ==============================================================================
# This version addresses the Kubelet "InvalidDiskCapacity" error by explicitly
# disabling SELinux and AppArmor in the K3s installation arguments. It also
# reverts to the robust two-stage CoreDNS health check.

set -eo pipefail

# --- Configuration Variables (Unchanged) ---
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
readonly ETCD_PROJECT_NAME="personal-cluster-etcd"

# --- Script-derived Variables (Unchanged) ---
readonly LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"
readonly ARGOCD_NS="argocd"
readonly TRAEFIK_NS="traefik"
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly SSH_CMD="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -i ${SSH_PRIVATE_KEY_PATH}"
readonly TF_DIR="01-infra"
readonly KUBECONFIG_PATH="${HOME}/.kube/config"

# --- Helper Functions (Unchanged) ---
log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP ${1}: ${2} (Timestamp: $(date -u --iso-8601=seconds))\033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}

failure_dump() {
    echo -e "\n\033[1;31m# ============================================================================== #\033[0m"
    echo -e "\033[1;31m#                      CAPTURING KUBERNETES FAILURE DUMP                       #\033[0m"
    echo -e "\033[1;31m# ============================================================================== #\033[0m\n"
    if ! [ -f "${KUBECONFIG_PATH}" ]; then
        echo "Kubeconfig not found, cannot perform dump."
        return
    fi
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    echo ">>> [DUMP] Checking kubectl connectivity..."
    kubectl version || echo "kubectl connection failed."
    echo "\n>>> [DUMP] Getting all resources in all namespaces..."
    kubectl get all -A -o wide
    echo "\n>>> [DUMP] Describing all pods in all namespaces..."
    kubectl describe pod -A
    echo "\n>>> [DUMP] Getting all ArgoCD Applications..."
    kubectl get applications -A -o yaml || echo "Failed to get ArgoCD Applications."
    echo "\n>>> [DUMP] CRASH LOGS: Previous logs from any crashing pod..."
    kubectl get pods -A | awk '$4 ~ /CrashLoopBackOff|Error/ {print ">>> Getting previous logs for pod " $2 " in namespace " $1; system("kubectl logs -n " $1 " " $2 " --previous")}'
    echo "\n>>> [DUMP] Getting cluster events (last 30)..."
    kubectl get events -A --sort-by='.lastTimestamp' | tail -n 30
    echo -e "\n\033[1;31m#                            FAILURE DUMP COMPLETE                             #\033[0m\n"
}

# --- Main Execution Logic ---
main() {
    exec &> >(tee -a "$LOG_FILE")
    local step_counter=1
    trap 'echo -e "\n\033[0;31mFATAL: Deployment script failed at STEP $((step_counter - 1)). See ${LOG_FILE} for full details.\033[0m" >&2; failure_dump' ERR

    echo "### DEPLOYMENT ORCHESTRATOR (v25.0) INITIATED AT $(date) ###"
    echo "Full log will be saved to: ${LOG_FILE}"

    log_step $step_counter "DNS Prerequisite Verification"; ((step_counter++))
    echo "--> Verifying wildcard DNS record '*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}' points to ${VPS_IP}..."
    local resolved_ip
    resolved_ip=$(dig @"1.1.1.1" "test-wildcard.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}" +short)
    if [[ "${resolved_ip}" != "${VPS_IP}" ]]; then
        echo "FATAL: DNS Query failed or incorrect. Expected '${VPS_IP}', but got '${resolved_ip}'." >&2
        exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."

    log_step $step_counter "Remote Host Deep Cleanup & MAX PERMISSIONS"; ((step_counter++))
    echo "--> Performing targeted cleanup and applying maximum permissions on ${VPS_IP}..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" <<'EOF'
        set -ex
        
        echo '--> [PERM] Disabling AppArmor...'
        if command -v systemctl &> /dev/null && systemctl is-active --quiet apparmor; then
            systemctl stop apparmor
            systemctl disable apparmor
        else
            echo "AppArmor not active or not installed."
        fi

        echo '--> [PERM] Disabling firewalls (UFW, firewalld)...'
        if command -v ufw &> /dev/null; then ufw disable; fi || echo "UFW not found."
        if command -v systemctl &> /dev/null && systemctl is-active --quiet firewalld; then systemctl stop firewalld && systemctl disable firewalld; fi || echo "firewalld not active."

        echo '--> [PERM] Setting SELinux to Permissive mode...'
        if command -v setenforce &> /dev/null; then setenforce 0; fi || echo "setenforce not found, SELinux likely not installed."

        echo '--> [CLEANUP] Uninstalling K3s if it exists...'
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi
        pkill -9 -f "k3s|containerd|flannel" || echo "No lingering K3s processes to kill."

        echo '--> [CLEANUP] Stopping and removing deployment-specific etcd container...'
        if command -v docker &> /dev/null; then
            docker rm -f core-etcd || echo "Container 'core-etcd' not found or already removed."
        fi
        
        echo '--> [CLEANUP] Removing residual files and directories...'
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d /tmp/k3s-install-wrapper.sh /tmp/k3s-install-output.log

        echo '--> [CLEANUP] Clearing old journald logs for relevant services...'
        journalctl --rotate
        journalctl --vacuum-time=1s
        
        echo '--> [CLEANUP] Restarting Docker daemon to reset network state...'
        systemctl restart docker

        echo '--> [CLEANUP] Reloading systemd daemon...'
        systemctl daemon-reload
EOF
    echo "--> SUCCESS: Remote host cleaned and permissions maximized."

    log_step $step_counter "Terraform Infrastructure Provisioning"; ((step_counter++))
    (
        cd "${TF_DIR}" || exit 1
        rm -f .terraform.lock.hcl terraform.tfstate*
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
            -var="gitops_repo_url=${GITOPS_REPO_URL}" \
            -var="etcd_project_name=${ETCD_PROJECT_NAME}"
    )
    echo "--> SUCCESS: Core infrastructure provisioned."

    log_step $step_counter "Verifying K3s Installation Script Execution"; ((step_counter++))
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "grep -q 'K3s Installation Script Finished Successfully' /tmp/k3s-install-output.log"
    echo "--> SUCCESS: K3s installation script execution verified."

    log_step $step_counter "Post-Terraform Verification"; ((step_counter++))
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "docker exec core-etcd etcdctl endpoint health" | grep -q "is healthy"
    echo "--> SUCCESS: etcd is healthy."

    log_step $step_counter "Local Kubeconfig Setup & Cluster Health Check"; ((step_counter++))
    echo "--> Fetching and configuring local kubeconfig..."
    RAW_KUBECONFIG=$(${SSH_CMD} "${SSH_USER}@${VPS_IP}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/" | sed "s/default/personal-cluster/")
    mkdir -p "$(dirname "${KUBECONFIG_PATH}")" && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    echo "--> Waiting for K3s node to become Ready..."
    kubectl wait --for=condition=Ready node --all --timeout=5m

    echo "--> Stage 1: Waiting for CoreDNS Deployment object to be created by K3s..."
    local coredns_attempts=0
    local max_coredns_attempts=24
    while ! kubectl get deployment coredns -n kube-system &> /dev/null; do
        ((coredns_attempts++))
        if ((coredns_attempts > max_coredns_attempts)); then
            echo "FATAL: Timed out waiting for CoreDNS deployment to be created." >&2
            exit 1
        fi
        echo "    (Attempt ${coredns_attempts}/${max_coredns_attempts}) CoreDNS deployment not found, retrying in 5 seconds..."
        sleep 5
    done
    echo "--> SUCCESS: CoreDNS Deployment object found."

    echo "--> Stage 2: Waiting for CoreDNS to be available..."
    kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=5m
    echo "--> SUCCESS: Cluster is healthy and kubeconfig is set up."

    log_step $step_counter "GitOps Bootstrap (ArgoCD)"; ((step_counter++))
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
    
    log_step $step_counter "Final End-to-End Verification"; ((step_counter++))
    echo "--> 1/5: Waiting for all ArgoCD applications to become Healthy & Synced..."
    kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application --all -n ${ARGOCD_NS} --timeout=15m
    kubectl wait --for=jsonpath='{.status.sync.status}'=Synced application --all -n ${ARGOCD_NS} --timeout=15m
    echo "--> SUCCESS: All applications are Healthy and Synced."

    echo "--> 2/5: Waiting for Traefik DaemonSet to be ready..."
    kubectl rollout status daemonset/traefik -n ${TRAEFIK_NS} --timeout=5m
    echo "--> SUCCESS: Traefik DaemonSet is ready."

    echo "--> 3/5: Verifying Traefik is listening on host ports..."
    ${SSH_CMD} "${SSH_USER}@${VPS_IP}" "ss -tlpn | grep -E ':(80|443)'"
    echo "--> SUCCESS: Traefik is listening on host ports 80 & 443."

    echo "--> 4/5: Verifying ClusterIssuer is ready..."
    kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m
    echo "--> SUCCESS: ClusterIssuer is ready."

    echo "--> 5/5: Verifying ArgoCD Ingress certificate is issued..."
    kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n ${ARGOCD_NS} --timeout=5m
    echo "--> SUCCESS: Certificate for ArgoCD has been issued."

    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    trap - EXIT
    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    
    echo -e "\nYour personal cluster is ready and GitOps is running."
    echo -e "\n\033[1;33mArgoCD Login Details:\033[0m"
    echo -e "Access UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (accept the staging certificate)"
    echo -e "Username:  \033[1;36m${ARGOCD_ADMIN_USER}\033[0m"
    echo -e "Password:  \033[1;36m${ARGOCD_PASSWORD}\033[0m"
}

main "$@"