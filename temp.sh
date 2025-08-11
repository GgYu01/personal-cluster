#!/bin/bash

# ==============================================================================
#            Deep System State Diagnostic Collector (v2.0)
# ==============================================================================
# v2.0:
# - Provides the full, unabbreviated script content.
# - Fixes premature exit in data collection function by running it in a subshell
#   without `set -e`.
# - Adds journald log rotation/cleanup for k3s service to get clean logs.
# - Enhances Traefik log collection to fetch all historical logs.
# ==============================================================================

# --- Strict Mode & Initial Setup ---
set -e
set -o pipefail
LOG_FILE="diagnostic_log_v2_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${LOG_FILE}")
echo "### DIAGNOSTIC COLLECTOR (v2.0) INITIATED AT $(date) ###"

# --- Configuration (Copied from user's script) ---
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
API_SERVER_FQDN="api.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
SSH_KEY_PATH_EXPANDED="${TF_VAR_ssh_private_key_path/#\~/$HOME}"
SSH_CMD="ssh -i ${SSH_KEY_PATH_EXPANDED} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# --- Helper Functions ---
log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP $1: $2 \033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}

# ----------------------------
# --- DIAGNOSTIC FUNCTIONS ---
# ----------------------------
collect_diagnostic_data() {
    echo -e "\n\n\033[1;31m##############################################################################\033[0m"
    echo -e "\033[1;31m#             FAILURE DETECTED. INITIATING DIAGNOSTIC COLLECTION.            #\033[0m"
    echo -e "\033[1;31m##############################################################################\033[0m"

    # Use a subshell to temporarily disable `set -e` and ensure all commands run, even if some fail.
    (
      set +e
      
      # Host-level diagnostics
      echo -e "\n\033[1;33m--- [DIAG-HOST] Listening ports on host (ss -tlpn) ---\033[0m"
      ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "ss -tlpn"
      
      echo -e "\n\033[1;33m--- [DIAG-HOST] Docker processes (docker ps -a) ---\033[0m"
      ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "docker ps -a"

      echo -e "\n\033[1;33m--- [DIAG-HOST] K3s service journal (last 200 lines from this boot) ---\033[0m"
      ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "journalctl -u k3s --no-pager -b -n 200"

      # Kubernetes-level diagnostics
      echo -e "\n\033[1;33m--- [DIAG-K8S] Cluster-wide events (last 50) ---\033[0m"
      kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50

      echo -e "\n\033[1;33m--- [DIAG-K8S] Node status (kubectl get nodes -o wide) ---\033[0m"
      kubectl get nodes -o wide

      echo -e "\n\033[1;33m--- [DIAG-K8S] All pods in all namespaces (kubectl get pods -A -o wide) ---\033[0m"
      kubectl get pods -A -o wide

      # ArgoCD diagnostics
      echo -e "\n\033[1;33m--- [DIAG-ARGOCD] All ArgoCD Applications (YAML output) ---\033[0m"
      kubectl get applications -A -o yaml

      # Deep dive into critical namespaces
      for NS in traefik cert-manager argocd kube-system; do
        echo -e "\n\033[1;33m--- [DIAG-NS] All resources in namespace: ${NS} ---\033[0m"
        kubectl get all -n "${NS}" -o wide

        echo -e "\n\033[1;33m--- [DIAG-PODS] Pod descriptions in namespace: ${NS} ---\033[0m"
        PODS=$(kubectl get pods -n "${NS}" -o jsonpath='{.items[*].metadata.name}')
        if [ -n "$PODS" ]; then
          for POD in $PODS; do
            echo -e "\n--- Describing pod: ${POD} in ${NS} ---"
            kubectl describe pod "${POD}" -n "${NS}"
          done
        else
          echo "No pods found in namespace ${NS}."
        fi
        
        echo -e "\n\033[1;33m--- [DIAG-LOGS] Pod logs in namespace: ${NS} ---\033[0m"
        if [ -n "$PODS" ]; then
          for POD in $PODS; do
            CONTAINERS=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[*].name}')
            for CONTAINER in $CONTAINERS; do
              echo -e "\n--- Logs for pod/container: ${POD}/${CONTAINER} in ${NS} (all historical logs) ---"
              # Fetch ALL logs for the container to ensure we capture the initial crash reason.
              kubectl logs "${POD}" -c "${CONTAINER}" -n "${NS}" --tail=-1
            done
          done
        else
          echo "No pods found in namespace ${NS}."
        fi
      done
    )
    
    echo -e "\n\n\033[1;31m##############################################################################\033[0m"
    echo -e "\033[1;31m#                   DIAGNOSTIC COLLECTION COMPLETE.                          #\033[0m"
    echo -e "\033[1;31m##############################################################################\033[0m"
}

# Modified wait_for_command to trigger diagnostics on failure
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
            # Run the command one last time and show output
            eval "${cmd_to_run}"
            echo "---------------------------------------"
            # Call the data collection function. It will handle its own errors.
            collect_diagnostic_data
            exit 1
        fi
        echo -n "."
        sleep 10
    done
    echo -e "\n--> \033[0;32mSUCCESS:\033[0m '${description}' is ready."
}

# --- Main Execution Logic ---
main() {
    log_step "1" "Verifying Manual DNS Prerequisite"
    local FQDN_TO_TEST="check-$(date +%s).${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
    local RESOLVED_IP=$(dig @1.1.1.1 "${FQDN_TO_TEST}" +short +time=5)
    if [[ "${RESOLVED_IP}" != "${TF_VAR_vps_ip}" ]]; then
        echo "FATAL: DNS Prerequisite Not Met! Wildcard DNS record for *.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name} does not resolve to ${TF_VAR_vps_ip}." >&2
        exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."

    log_step "2" "Preparing Environment (Enhanced Cleanup)"
    rm -rf 01-infra/.terraform* 01-infra/terraform.tfstate* ~/.kube/config
    ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" '
        set -x
        # Enhanced cleanup
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down -v --remove-orphans &>/dev/null); fi
        # Force stop and remove any container named core-etcd
        docker ps -a -q --filter "name=core-etcd" | xargs -r docker stop
        docker ps -a -q --filter "name=core-etcd" | xargs -r docker rm -v
        # Thoroughly remove all related directories
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d
        # Rotate journald logs for the k3s unit to get a clean slate
        echo "Rotating journald logs for k3s service..."
        journalctl --rotate --unit=k3s &>/dev/null
        journalctl --vacuum-time=1s --unit=k3s &>/dev/null
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
    wait_for_command "curl -s --fail -v https://argocd.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name} 2>&1 | grep -q 'issuer: C=US; O=(STAGING) Let'" "HTTPS access to ArgoCD FQDN" 180

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#               ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                       #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and GitOps is running."
    echo -e "\n\033[1;33mACTION REQUIRED: Get your initial admin password\033[0m"
    echo -e "Run: \033[1;36mkubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo\033[0m"
    echo -e "\nAccess UI: \033[1;36mhttps://argocd.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}\033[0m (Username: ${ADMIN_USERNAME})"
}

# --- Script Entry Point ---
# The script will exit with a non-zero status if any command in main() fails,
# due to `set -e`. The wait_for_command function will trigger diagnostics
# before exiting.
main