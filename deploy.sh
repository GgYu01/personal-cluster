#!/usr/bin/env bash

# ==============================================================================
#
#       PERSONAL CLUSTER DEPLOYMENT BOOTSTRAPPER (v23.1 - Static Password)
#
# ==============================================================================
#
#   VERSION 23.1 CHANGE LOG:
#   - PASSWORD MANAGEMENT: Implemented static password for Argo CD 'admin' user
#     based on official Helm chart v8.2.7 documentation. The password is now
#     consistently 'password'.
#   - BOOTSTRAP PROCESS: Modified both the initial 'helm install' command and the
#     GitOps Application manifest (`argocd-app.yaml`) to include the bcrypt-hashed
#     password. This ensures correctness at creation and prevents configuration
#     drift during self-healing.
#   - VERIFICATION: Removed logic for retrieving a random password. The final
#     output now displays the static credentials.
#
# ==============================================================================

set -eo pipefail

# --- [SECTION 1: CONFIGURATION VARIABLES] ---
readonly VPS_IP="172.245.187.113"
readonly DOMAIN_NAME="gglohh.top"
readonly SITE_CODE="core01"
readonly ENVIRONMENT="prod"
readonly K3S_CLUSTER_TOKEN="admin" # Simple, as requested
readonly ARGOCD_ADMIN_PASSWORD="password"

# --- Software Versions ---
readonly K3S_VERSION="v1.33.3+k3s1"

# --- Internal Settings ---
readonly ETCD_PROJECT_NAME="personal-cluster-etcd"
readonly ETCD_CONTAINER_NAME="core-etcd"
readonly ETCD_DATA_DIR="/opt/etcd/data"
readonly ETCD_CONTAINER_USER_ID=1001
readonly ETCD_NETWORK_NAME="${ETCD_PROJECT_NAME}_default"
readonly KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
readonly USER_KUBECONFIG_PATH="${HOME}/.kube/config"
readonly TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
readonly LOG_FILE_NAME="deployment-bootstrap-${TIMESTAMP}.log"
readonly LOG_FILE="$(pwd)/${LOG_FILE_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly KUBELET_CONFIG_PATH="/etc/rancher/k3s/kubelet.config"

# --- [START OF PASSWORD FIX] ---
# Statically define the bcrypt hash for the password 'password'.
# This avoids re-calculating it on every run and makes the script's intent clearer.
readonly ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$Xx3c/ILSzwZfp2wHhoPxFOwH4yFp3MepBtoZpR2JgTsPaG6dz1EYS'
# --- [END OF PASSWORD FIX] ---

# --- [SECTION 2: LOGGING & DIAGNOSTICS] ---
log_step() { printf "\n\n\033[1;34m# ============================================================================== #\033[0m\n"; printf "\033[1;34m# STEP %s: %s (Timestamp: %s)\033[0m\n" "$1" "$2" "$(date -u --iso-8601=seconds)"; printf "\033[1;34m# ============================================================================== #\033[0m\n\n"; }
log_info() { echo "--> INFO: $1"; }
log_warn() { echo -e "\033[1;33m⚠️  WARN: $1\033[0m"; }
log_success() { echo -e "\033[1;32m✅ SUCCESS:\033[0m $1"; }
log_error_and_exit() { echo -e "\n\033[1;31m❌ FATAL ERROR:\033[0m $1" >&2; echo -e "\033[1;31mDeployment failed. See ${LOG_FILE} for full details.\033[0m" >&2; exit 1; }

run_with_retry() {
    local cmd="$1"
    local description="$2"
    local timeout_seconds="$3"
    local interval_seconds="${4:-10}"
    
    log_info "Verifying: ${description} (Timeout: ${timeout_seconds}s)"
    if ! timeout "${timeout_seconds}s" bash -c -- "until ${cmd} &>/dev/null; do printf '    ...waiting...\\n'; sleep ${interval_seconds}; done"; then
        log_warn "Condition '${description}' was NOT met within the timeout period."
        return 1
    fi
    log_success "Verified: ${description}."
    return 0
}

