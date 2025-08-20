#!/usr/bin/env bash

# ==============================================================================
#
# PERSONAL CLUSTER DEPLOYMENT INSTALLER (v5.5 - Corrected DaemonSet Validation)
#
# ==============================================================================
#
#   VERSION 5.5 CHANGE LOG:
#   - FINAL VALIDATION FIX: The previous script failed because 'kubectl rollout status'
#     cannot be used on a DaemonSet with an 'OnDelete' update strategy.
#   - ROBUST DAEMONSET VERIFICATION: Replaced the failing command with a robust
#     'kubectl wait' command. It now correctly waits for the number of ready
#     pods in the DaemonSet to match the number of desired pods, which is the
#     proper way to verify DaemonSet readiness regardless of its update strategy.
#
# ==============================================================================

set -eo pipefail

# --- [SECTION 1: CONFIGURATION VARIABLES] ---
readonly VPS_IP="172.245.187.113"
readonly DOMAIN_NAME="gglohh.top"
readonly SITE_CODE="core01"
readonly ENVIRONMENT="prod"
readonly K3S_VERSION="v1.33.3+k3s1"
readonly K3S_CLUSTER_TOKEN="admin"
readonly ETCD_PROJECT_NAME="personal-cluster-etcd"
readonly ETCD_CONTAINER_NAME="core-etcd"
readonly GITOPS_REPO_URL="https://github.com/GgYu01/personal-cluster.git"
readonly ARGOCD_CHART_VERSION="8.2.7"
readonly ARGOCD_ADMIN_USER="admin"

# --- [SECTION 2: SCRIPT-DERIVED VARIABLES & HELPERS] ---
readonly API_SERVER_FQDN="api.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly ARGOCD_FQDN="argocd.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
readonly KUBECONFIG_PATH="${HOME}/.kube/config"
readonly LOG_FILE_NAME="deployment-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_FILE="$(pwd)/${LOG_FILE_NAME}"

log_step() {
    echo -e "\n\n\033[1;34m# ============================================================================== #\033[0m"
    echo -e "\033[1;34m# STEP ${1}: ${2} (Timestamp: $(date -u --iso-8601=seconds))\033[0m"
    echo -e "\033[1;34m# ============================================================================== #\033[0m\n"
}
log_info() { echo "--> INFO: $1"; }
log_warn() { echo -e "\033[1;33m⚠️  WARN: $1\033[0m"; }
log_success() { echo -e "\033[1;32m✅ SUCCESS:\033[0m $1"; }
log_error_and_exit() {
    echo -e "\n\033[1;31m❌ FATAL ERROR:\033[0m $1" >&2
    echo -e "\033[1;31mDeployment failed. See ${LOG_FILE} for full details.\033[0m" >&2
    exit 1
}

failure_dump() {
    echo -e "\n\033[1;33m--- CAPTURING FAILURE STATE DUMP ---\033[0m" >&2
    log_info "Dumping last 500 lines of K3s journal..."
    journalctl -u k3s.service --no-pager -n 500 -b >> "${LOG_FILE}"
    
    if [ -f "${KUBECONFIG_PATH}" ]; then
        export KUBECONFIG="${KUBECONFIG_PATH}"
        log_info "Kubeconfig found. Dumping cluster state..."
        log_info "Listing all namespaces and their labels..."
        kubectl get namespaces --show-labels >> "${LOG_FILE}" 2>&1 || true
        log_info "Describing all pods in all namespaces..."
        kubectl describe pods -A >> "${LOG_FILE}" 2>&1 || true
        log_info "Describing all ArgoCD Applications..."
        kubectl describe applications -n argocd >> "${LOG_FILE}" 2>&1 || true
    else
        log_warn "Kubeconfig not found. Skipping Kubernetes API state dump."
    fi
}

# --- [SECTION 3: DEPLOYMENT FUNCTIONS] ---

