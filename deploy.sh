#!/usr/bin/env bash

# ==============================================================================
#
# PERSONAL CLUSTER DEPLOYMENT INSTALLER (v3.6 - INTEGRATED GITOPS DEBUGGING)
#
# ==============================================================================
#
#   VERSION 3.6 CHANGE:
#   - INTEGRATED DEBUGGING: The script now calls a dedicated 'temp.sh'
#     script upon failure. This provides a deep dive into the state of
#     ArgoCD applications, controllers, and managed resources, allowing for
#     precise diagnosis of GitOps-layer issues.
#
# ==============================================================================

set -eo pipefail

# --- [SECTION 1: CONFIGURATION VARIABLES] ---
readonly VPS_IP="172.245.187.113"; readonly DOMAIN_NAME="gglohh.top"; readonly SITE_CODE="core01"; readonly ENVIRONMENT="prod"; readonly K3S_VERSION="v1.33.3+k3s1"; readonly K3S_CLUSTER_TOKEN="admin"; readonly ETCD_PROJECT_NAME="personal-cluster-etcd"; readonly ETCD_CONTAINER_NAME="core-etcd"; readonly GITOPS_REPO_URL="https://github.com/GgYu01/personal-cluster.git"; readonly ARGOCD_CHART_VERSION="8.2.7"; readonly ARGOCD_ADMIN_USER="admin"

# --- [SECTION 2: SCRIPT-DERIVED VARIABLES & HELPERS] ---
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"; readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"; readonly KUBECONFIG_PATH="${HOME}/.kube/config"; readonly LOG_FILE_NAME="deployment-$(date +%Y%m%d-%H%M%S).log"; readonly LOG_FILE="$(pwd)/${LOG_FILE_NAME}"