# --- [SECTION 3: DEPLOYMENT FUNCTIONS] ---

function perform_system_cleanup() {
    log_step 1 "System Cleanup"
    log_info "This step will eradicate all traces of previous K3s and this project's ETCD."
    
    log_info "Stopping k3s, docker, and containerd services..."
    systemctl stop k3s.service &>/dev/null || true
    systemctl disable k3s.service &>/dev/null || true
    
    if command -v docker &>/dev/null && systemctl is-active --quiet docker.service; then
        log_info "Forcefully removing project's ETCD container and network..."
        docker rm -f "${ETCD_CONTAINER_NAME}" &>/dev/null || true
        docker network rm "${ETCD_NETWORK_NAME}" &>/dev/null || true
    else
        log_warn "Docker not running or not installed. Skipping Docker resource cleanup."
    fi
    
    log_info "Running K3s uninstaller and cleaning up filesystem..."
    if [ -x /usr/local/bin/k3s-uninstall.sh ]; then
        /usr/local/bin/k3s-uninstall.sh &>/dev/null
    fi
    rm -rf /var/lib/rancher/k3s /etc/rancher /var/lib/kubelet /run/flannel /run/containerd /var/lib/containerd /tmp/k3s-*
    rm -rf "${ETCD_DATA_DIR}"
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env "${KUBELET_CONFIG_PATH}" "${KUBECONFIG_PATH}"
    rm -rf "${HOME}/.kube"

    log_info "Reloading systemd and cleaning journals for k3s and docker..."
    systemctl daemon-reload
    journalctl --rotate && journalctl --vacuum-time=1s
    
    log_success "System cleanup complete."
}

function deploy_etcd() {
    log_step 2 "Deploy and Verify External ETCD"
    
    log_info "Preparing ETCD data directory with correct permissions for UID ${ETCD_CONTAINER_USER_ID}..."
    mkdir -p "${ETCD_DATA_DIR}"
    chown -R "${ETCD_CONTAINER_USER_ID}:${ETCD_CONTAINER_USER_ID}" "${ETCD_DATA_DIR}"
    
    log_info "Deploying ETCD via Docker..."
    docker run -d --restart unless-stopped \
      -p 127.0.0.1:2379:2379 \
      -v "${ETCD_DATA_DIR}":/bitnami/etcd/data \
      --name "${ETCD_CONTAINER_NAME}" \
      -e ALLOW_NONE_AUTHENTICATION=yes \
      bitnami/etcd:latest >/dev/null
      
    log_success "ETCD container started."

    if ! run_with_retry "curl --fail --silent http://127.0.0.1:2379/health" "ETCD to be healthy" 60 5; then
        log_info "ETCD health check failed. Dumping container logs for diagnosis:"
        docker logs "${ETCD_CONTAINER_NAME}"
        log_error_and_exit "ETCD deployment failed."
    fi
}

function install_k3s() {
    log_step 3 "Install and Verify K3S"
    
    log_info "Preparing K3s manifest and configuration directories..."
    mkdir -p /var/lib/rancher/k3s/server/manifests
    mkdir -p "$(dirname "${KUBELET_CONFIG_PATH}")"
    
    log_info "Creating Traefik CRD provider and Kubelet swap configurations..."
    cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesCRD:
        enabled: true
EOF

    cat > "${KUBELET_CONFIG_PATH}" << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF
    log_success "K3s customization manifests created."

    log_info "Installing K3s ${K3S_VERSION}..."
    local install_cmd=(
        "curl -sfL https://get.k3s.io |"
        "INSTALL_K3S_VERSION='${K3S_VERSION}'"
        "K3S_TOKEN='${K3S_CLUSTER_TOKEN}'"
        "sh -s - server"
        "--cluster-init"
        "--datastore-endpoint='http://127.0.0.1:2379'"
        "--tls-san='${VPS_IP}'"
        "--flannel-backend=host-gw"
        "--kubelet-arg='config=${KUBELET_CONFIG_PATH}'"
    )
    eval "${install_cmd[*]}"
    log_success "K3s installation script finished."

    log_info "Setting up kubeconfig for user..."
    mkdir -p "$(dirname "${USER_KUBECONFIG_PATH}")"
    cp "${KUBECONFIG_PATH}" "${USER_KUBECONFIG_PATH}"
    chown "$(id -u):$(id -g)" "${USER_KUBECONFIG_PATH}"
    export KUBECONFIG="${USER_KUBECONFIG_PATH}"
    
    if ! run_with_retry "kubectl get node $(hostname | tr '[:upper:]' '[:lower:]') --no-headers | awk '{print \$2}' | grep -q 'Ready'" "K3s node to be Ready" 180; then
        log_info "K3s node did not become ready. Dumping K3s service logs:"
        journalctl -u k3s.service --no-pager -n 500
        log_error_and_exit "K3s cluster verification failed."
    fi
}