perform_system_cleanup() {
    log_info "Performing a comprehensive cleanup of K3s and ETCD..."
    set -x
    if systemctl list-units --type=service --all | grep -q "k3s.service"; then
        log_info "Stopping and disabling existing K3s service."
        systemctl stop k3s.service &>/dev/null || true
        systemctl disable k3s.service &>/dev/null || true
    fi
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        log_info "Executing k3s-uninstall.sh script."
        /usr/local/bin/k3s-uninstall.sh &>/dev/null
    fi
    if docker ps -a --format '{{.Names}}' | grep -q "^${ETCD_CONTAINER_NAME}$"; then
        log_info "Stopping and removing ETCD container."
        docker stop "${ETCD_CONTAINER_NAME}" &>/dev/null || true
        docker rm "${ETCD_CONTAINER_NAME}" &>/dev/null || true
    fi
    log_info "Purging K3s and ETCD data directories."
    rm -rf /opt/etcd /etc/rancher /var/lib/rancher /var/lib/kubelet /tmp/k3s-*
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env
    log_info "Reloading systemd and cleaning journal."
    systemctl daemon-reload
    journalctl --rotate && journalctl --vacuum-time=1s && journalctl -u k3s --vacuum-time=1s &>/dev/null || true
    set +x
    log_success "System has been cleaned."
}

prepare_k3s_config() {
    log_info "Creating K3s admission control configuration file to globally set Pod Security Standards to 'privileged'."
    mkdir -p /etc/rancher/k3s
    cat > /etc/rancher/k3s/admission-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1beta1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "privileged"
      audit-version: "latest"
      warn: "privileged"
      warn-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces: []
EOF
    log_success "K3s admission-config.yaml created."
}

install_and_verify_k3s() {
    local max_attempts=3
    for attempt in $(seq 1 ${max_attempts}); do
        log_info "Starting K3s installation, attempt ${attempt}/${max_attempts}..."
        
        local k3s_exec_args="server \
            --cluster-init \
            --datastore-endpoint=http://127.0.0.1:2379 \
            --tls-san=${API_SERVER_FQDN} \
            --tls-san=${VPS_IP} \
            --disable=traefik \
            --disable=servicelb \
            --disable-cloud-controller \
            --flannel-iface=eth0 \
            --selinux=false \
            --kubelet-arg=fail-swap-on=false \
            --kube-apiserver-arg=admission-control-config-file=/etc/rancher/k3s/admission-config.yaml"
            
        log_info "Installing K3s with exec arguments: ${k3s_exec_args}"
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" K3S_TOKEN="${K3S_CLUSTER_TOKEN}" INSTALL_K3S_EXEC="${k3s_exec_args}" sh -

        log_info "Starting deep verification of K3s cluster..."
        if verify_k3s_health; then
            log_success "K3s cluster is healthy and fully initialized on attempt ${attempt}."
            return 0
        else
            log_warn "K3s verification failed on attempt ${attempt}. Capturing journal logs before cleanup..."
            journalctl -u k3s.service --no-pager -n 200 -b >> "${LOG_FILE}"
            log_warn "Cleaning up for next attempt..."
            if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
                /usr/local/bin/k3s-uninstall.sh &>/dev/null
            fi
            sleep 10
        fi
    done
    log_error_and_exit "K3s installation failed to become healthy after ${max_attempts} attempts."
}