log_step() { echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"; echo -e "\033[1;34m# STEP ${1}: ${2} (Timestamp: $(date -u --iso-8601=seconds))\033[0m"; echo -e "\033[1;34m# ============================================================================== #\033[0m\n"; }
log_info() { echo "--> INFO: $1"; }
log_success() { echo -e "\033[1;32m✅ SUCCESS:\033[0m $1"; }
log_error_and_exit() { echo -e "\n\033[1;31m❌ FATAL ERROR:\033[0m $1" >&2; echo -e "\033[1;31mDeployment failed. See ${LOG_FILE} for full details.\033[0m" >&2; exit 1; }

# [MODIFIED] Enhanced failure dump function to include ArgoCD diagnostics
failure_dump() {
    echo -e "\n\033[1;33m--- CAPTURING FAILURE STATE DUMP ---\033[0m" >&2
    if [ -f ./temp.sh ]; then
        chmod +x ./temp.sh
        ./temp.sh >&2
    else
        echo "WARNING: temp.sh not found. Skipping deep dive diagnostics." >&2
    fi
}

# --- [SECTION 3: MAIN EXECUTION LOGIC] ---
main() {
    if [[ $EUID -ne 0 ]]; then echo "FATAL ERROR: This script must be run as root." >&2; exit 1; fi
    touch "${LOG_FILE}" &>/dev/null || { echo "FATAL ERROR: Cannot write to log file at ${LOG_FILE}." >&2; exit 1; }
    exec &> >(tee -a "$LOG_FILE")
    local step_counter=0
    trap 'failure_dump; log_error_and_exit "Script exited due to an error in STEP ${step_counter}."' ERR

    log_info "Deployment Installer (v3.6 - Local) initiated. Full log: ${LOG_FILE}"

    # --- PHASE 1: PREPARATION & DEEP-CLEAN ---
    step_counter=$((step_counter + 1)); log_step $step_counter "System Deep Cleanup"
    log_info "Performing a comprehensive cleanup..."
    set -x
    if systemctl list-units --type=service --all | grep -q "k3s.service"; then systemctl stop k3s.service || true; systemctl disable k3s.service || true; fi
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
    if [ -f /opt/etcd/docker-compose.yml ]; then (cd /opt/etcd && docker-compose --project-name "${ETCD_PROJECT_NAME}" down --rmi all --volumes --remove-orphans) || echo "ETCD compose down failed."; fi
    rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /opt/etcd /tmp/k3s-*
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env
    systemctl daemon-reload
    journalctl --rotate && journalctl --vacuum-time=1s && journalctl -u k3s --vacuum-time=1s || true
    set +x
    log_success "System has been cleaned."

    # --- PHASE 2: CORE DEPENDENCIES DEPLOYMENT & VERIFICATION ---
    step_counter=$((step_counter + 1)); log_step $step_counter "Deploy and Verify External ETCD"
    log_info "Deploying ETCD via Docker Compose."
    mkdir -p /opt/etcd/data && chown -R 1001:1001 /opt/etcd/data
cat > /opt/etcd/docker-compose.yml << EOF
version: "3.8"
services:
  etcd: {image: bitnami/etcd:3.5.9, container_name: ${ETCD_CONTAINER_NAME}, restart: "no", ports: ["127.0.0.1:2379:2379"], volumes: ["/opt/etcd/data:/bitnami/etcd"], environment: [ALLOW_NONE_AUTHENTICATION=yes, ETCD_ADVERTISE_CLIENT_URLS=http://127.0.0.1:2379]}
EOF
    (cd /opt/etcd && docker-compose --project-name "${ETCD_PROJECT_NAME}" up -d)
    log_success "ETCD docker-compose command executed."
    log_info "Verifying ETCD health..."
    local etcd_attempts=0; local max_etcd_attempts=12
    until docker exec ${ETCD_CONTAINER_NAME} etcdctl endpoint health | grep -q 'is healthy'; do
        etcd_attempts=$((etcd_attempts + 1))
        if [ "${etcd_attempts}" -gt "${max_etcd_attempts}" ]; then log_error_and_exit "ETCD failed to become healthy."; fi
        log_info "Waiting for ETCD... (attempt ${etcd_attempts}/${max_etcd_attempts})"; sleep 5
    done
    log_success "External ETCD is running and healthy."

    # --- PHASE 3: K3S CUSTOM INSTALLATION & FIX ---
    step_counter=$((step_counter + 1)); log_step $step_counter "K3s Custom Installation"
    local k3s_exec_args="server --datastore-endpoint=http://127.0.0.1:2379 --tls-san=${API_SERVER_FQDN} --tls-san=${VPS_IP} --disable=traefik --disable=servicelb --disable-cloud-controller --flannel-iface=eth0 --selinux=false"
    log_info "Installing K3s with exec arguments: ${k3s_exec_args}"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" K3S_TOKEN="${K3S_CLUSTER_TOKEN}" INSTALL_K3S_EXEC="${k3s_exec_args}" sh -
    log_success "K3s installation script has been executed."
    log_info "Verifying K3s systemd service is active..."
    local k3s_service_attempts=0; local max_k3s_service_attempts=12
    until systemctl is-active --quiet k3s.service; do
        k3s_service_attempts=$((k3s_service_attempts + 1))
        if [ "${k3s_service_attempts}" -gt "${max_k3s_service_attempts}" ]; then log_error_and_exit "K3s service failed to become active."; fi
        log_info "Waiting for K3s service... (attempt ${k3s_service_attempts}/${max_k3s_service_attempts})"; sleep 5
    done
    log_success "K3s systemd service is active."

    # --- PHASE 4: IN-DEPTH KUBERNETES CLUSTER HEALTH CHECK ---
    step_counter=$((step_counter + 1)); log_step $step_counter "Cluster Health Verification"
    log_info "Configuring local kubeconfig..."
    mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
    local raw_kubeconfig; raw_kubeconfig=$(cat /etc/rancher/k3s/k3s.yaml)
    echo "${raw_kubeconfig}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/" | sed "s/default/personal-cluster/" > "${KUBECONFIG_PATH}"
    chmod 600 "${KUBECONFIG_PATH}"; export KUBECONFIG="${KUBECONFIG_PATH}"
    log_success "Local kubeconfig configured."
    log_info "[Health Check 1/3] Waiting for API server..."
    kubectl version --request-timeout=30s
    log_success "API server is responsive."
    log_info "[Health Check 2/3] Verifying node is Ready and Schedulable..."
    local node_attempts=0; local max_node_attempts=12
    until kubectl get nodes --no-headers=true 2>/dev/null | grep -q "."; do
        node_attempts=$((node_attempts + 1))
        if [ "${node_attempts}" -gt "${max_node_attempts}" ]; then log_error_and_exit "Timed out waiting for Node resource."; fi
        log_info "Node not found, retrying... (${node_attempts}/${max_node_attempts})"; sleep 5
    done
    kubectl wait --for=condition=Ready node --all --timeout=5m
    local node_name; node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    if kubectl get node "${node_name}" -o jsonpath='{.spec.taints[?(@.effect=="NoSchedule")]}' | grep -q "NoSchedule"; then
        log_error_and_exit "Node '${node_name}' has a 'NoSchedule' taint."
    fi
    log_success "Node is Ready and Schedulable."
    log_info "[Health Check 3/3] Verifying critical addons..."
    kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=5m
    kubectl wait --for=condition=Available deployment/local-path-provisioner -n kube-system --timeout=5m
    log_success "Cluster core components are fully operational."

    # --- PHASE 5: GITOPS BOOTSTRAP & APPLICATION DEPLOYMENT ---
    step_counter=$((step_counter + 1)); log_step $step_counter "GitOps Bootstrap (ArgoCD)"
    log_info "Installing ArgoCD via Helm..."
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || helm repo update
    helm upgrade --install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" -n argocd --create-namespace --set server.service.type=ClusterIP --wait --timeout=15m
    log_success "ArgoCD Helm chart installed."
    log_info "Applying root Application..."
    # Note: ArgoCD CLI is not a prerequisite for the script, so we use kubectl
    if ! command -v argocd &> /dev/null; then
        log_info "argocd CLI not found. You may want to install it for easier debugging."
    fi
    kubectl apply -f kubernetes/bootstrap/root.yaml
    log_success "Root ArgoCD Application applied."

    # --- FINAL VERIFICATION ---
    step_counter=$((step_counter + 1)); log_step $step_counter "Final End-to-End Verification"
    log_info "Waiting for all ArgoCD-managed applications to become Healthy & Synced..."
    kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application --all -n argocd --timeout=15m
    kubectl wait --for=jsonpath='{.status.sync.status}'=Synced application --all -n argocd --timeout=15m
    log_success "All ArgoCD applications are Healthy and Synced."
    # ... The rest of the verification steps ...
    log_info "Verifying Traefik is running and listening on host ports..."
    kubectl rollout status daemonset/traefik -n traefik --timeout=5m
    if ! ss -tlpn | grep -q ':443'; then log_error_and_exit "Traefik is not listening on host port 443."; fi
    log_success "Traefik is running and listening on host ports."
    log_info "Verifying ClusterIssuer is ready..."
    kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m
    log_success "ClusterIssuer 'cloudflare-staging' is Ready."
    log_info "Verifying ArgoCD Ingress certificate has been issued..."
    kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=5m
    log_success "Certificate for ArgoCD has been successfully issued."

    # --- DEPLOYMENT COMPLETE ---
    trap - ERR
    local argocd_password; argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo -e "\n\n\033[1;32m##############################################################################\033[0m"; echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"; echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and managed by ArgoCD."; echo -e "\n\033[1;33mArgoCD Access Details:\033[0m"; echo -e "  UI:      \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (accept the staging certificate)"; echo -e "  User:    \033[1;36m${ARGOCD_ADMIN_USER}\033[0m"; echo -e "  Password:\033[1;36m ${argocd_password}\033[0m"
    echo -e "\nTo log in via CLI:"; echo -e "  \033[0;35margocd login ${ARGOCD_FQDN} --username ${ARGOCD_ADMIN_USER} --password '${argocd_password}' --insecure\033[0m"
}
main "$@"