function bootstrap_gitops() {
    log_step 4 "Bootstrap GitOps Engine (Argo CD)"

    log_info "Bootstrapping Argo CD via Helm..."
    log_info "This initial install will create CRDs and components with static credentials."

    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || helm repo update

    # --- [START OF PASSWORD FIX] ---
    # Inject the bcrypt-hashed password and the '--insecure' flag during the initial Helm install.
    # This ensures the 'argocd-secret' is created with the correct static password from the very beginning,
    # preventing the creation of the 'argocd-initial-admin-secret' with a random password.
    helm upgrade --install argocd argo/argo-cd \
        --version 8.2.7 \
        --namespace argocd --create-namespace \
        --set-string "server.extraArgs={--insecure}" \
        --set-string "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
        --set-string "configs.secret.argocdServerAdminPasswordMtime=$(date -u --iso-8601=seconds)" \
        --wait --timeout=15m
    # --- [END OF PASSWORD FIX] ---

    log_success "Argo CD components and CRDs installed via Helm with static password."

    log_info "Applying Argo CD application manifests to enable GitOps self-management..."
    kubectl apply -f kubernetes/bootstrap/argocd-app.yaml

    log_info "Waiting for Argo CD to sync its own application resource..."
    if ! run_with_retry "kubectl get application/argocd -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Argo CD to become Healthy and self-managed" 300; then
        log_info "Argo CD self-management sync failed. Dumping application status:"
        kubectl get application/argocd -n argocd -o yaml
        log_error_and_exit "Argo CD bootstrap failed at self-management step."
    fi

    log_success "Argo CD has been bootstrapped and is now self-managing via GitOps."
}

function deploy_applications() {
    log_step 5 "Deploy Core Applications via GitOps"
    
    log_info "Applying application definitions for Argo CD to manage..."
    kubectl apply -f kubernetes/apps/
    
    log_info "Waiting for Cert-Manager application to become Healthy in Argo CD..."
    if ! run_with_retry "kubectl get application/cert-manager -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Cert-Manager Argo CD App to be Healthy" 300; then
        log_error_and_exit "Cert-Manager deployment via Argo CD failed."
    fi
    log_success "Cert-Manager application is Healthy in Argo CD."

    log_info "Verifying that the cert-manager webhook is ready to serve requests..."
    if ! run_with_retry "kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=3m" "cert-manager webhook Deployment to be Available" 180; then
        log_info "Cert-Manager webhook did not become available. Dumping deployment status and logs:"
        kubectl -n cert-manager describe deployment/cert-manager-webhook
        kubectl -n cert-manager logs -l app.kubernetes.io/name=webhook --all-containers
        log_error_and_exit "Cert-Manager webhook verification failed."
    fi
    log_success "Cert-Manager webhook is available."
    
    log_info "Waiting for core-manifests application to become Healthy..."
    if ! run_with_retry "kubectl get application/core-manifests -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "core-manifests Argo CD App to be Healthy" 300; then
        log_info "Core manifest deployment via Argo CD failed. Dumping application status:"
        kubectl get application/core-manifests -n argocd -o yaml
        log_error_and_exit "Core manifest deployment via Argo CD failed."
    fi
    
    log_success "All applications are managed by Argo CD and report as Healthy."
}