verify_k3s_health() {
    log_info "[Verification 1/6] Waiting for K3s service to become active..."
    for i in {1..15}; do if systemctl is-active --quiet k3s.service; then log_success "K3s service is active."; break; fi; sleep 4; done
    if ! systemctl is-active --quiet k3s.service; then log_warn "K3s service failed to activate."; return 1; fi

    log_info "[Verification 2/6] Waiting for kubeconfig file..."
    for i in {1..10}; do if [ -f /etc/rancher/k3s/k3s.yaml ]; then log_success "Kubeconfig found."; break; fi; sleep 3; done
    if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then log_warn "Kubeconfig file not created in time."; return 1; fi

    mkdir -p "$(dirname "${KUBECONFIG_PATH}")"
    local raw_kubeconfig; raw_kubeconfig=$(cat /etc/rancher/k3s/k3s.yaml)
    echo "${raw_kubeconfig}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/" | sed "s/default/personal-cluster/" > "${KUBECONFIG_PATH}"
    chmod 600 "${KUBECONFIG_PATH}"; export KUBECONFIG="${KUBECONFIG_PATH}"

    log_info "[Verification 3/6] Waiting for 'kube-system' namespace to be created..."
    if ! kubectl wait --for=jsonpath='{.metadata.name}'=kube-system namespace/kube-system --timeout=2m; then
        log_warn "Timed out waiting for 'kube-system' namespace. This is a critical initialization failure."
        return 1
    fi
    log_success "'kube-system' namespace is present."
    
    log_info "[Verification 4/6] Waiting for 'default' namespace to be created..."
    if ! kubectl wait --for=jsonpath='{.metadata.name}'=default namespace/default --timeout=1m; then
        log_warn "Timed out waiting for 'default' namespace."
        return 1
    fi
    log_success "'default' namespace is present."

    log_info "[Verification 5/6] Waiting for node object to appear in API..."
    local node_appeared=false
    for i in {1..40}; do # Timeout approx 2 minutes (40 * 3s)
        if [[ -n "$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)" ]]; then
            log_success "Node object is registered in the API server."
            node_appeared=true
            break
        fi
        log_info "Waiting for node object registration... (attempt $i/40)"
        sleep 3
    done
    if ! ${node_appeared}; then
        log_warn "Timed out waiting for any node object to be registered."
        return 1
    fi

    log_info "[Verification 6/6] Waiting for node to become Ready and Schedulable..."
    if ! kubectl wait --for=condition=Ready node --all --timeout=5m; then
        log_warn "Node did not become Ready in time."
        return 1
    fi
    log_success "Node is Ready and Schedulable."

    return 0
}

