#!/bin/bash

# ==============================================================================
#                 The Definitive Orchestrator & Diagnoser (v5.0)
# ==============================================================================
#
# v5.0 Philosophy:
# - ARCHITECTURAL SHIFT: Abandons the fragile `hostPort` mechanism in favor of
#   the robust and standard `DaemonSet` + `hostNetwork: true` pattern for the
#   ingress controller. This is the industry best-practice.
# - COMPLETE & SELF-CONTAINED: This script is now monolithic, containing all
#   helper functions and logic, to be provided in its entirety as requested.
# - UNCOMPROMISING DIAGNOSTICS: Retains the enhanced data collection on failure,
#   ensuring any unforeseen issues are captured with full context.
#
# ==============================================================================

# --- Strict Mode & Initial Setup ---
set -e
set -o pipefail
LOG_FILE="deployment_v5.0_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${LOG_FILE}")
echo "### DEPLOYMENT ORCHESTRATOR (v5.0) INITIATED AT $(date) ###"

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

collect_diagnostic_data() {
    (
      set +e
      echo -e "\n\n\033[1;31m##############################################################################\033[0m"
      echo -e "\033[1;31m#             FAILURE DETECTED. INITIATING DIAGNOSTIC COLLECTION.            #\033[0m"
      echo -e "\033[1;31m##############################################################################\033[0m"

      echo -e "\n\033[1;33m--- [DIAG-HOST] Listening ports on host (ss -tlpn) ---\033[0m"
      ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "ss -tlpn" || echo "[DIAG] Failed: ss"

      echo -e "\n\033[1;33m--- [DIAG-HOST] K3s service journal (last 200 lines from this boot) ---\033[0m"
      ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "journalctl -u k3s --no-pager -b -n 200" || echo "[DIAG] Failed: journalctl"

      echo -e "\n\033[1;33m--- [DIAG-K8S] Node status (kubectl get nodes -o wide) ---\033[0m"
      kubectl get nodes -o wide || echo "[DIAG] Failed: get nodes"

      echo -e "\n\033[1;33m--- [DIAG-K8S] All pods in all namespaces (kubectl get pods -A -o wide) ---\033[0m"
      kubectl get pods -A -o wide || echo "[DIAG] Failed: get pods"
      
      echo -e "\n\033[1;33m--- [DIAG-ARGOCD] All ArgoCD Applications (YAML output) ---\033[0m"
      kubectl get applications -A -o yaml || echo "[DIAG] Failed: get applications"

      for NS in traefik cert-manager argocd kube-system; do
        echo -e "\n\033[1;33m--- [DIAG-NS] Resources in namespace: ${NS} ---\033[0m"
        kubectl get all -n "${NS}" -o wide || echo "[DIAG] Failed: get all in ${NS}"

        echo -e "\n\033[1;33m--- [DIAG-PODS] Pod descriptions in namespace: ${NS} ---\033[0m"
        PODS=$(kubectl get pods -n "${NS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ -n "$PODS" ]; then
          for POD in $PODS; do
            echo "--- Describing pod: ${POD} in ${NS} ---"
            kubectl describe pod "${POD}" -n "${NS}" || echo "[DIAG] Failed to describe pod ${POD}"
          done
        else
          echo "No pods found in namespace ${NS}."
        fi
        
        echo -e "\n\033[1;33m--- [DIAG-LOGS] Pod logs in namespace: ${NS} (all logs) ---\033[0m"
        if [ -n "$PODS" ]; then
          for POD in $PODS; do
            CONTAINERS=$(kubectl get pod "${POD}" -n "${NS}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
            for CONTAINER in $CONTAINERS; do
              echo "--- Logs for pod/container: ${POD}/${CONTAINER} in ${NS} ---"
              kubectl logs "${POD}" -c "${CONTAINER}" -n "${NS}" --tail=-1 || echo "[DIAG] Failed to get logs for ${POD}/${CONTAINER}"
            done
          done
        else
          echo "No pods found in namespace ${NS}."
        fi
      done
      
      echo -e "\n\033[1;31m--- END OF DIAGNOSTICS ---\033[0m"
    )
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
            eval "${cmd_to_run}" || true
            echo "---------------------------------------"
            collect_diagnostic_data
            exit 1
        fi
        echo -n "."
        sleep 10
    done
    echo -e "\n--> \033[0;32mSUCCESS:\033[0m '${description}' is ready."
}

function step_01_verify_dns() {
    local FQDN_TO_TEST="check-$(date +%s).${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
    local RESOLVED_IP=$(dig @1.1.1.1 "${FQDN_TO_TEST}" +short +time=5)
    if [[ "${RESOLVED_IP}" != "${TF_VAR_vps_ip}" ]]; then
        echo "FATAL: DNS Prerequisite Not Met! Wildcard DNS for *.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name} does not resolve to ${TF_VAR_vps_ip}." >&2
        exit 1
    fi
    echo "--> SUCCESS: DNS prerequisite is met."
}

function step_02_prepare_environment() {
    rm -rf 01-infra/.terraform* 01-infra/terraform.tfstate* ~/.kube/config
    ${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" '
        set -x
        if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
        if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose down -v --remove-orphans &>/dev/null); fi
        docker ps -a -q --filter "name=core-etcd" | xargs -r docker stop >/dev/null 2>&1
        docker ps -a -q --filter "name=core-etcd" | xargs -r docker rm -v >/dev/null 2>&1
        rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd /var/lib/cni/ /etc/cni/net.d
        echo "Rotating journald logs for k3s service..."
        journalctl --rotate --unit=k3s >/dev/null 2>&1 || true
        journalctl --vacuum-time=1s --unit=k3s >/dev/null 2>&1 || true
        systemctl daemon-reload
    '
    echo "--> SUCCESS: Environment prepared."
}

function step_03_apply_infrastructure() {
    cd 01-infra
    terraform init -upgrade >/dev/null
    terraform apply -auto-approve
    cd ..
}

function step_04_verify_k3s_and_get_kubeconfig() {
    KUBECONFIG_PATH=~/.kube/config
    RAW_KUBECONFIG=$(${SSH_CMD} "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
    PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
    mkdir -p ~/.kube && echo "${PROCESSED_KUBECONFIG}" > "${KUBECONFIG_PATH}" && chmod 600 "${KUBECONFIG_PATH}"
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    wait_for_command "kubectl get nodes --no-headers | grep -q ' Ready'" "K3s node readiness" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=kube-dns -n kube-system --timeout=30s" "CoreDNS pods" 300
    wait_for_command "kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=30s" "metrics-server" 300
    echo "--> SUCCESS: Core cluster is healthy."
}

function step_05_bootstrap_argocd() {
    kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null || true
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || true
    helm repo update > /dev/null
    helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" -n "${ARGOCD_NS}" --set server.service.type=ClusterIP --wait --timeout 15m
    kubectl apply -f kubernetes/bootstrap/root.yaml
}

function step_06_final_verification() {
    echo "--> [6.1] Verifying Cert-Manager installation..."
    wait_for_command "kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=30s" "Cert-Manager deployment to be Available" 300
    echo "--> [6.2] Verifying Traefik installation..."
    # We now wait for the DaemonSet to be ready, not a Deployment
    wait_for_command "kubectl -n traefik get daemonset traefik -o jsonpath='{.status.numberReady}' | grep -q 1" "Traefik DaemonSet to be Ready" 300
    echo "--> [6.3] Verifying Traefik is listening on host ports..."
    wait_for_command "${SSH_CMD} '${TF_VAR_ssh_user}@${TF_VAR_vps_ip}' \"ss -tlpn | grep -E ':80 |:443 ' | grep 'traefik'\"" "Traefik to be listening on host ports 80/443" 180
    echo "--> [6.4] Verifying Let's Encrypt Certificate and HTTPS access for ArgoCD..."
    wait_for_command "kubectl get secret argocd-server-tls-staging -n argocd" "Let's Encrypt Certificate for ArgoCD" 600
    wait_for_command "curl -s --fail -k -v https://${ARGOCD_FQDN} 2>&1 | grep -q 'issuer: C=US; O=(STAGING) Let'" "HTTPS access to ${ARGOCD_FQDN}" 180
}

# --- Main Execution Logic ---
main() {
    log_step "1" "Verifying Manual DNS Prerequisite"
    step_01_verify_dns

    log_step "2" "Preparing Environment (Enhanced Cleanup)"
    step_02_prepare_environment
    
    log_step "3" "Applying Core Infrastructure (etcd & K3s)"
    step_03_apply_infrastructure

    log_step "4" "Verifying Cluster Health and Setting up Kubeconfig"
    step_04_verify_k3s_and_get_kubeconfig
    
    log_step "5" "Bootstrapping GitOps with ArgoCD"
    step_05_bootstrap_argocd

    log_step "6" "Final End-to-End Verification"
    step_06_final_verification

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#               ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                       #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready."
    echo -e "\nArgoCD UI: \033[1;36mhttps://${ARGOCD_FQDN}\033[0m"
    echo -e "\nTo get the initial admin password, run:"
    echo -e "\033[1;36mkubectl -n ${ARGOCD_NS} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo\033[0m"
}

main