function final_verification() {
    log_step 6 "Final End-to-End Verification"
    
    log_info "Verifying ClusterIssuer 'cloudflare-staging' is ready..."
    if ! run_with_retry "kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m" "ClusterIssuer to be Ready" 120 10; then
        log_info "ClusterIssuer did not become ready. Dumping Cert-Manager logs:"
        kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --all-containers
        log_error_and_exit "ClusterIssuer verification failed."
    fi

    log_info "Verifying ArgoCD IngressRoute certificate has been issued..."
    if ! run_with_retry "kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=5m" "Certificate to be Ready" 300 15; then
        log_info "Certificate did not become ready. Dumping Cert-Manager logs and describing Certificate:"
        kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --all-containers
        kubectl describe certificate -n argocd argocd-server-tls-staging
        log_error_and_exit "Certificate issuance failed."
    fi

    log_info "Performing final reachability check on ArgoCD URL: https://${ARGOCD_FQDN}"
    local check_cmd="curl -k -L -s -o /dev/null -w '%{http_code}' --resolve ${ARGOCD_FQDN}:443:${VPS_IP} https://${ARGOCD_FQDN}/ | grep -q '200'"
    if ! run_with_retry "${check_cmd}" "ArgoCD UI to be reachable (HTTP 200 OK)" 120 10; then
        log_info "ArgoCD UI is not reachable or not returning HTTP 200. Dumping Traefik and Argo CD Server logs:"
        kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
        kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
        log_error_and_exit "End-to-end verification failed."
    fi
}

# --- [SECTION 4: MAIN EXECUTION] ---
main() {
    # Pre-flight checks
    if [[ $EUID -ne 0 ]]; then log_error_and_exit "This script must be run as root."; fi
    if ! command -v docker &> /dev/null || ! systemctl is-active --quiet docker; then log_error_and_exit "Docker is not installed or not running."; fi
    if ! command -v helm &> /dev/null; then log_error_and_exit "Helm is not installed. Please install Helm to proceed."; fi
    if [ ! -d "kubernetes/bootstrap" ] || [ ! -d "kubernetes/apps" ]; then log_error_and_exit "Required directories 'kubernetes/bootstrap' and 'kubernetes/apps' not found. Run from repo root."; fi
    
    touch "${LOG_FILE}" &>/dev/null || { echo "FATAL ERROR: Cannot write to log file at ${LOG_FILE}." >&2; exit 1; }
    exec &> >(tee -a "$LOG_FILE")

    log_info "Deployment Bootstrapper (v23.1) initiated. Full log: ${LOG_FILE}"
    
    perform_system_cleanup
    deploy_etcd
    install_k3s
    bootstrap_gitops
    deploy_applications
    final_verification

    # --- [START OF PASSWORD FIX] ---
    # The password is now static. The success message is updated to reflect this.
    # The 'argocd-initial-admin-secret' should no longer exist with this new method.
    log_info "Verifying 'argocd-initial-admin-secret' is not present..."
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        log_warn "The 'argocd-initial-admin-secret' still exists, which is unexpected. The password should be managed by 'argocd-secret'."
    else
        log_success "'argocd-initial-admin-secret' is not present, as expected."
    fi
    # --- [END OF PASSWORD FIX] ---

    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and managed by ArgoCD."
    echo -e "\n\033[1;33mArgoCD Access Details:\033[0m"
    echo -e "  UI:      \033[1;36mhttps://${ARGOCD_FQDN}\033[0m"
    echo -e "           (NOTE: You must accept the 'staging' or 'untrusted' certificate in your browser)"
    echo -e "  User:    \033[1;36madmin\033[0m"
    echo -e "  Password:\033[1;36m ${ARGOCD_ADMIN_PASSWORD}\033[0m"

    echo -e "\nTo log in via CLI:"
    echo -e "  \033[0;35margocd login ${ARGOCD_FQDN} --username admin --password '${ARGOCD_ADMIN_PASSWORD}' --insecure\033[0m"
    echo -e "\nKubeconfig is available at: ${USER_KUBECONFIG_PATH}"
}

main "$@"