# --- [SECTION 4: MAIN EXECUTION LOGIC] ---
main() {
    if [[ $EUID -ne 0 ]]; then echo "FATAL ERROR: This script must be run as root." >&2; exit 1; fi
    touch "${LOG_FILE}" &>/dev/null || { echo "FATAL ERROR: Cannot write to log file at ${LOG_FILE}." >&2; exit 1; }
    exec &> >(tee -a "$LOG_FILE")
    local step_counter=0
    trap 'failure_dump; log_error_and_exit "Script exited due to an error in STEP ${step_counter}."' ERR

    log_info "Deployment Installer (v5.5 - Corrected DaemonSet Validation) initiated. Full log: ${LOG_FILE}"

    step_counter=1; log_step $step_counter "System Deep Cleanup"
    perform_system_cleanup

    step_counter=2; log_step $step_counter "Deploy and Verify External ETCD"
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

    step_counter=3; log_step $step_counter "Prepare K3s Configuration"
    prepare_k3s_config

    step_counter=4; log_step $step_counter "K3s Robust Installation and Verification"
    install_and_verify_k3s

    step_counter=5; log_step $step_counter "Cluster Addons Health Verification"
    log_info "Verifying critical addons are available..."
    kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=5m
    kubectl wait --for=condition=Available deployment/local-path-provisioner -n kube-system --timeout=5m
    log_success "Cluster core components are fully operational."

    step_counter=6; log_step $step_counter "GitOps Bootstrap (ArgoCD)"
    log_info "Installing ArgoCD via Helm..."
    helm repo add argo https://argoproj.github.io/argo-helm &>/dev/null || helm repo update
    helm upgrade --install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" -n argocd --create-namespace --set server.service.type=ClusterIP --wait --timeout=15m
    log_success "ArgoCD Helm chart installed and its pods are ready."

    step_counter=7; log_step $step_counter "Bootstrap Cert-Manager"
    log_info "Applying the Cert-Manager ArgoCD Application..."
    kubectl apply -f kubernetes/applications/cert-manager.yaml
    log_info "Waiting for Cert-Manager Application to sync and become healthy..."
    kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application/cert-manager -n argocd --timeout=5m
    kubectl wait --for=jsonpath='{.status.sync.status}'=Synced application/cert-manager -n argocd --timeout=5m
    log_info "Performing deep validation for Cert-Manager..."
    kubectl wait --for=condition=Established crd/clusterissuers.cert-manager.io --timeout=2m
    kubectl wait --for=condition=Available deployment -n cert-manager --all --timeout=5m
    log_success "Cert-Manager is fully deployed and operational."

    step_counter=8; log_step $step_counter "Bootstrap Traefik"
    log_info "Applying the Traefik ArgoCD Application..."
    kubectl apply -f kubernetes/applications/traefik.yaml
    log_info "Waiting for Traefik Application to sync and become healthy..."
    kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application/traefik -n argocd --timeout=5m
    kubectl wait --for=jsonpath='{.status.sync.status}'=Synced application/traefik -n argocd --timeout=5m
    log_info "Performing deep validation for Traefik..."
    kubectl wait --for=condition=Established crd/ingressroutes.traefik.io --timeout=2m
    
    # --- [START OF CORRECTION] ---
    # Replaced 'rollout status' with a 'wait' command that is compatible with DaemonSets.
    # This command waits until the number of ready pods matches the desired number of pods.
    log_info "Waiting for Traefik DaemonSet to be fully ready..."
    kubectl wait --for=jsonpath='{.status.numberReady}'=$(kubectl get daemonset traefik -n traefik -o jsonpath='{.status.desiredNumberScheduled}') daemonset/traefik -n traefik --timeout=5m
    # --- [END OF CORRECTION] ---
    
    log_success "Traefik is fully deployed and operational."
    
    step_counter=9; log_step $step_counter "Bootstrap Core Manifests"
    log_info "Applying the Core Manifests ArgoCD Application..."
    kubectl apply -f kubernetes/applications/manifests.yaml
    log_info "Waiting for Core Manifests Application to sync and become healthy..."
    kubectl wait --for=jsonpath='{.status.health.status}'=Healthy application/core-manifests -n argocd --timeout=5m
    kubectl wait --for=jsonpath='{.status.sync.status}'=Synced application/core-manifests -n argocd --timeout=5m
    log_success "Core manifests are synced."

    step_counter=10; log_step $step_counter "Final End-to-End Verification"
    log_info "Verifying Traefik is listening on host ports..."
    if ! ss -tlpn | grep -q ':443'; then log_error_and_exit "Traefik is not listening on host port 443."; fi
    log_success "Traefik is confirmed to be listening on host ports."
    log_info "Verifying ClusterIssuer is ready..."
    kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m
    log_success "ClusterIssuer 'cloudflare-staging' is Ready."
    log_info "Verifying ArgoCD Ingress certificate has been issued..."
    kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=5m
    log_success "Certificate for ArgoCD has been successfully issued."

    trap - ERR
    local argocd_password; argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo -e "\n\n\033[1;32m##############################################################################\033[0m"
    echo -e "\033[1;32m#          ✅ DEPLOYMENT COMPLETED SUCCESSFULLY ✅                         #\033[0m"
    echo -e "\033[1;32m##############################################################################\033[0m"
    echo -e "\nYour personal cluster is ready and managed by ArgoCD."
    echo -e "\n\033[1;33mArgoCD Access Details:\033[0m"
    echo -e "  UI:      \033[1;36mhttps://${ARGOCD_FQDN}\033[0m (accept the staging certificate)"
    echo -e "  User:    \033[1;36m${ARGOCD_ADMIN_USER}\033[0m"
    echo -e "  Password:\033[1;36m ${argocd_password}\033[0m"
    echo -e "\nTo log in via CLI:"
    echo -e "  \033[0;35margocd login ${ARGOCD_FQDN} --username ${ARGOCD_ADMIN_USER} --password '${argocd_password}' --insecure\033[0m"
}

# --- [SECTION 5: SCRIPT ENTRYPOINT] ---
main "$@"