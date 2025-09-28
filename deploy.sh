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

# --- ACME & DNS (Cloudflare) ---
# NOTE: Hard-coded, insecure by design, as requested
readonly ACME_EMAIL="1405630484@qq.com"
readonly CF_API_TOKEN="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
readonly WILDCARD_FQDN="*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"   # *.core01.prod.gglohh.top
readonly CF_PROXIED="false"

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
readonly PORTAL_FQDN="portal.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"  # portal.core01.prod.gglohh.top
readonly KUBELET_CONFIG_PATH="/etc/rancher/k3s/kubelet.config"

# --- [START OF PASSWORD FIX] ---
# Statically define the bcrypt hash for the password 'password'.
# This avoids re-calculating it on every run and makes the script's intent clearer.
readonly ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$Xx3c/ILSzwZfp2wHhoPxFOwH4yFp3MepBtoZpR2JgTsPaG6dz1EYS'
# --- [END OF PASSWORD FIX] ---

# [NEW] One-shot diagnostics flag to avoid duplicate heavy logs
K3S_DIAG_DONE=0

# [NEW] K3s journal anchor; collect logs only since this timestamp
K3S_JOURNAL_ANCHOR=""

# --- [NEW - SECTION 2.1: Cloudflare DNS Helpers] --- 
# Purpose: Manage wildcard A record state-driven via CF API (idempotent, non-interactive). 
cf_api() { 
  # $1: method, $2: path, $3: data (optional) 
  local method="$1"; local path="$2"; local data="${3:-}" 
  local url="https://api.cloudflare.com/client/v4${path}"
  if [[ -n "$data" ]]; then
    curl -sS -X "${method}" "${url}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json" \
      --data-raw "${data}"
  else
    curl -sS -X "${method}" "${url}" \
      -H "Authorization: Bearer ${CF_API_TOKEN}" \
      -H "Content-Type: application/json"
  fi
}

wait_apiserver_ready() { 
  # $1 timeout seconds (default 180), $2 interval seconds (default 5) 
  local timeout_s="${1:-180}" 
  local interval_s="${2:-5}" 
  log_info "Checking Kubernetes apiserver readiness (/readyz) with timeout ${timeout_s}s..." 
  if ! timeout "${timeout_s}s" bash -lc \
    'until kubectl --request-timeout=10s get --raw=/readyz >/dev/null 2>&1; do echo "    ...apiserver not ready yet"; sleep '"${interval_s}"'; done'; then
    log_error_and_exit "Kubernetes apiserver is not ready within ${timeout_s}s." 
  fi
  log_success "Kubernetes apiserver reports Ready." 
}

ensure_cloudflare_wildcard_a() {
  # Non-interactive, state-driven; creates or updates wildcard A only when needed.
  log_step 0 "Ensure Cloudflare wildcard DNS"
  local zone_name="${DOMAIN_NAME}"
  local sub_wildcard="*.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"

  log_info "Resolving Cloudflare Zone ID for ${zone_name} ..."
  local zone_resp; zone_resp=$(cf_api GET "/zones?name=${zone_name}")
  local zone_id; zone_id=$(echo "${zone_resp}" | jq -r '.result[0].id')
  if [[ -z "${zone_id}" || "${zone_id}" == "null" ]]; then
    log_error_and_exit "Cloudflare zone '${zone_name}' not found."
  fi
  log_success "Cloudflare Zone ID acquired: ${zone_id}"

  log_info "Checking existing DNS record for ${sub_wildcard} (type A) ..."
  # URL-encode "*." as %2A.
  local rec_resp; rec_resp=$(cf_api GET "/zones/${zone_id}/dns_records?type=A&name=*.$SITE_CODE.$ENVIRONMENT.$DOMAIN_NAME") 
  local rec_id; rec_id=$(echo "${rec_resp}" | jq -r '.result[0].id // empty') 
  local rec_ip; rec_ip=$(echo "${rec_resp}" | jq -r '.result[0].content // empty')

  if [[ -n "${rec_id}" ]]; then
    if [[ "${rec_ip}" == "${VPS_IP}" ]]; then
      log_success "Wildcard A already correct: ${sub_wildcard} -> ${VPS_IP} (no action)." 
    else
      log_info "Updating wildcard A to ${VPS_IP} ..." 
      local payload; payload=$(jq -nc --arg name "${sub_wildcard}" --arg ip "${VPS_IP}" --argjson proxied ${CF_PROXIED} \
        '{type:"A", name:$name, content:$ip, ttl:1, proxied:$proxied}')
      local up_resp; up_resp=$(cf_api PUT "/zones/${zone_id}/dns_records/${rec_id}" "${payload}")
      if [[ "$(echo "${up_resp}" | jq -r '.success')" != "true" ]]; then
        echo "${up_resp}" | sed 's/^/CF-ERR: /g'
        log_error_and_exit "Failed to update wildcard A record."
      fi
      log_success "Wildcard A updated: ${sub_wildcard} -> ${VPS_IP}"
    fi
  else
    log_info "Creating wildcard A ${sub_wildcard} -> ${VPS_IP} ..."
    local payload; payload=$(jq -nc --arg name "${sub_wildcard}" --arg ip "${VPS_IP}" --argjson proxied ${CF_PROXIED} \
      '{type:"A", name:$name, content:$ip, ttl:1, proxied:$proxied}')
    local cr_resp; cr_resp=$(cf_api POST "/zones/${zone_id}/dns_records" "${payload}")
    if [[ "$(echo "${cr_resp}" | jq -r '.success')" != "true" ]]; then
      echo "${cr_resp}" | sed 's/^/CF-ERR: /g'
      log_error_and_exit "Failed to create wildcard A record."
    fi
    log_success "Wildcard A created: ${sub_wildcard} -> ${VPS_IP}"
  fi

  log_info "Verifying public resolution via 1.1.1.1 ..."
  local probe_fqdn="test.${SITE_CODE}.${ENVIRONMENT}.${DOMAIN_NAME}"
  if ! timeout 60 bash -lc "until dig +short @1.1.1.1 ${probe_fqdn} A | grep -q '^${VPS_IP}\$'; do echo '    ...waiting DNS...'; sleep 5; done"; then
    log_warn "Public resolution for ${probe_fqdn} did not return ${VPS_IP} within timeout."
  else
    log_success "Public DNS resolution OK for wildcard subdomain."
  fi
}

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
    local note_every="${5:-30}"  # print a note at most every N seconds

    log_info "Verifying: ${description} (Timeout: ${timeout_seconds}s)" 
    local start_ts now_ts elapsed next_note
    start_ts=$(date +%s)
    next_note=$note_every

    while true; do
        if bash -lc "${cmd}" &>/dev/null; then
            log_success "Verified: ${description}."
            return 0
        fi
        now_ts=$(date +%s)
        elapsed=$(( now_ts - start_ts ))
        if (( elapsed >= timeout_seconds )); then
            log_warn "Condition '${description}' was NOT met within the timeout period."
            return 1
        fi
        if (( elapsed >= next_note )); then
            echo "    ...waiting '${description}' (elapsed: ${elapsed}s)"
            next_note=$(( next_note + note_every ))
        fi
        sleep "${interval_seconds}"
    done
}

# Single-shot job logs collector for helm jobs
print_job_pod_logs() {
    # $1: namespace, $2: job name
    local ns="$1"; local job="$2"
    echo "==== [DIAG] Logs for Job ${ns}/${job} ===="
    local pods
    pods=$(kubectl -n "${ns}" get pods --selector=job-name="${job}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    if [[ -z "${pods}" ]]; then
        echo "(no pods found for job ${job})"
        return 0
    fi
    for p in ${pods}; do
        echo "--- Pod: ${p} (containers) ---"
        kubectl -n "${ns}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true
        echo
        for c in $(kubectl -n "${ns}" get pod "${p}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null); do
            echo "----- Container: ${c} -----"
            kubectl -n "${ns}" logs "${p}" -c "${c}" --tail=500 2>/dev/null || true
        done
    done
}

# Wait helm install job to succeed; no early-exit on BackOff (controller may retry)
wait_helm_job_success() {
    # $1: namespace, $2: job name, $3: timeout seconds
    local ns="$1"; local job="$2"; local timeout_s="$3"
    log_info "Waiting Job ${ns}/${job} to succeed..."
    if ! timeout "${timeout_s}s" bash -lc "until [[ \$(kubectl -n ${ns} get job ${job} -o jsonpath='{.status.succeeded}' 2>/dev/null) == 1 ]]; do sleep 5; done"; then
        log_warn "Timeout waiting Job ${ns}/${job} to succeed."
        print_job_pod_logs "${ns}" "${job}"
        return 1
    fi
    log_success "Job ${ns}/${job} succeeded."
    return 0
}

# Wait all required Traefik CRDs available after traefik-crd job
wait_for_traefik_crds() {
    log_info "Waiting for Traefik CRDs to be established in API..."
    local crds=(
        ingressroutes.traefik.io
        ingressroutetcps.traefik.io
        ingressrouteudps.traefik.io
        middlewares.traefik.io
        traefikservices.traefik.io
        tlsoptions.traefik.io
        serverstransports.traefik.io
    )
    for c in "${crds[@]}"; do
        if ! run_with_retry "kubectl get crd ${c} >/dev/null 2>&1" "CRD ${c} present" 180 5; then
            log_error_and_exit "Required CRD ${c} not found after traefik-crd installation."
        fi
    done
    log_success "All Traefik CRDs are present."
}

# [New] Dump HelmChart & HelmChartConfig valuesContent once for high-value diagnostics
diagnose_traefik_values_merge() {
    echo "==== [DIAG] HelmChart kube-system/traefik (spec.valuesContent) ===="
    kubectl -n kube-system get helmchart traefik -o jsonpath='{.spec.valuesContent}' 2>/dev/null || true
    echo
    echo "==== [DIAG] HelmChartConfig kube-system/traefik (spec.valuesContent) ===="
    kubectl -n kube-system get helmchartconfig traefik -o jsonpath='{.spec.valuesContent}' 2>/dev/null || true
    echo
    echo "==== [DIAG] Traefik Service (full manifest) ===="
    kubectl -n kube-system get svc traefik -o yaml 2>/dev/null || true
}

# --- New: compact diagnostic for Traefik installation ---
diagnose_traefik_install() {
    # Single-shot diagnostics, no loops. Minimal but high-value.
    echo "==== [DIAG] kube-system basic resources ===="
    kubectl -n kube-system get deploy,po,svc,helmchart 2>/dev/null || true

    echo "==== [DIAG] helm-controller status ===="
    kubectl -n kube-system get deploy/helm-controller -o yaml 2>/dev/null || true
    kubectl -n kube-system logs deploy/helm-controller --tail=100 2>/dev/null || true

    echo "==== [DIAG] HelmChart traefik (if any) ===="
    kubectl -n kube-system get helmchart traefik -o yaml 2>/dev/null || true

    echo "==== [DIAG] Traefik deployment (if any) ===="
    kubectl -n kube-system get deploy/traefik -o yaml 2>/dev/null || true
    kubectl -n kube-system logs deploy/traefik --tail=200 2>/dev/null || true

    echo "==== [DIAG] Traefik service (if any) ===="
    kubectl -n kube-system get svc/traefik -o yaml 2>/dev/null || true

    echo "==== [DIAG] Recent kube-system events ===="
    kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -n 50 2>/dev/null || true
}

# [NEW] One-shot K3s failure diagnostics (deep, no loops, rate-limited by flag)
diagnose_k3s_failure() {
    # $1: stage hint, e.g., post-install | node-not-ready | installer-error
    local stage="${1:-unknown}"
    if [[ "${K3S_DIAG_DONE}" == "1" ]]; then
        log_info "K3s diagnostics already collected earlier; skip duplicate collection."
        return 0
    fi
    K3S_DIAG_DONE=1

    echo "==== [DIAG] K3s failure diagnostics (stage: ${stage}) ===="
    echo "--- [sysinfo] uname/date/os ---"
    uname -a || true
    (lsb_release -a 2>/dev/null || cat /etc/os-release 2>/dev/null || true)
    date -u || true

    echo "--- [resources] disk/memory ---"
    df -h || true
    free -m || true

    echo "--- [kernel params] ip_forward & bridge-nf ---"
    sysctl -e net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables 2>/dev/null || true

    echo "--- [ports] apiserver/kubelet/etcd listeners ---"
    ss -lntp 2>/dev/null | egrep '(:6443|:10250|:2379)' || true

    echo "--- [k3s binary & version] ---"
    command -v k3s 2>/dev/null || true
    k3s -v 2>/dev/null || true

    echo "--- [systemd k3s unit] show & files ---"
    systemctl show k3s.service -p FragmentPath,EnvironmentFile,ExecStart,ExecStartPre,ExecStartPost 2>/dev/null || true
    echo
    echo "----- /etc/systemd/system/k3s.service (head) -----"
    sed -n '1,160p' /etc/systemd/system/k3s.service 2>/dev/null || true
    echo
    echo "----- /etc/systemd/system/k3s.service.env -----"
    cat /etc/systemd/system/k3s.service.env 2>/dev/null || true

    echo "--- [k3s service status] ---"
    systemctl status k3s.service --no-pager 2>/dev/null || true

    echo "--- [journals] k3s (anchored, unique, last 200) ---"
    # Only logs since current run; de-duplicate identical lines; bound length
    local since_arg="${K3S_JOURNAL_ANCHOR:-"15 min ago"}"
    journalctl -u k3s.service --since "${since_arg}" --no-pager -o short-iso 2>/dev/null \
      | awk '!seen[$0]++' \
      | tail -n 200

    # Kubernetes-level diagnostics (if apiserver is reachable)
    if command -v kubectl >/dev/null 2>&1; then
      echo "--- [kube] nodes (wide) ---"
      kubectl get nodes -o wide 2>/dev/null || true

      local node_name
      node_name="$(hostname | tr '[:upper:]' '[:lower:]')"
      echo "--- [kube] node conditions (${node_name}) ---"
      kubectl get node "${node_name}" -o json 2>/dev/null | jq '.status.conditions // []' 2>/dev/null || true

      echo "--- [kube-system] pods (wide) ---"
      kubectl -n kube-system get pods -o wide 2>/dev/null || true

      echo "--- [kube-system] helm jobs logs (traefik) ---"
      # helm-install-traefik-crd
      if kubectl -n kube-system get job helm-install-traefik-crd >/dev/null 2>&1; then
        echo "----- logs: job/helm-install-traefik-crd (container: helm, tail: 120) -----"
        kubectl -n kube-system logs job/helm-install-traefik-crd -c helm --tail=120 2>/dev/null | awk '!seen[$0]++' || true
      fi
      # helm-install-traefik
      if kubectl -n kube-system get job helm-install-traefik >/dev/null 2>&1; then
        echo "----- logs: job/helm-install-traefik (container: helm, tail: 120) -----"
        kubectl -n kube-system logs job/helm-install-traefik -c helm --tail=120 2>/dev/null | awk '!seen[$0]++' || true
      fi

      echo "--- [kube-system] HelmChart/HelmChartConfig (traefik) ---"
      kubectl -n kube-system get helmchart traefik -o yaml 2>/dev/null | sed -n '1,200p' || true
      kubectl -n kube-system get helmchartconfig traefik -o yaml 2>/dev/null | sed -n '1,200p' || true

      echo "--- [kube-system] recent events (tail 60) ---"
      kubectl -n kube-system get events --sort-by=.lastTimestamp 2>/dev/null | tail -n 60 || true
    fi

    echo "--- [k3s generated files] ---"
    ls -l /etc/rancher/k3s /var/lib/rancher/k3s 2>/dev/null || true
    if [[ -f "${KUBECONFIG_PATH}" ]]; then
        echo "----- kubeconfig head -----"
        head -n 25 "${KUBECONFIG_PATH}" 2>/dev/null || true
    fi

    echo "--- [process list] k3s ---"
    ps -o pid,ppid,cmd -C k3s 2>/dev/null || pgrep -a k3s 2>/dev/null || true

    echo "==== [DIAG END] K3s failure diagnostics ===="
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
    # Keep non-k3s containerd paths intact to avoid breaking other Docker services
    rm -rf /var/lib/rancher/k3s /etc/rancher /var/lib/kubelet /run/flannel /tmp/k3s-*
    rm -rf "${ETCD_DATA_DIR}" 
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env "${KUBELET_CONFIG_PATH}" "${KUBECONFIG_PATH}" 
    rm -rf "${HOME}/.kube" 

    log_info "Reloading systemd and cleaning journals for k3s and docker..." 
    systemctl daemon-reload
    journalctl --rotate || true
    
    log_success "System cleanup complete."
}

function deploy_etcd() { 
    log_step 2 "Deploy and Verify External ETCD" 
    
    log_info "Preparing ETCD data directory with correct permissions for UID ${ETCD_CONTAINER_USER_ID}..." 
    mkdir -p "${ETCD_DATA_DIR}" 
    chown -R "${ETCD_CONTAINER_USER_ID}:${ETCD_CONTAINER_USER_ID}" "${ETCD_DATA_DIR}" 
    
    log_info "Deploying ETCD via Docker..." 
    docker run -d --restart unless-stopped \
      --name "${ETCD_CONTAINER_NAME}" \
      -p 127.0.0.1:2379:2379 \
      -v "${ETCD_DATA_DIR}":/bitnami/etcd/data \
      -e ETCD_NAME="${ETCD_CONTAINER_NAME}" \
      -e ETCD_ENABLE_V2="false" \
      -e ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379" \
      -e ETCD_ADVERTISE_CLIENT_URLS="http://127.0.0.1:2379" \
      -e ALLOW_NONE_AUTHENTICATION="yes" \
      bitnami/etcd:latest >/dev/null
      
    log_success "ETCD container started." 

    # Primary check: etcdctl v3 inside container (low-noise, rate-limited progress)
    log_info "Waiting for ETCD endpoint health via etcdctl (v3, in-container) ..."
    if ! run_with_retry "docker exec ${ETCD_CONTAINER_NAME} env ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 endpoint health" "ETCD to be healthy (etcdctl)" 180 3 30; then
        log_warn "Primary etcdctl health check did not pass within timeout. Trying HTTP /health as fallback..."

        # Fallback check: host-side HTTP /health (etcd exposes HTTP health for v3 when http listen is enabled)
        if ! run_with_retry "curl -fsS http://127.0.0.1:2379/health | grep -qi 'true\|healthy'" "ETCD HTTP /health endpoint reports healthy" 120 5 30; then
            # Diagnostics (one-shot, no loops)
            echo "==== [DIAG: etcdctl availability (in-container)] ===="
            docker exec "${ETCD_CONTAINER_NAME}" sh -lc 'command -v etcdctl >/dev/null 2>&1 && (etcdctl version || true) || echo "etcdctl not found"' 2>/dev/null || true
            echo
            echo "==== [DIAG: in-container ETCD_* environment] ===="
            docker exec "${ETCD_CONTAINER_NAME}" sh -lc 'env | grep -E "^ETCD_|^ALLOW_" | sort' 2>/dev/null || true
            echo
            echo "==== [DIAG: last 400 lines of etcd container logs] ===="
            docker logs --tail=400 "${ETCD_CONTAINER_NAME}" 2>/dev/null || true
            echo
            echo "==== [DIAG: docker inspect (ports, restart policy, state)] ===="
            docker inspect "${ETCD_CONTAINER_NAME}" | jq '.[0] | {Name: .Name, State: .State, HostConfig: {RestartPolicy: .HostConfig.RestartPolicy}, NetworkSettings: {Ports: .NetworkSettings.Ports}}' 2>/dev/null || true
            log_error_and_exit "ETCD deployment failed."
        fi
    fi

    log_success "ETCD endpoint is healthy."
}

function install_k3s() { 
    log_step 3 "Install and Verify K3S" 

    # Anchor K3s journal timestamp to avoid dumping historical logs
    K3S_JOURNAL_ANCHOR="$(date -u --iso-8601=seconds)"

    log_info "Preparing K3s manifest and configuration directories..." 
    mkdir -p /var/lib/rancher/k3s/server/manifests
    mkdir -p "$(dirname "${KUBELET_CONFIG_PATH}")" 

    log_info "Creating Traefik HelmChartConfig with CRD provider and frps (7000/TCP) entryPoint..." 
    cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml << 'EOF'
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
      kubernetesIngress:
        publishedService:
          enabled: true

    ports:
      web:
        port: 8000
        exposedPort: 80
      websecure:
        port: 8443
        exposedPort: 443
      frps:
        port: 7000
        expose:
          default: true
        exposedPort: 7000
        protocol: TCP

    additionalArguments:
      - "--entrypoints.websecure.http.tls=true"
EOF

    cat > "${KUBELET_CONFIG_PATH}" << EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF
    log_success "K3s customization manifests created." 

    log_info "Installing K3s ${K3S_VERSION}..."
    # Embedded etcd: use --cluster-init on the first (single) server; no external datastore flag
    local install_cmd="set -o pipefail; curl -sfL https://get.k3s.io \
      | INSTALL_K3S_VERSION='${K3S_VERSION}' K3S_TOKEN='${K3S_CLUSTER_TOKEN}' \
        sh -s - server \
          --cluster-init \
          --tls-san='${VPS_IP}' \
          --kubelet-arg='config=${KUBELET_CONFIG_PATH}'"
    if ! bash -lc "${install_cmd}"; then
        log_warn "K3s installer returned non-zero. Running diagnostics once..."
        diagnose_k3s_failure "installer-error"
        log_error_and_exit "K3s installer failed."
    fi
    log_success "K3s installation script finished." 

    # Gate immediately on systemd active state to catch early failures
    log_info "Checking k3s.service active state after install..."
    if ! systemctl is-active --quiet k3s; then
        log_warn "k3s.service is not active (failed). Running diagnostics once..."
        diagnose_k3s_failure "post-install"
        log_error_and_exit "K3s service failed to start."
    fi

    log_info "Setting up kubeconfig for user..." 
    mkdir -p "$(dirname "${USER_KUBECONFIG_PATH}")" 
    cp "${KUBECONFIG_PATH}" "${USER_KUBECONFIG_PATH}" 
    chown "$(id -u):$(id -g)" "${USER_KUBECONFIG_PATH}" 
    export KUBECONFIG="${USER_KUBECONFIG_PATH}" 

    log_info "Waiting for Node object to appear (Timeout: 180s)..."
    if ! timeout 180 bash -lc 'until kubectl get nodes --no-headers 2>/dev/null | grep -q .; do echo "    ...Node list empty, waiting..."; sleep 5; done'; then
      kubectl get nodes -o wide || true
      diagnose_k3s_failure "node-object-missing"
      log_error_and_exit "Node objects did not appear in time."
    fi

    # 再等 Node Ready（kubectl wait）
    log_info "Waiting for all Nodes to be Ready via kubectl wait (Timeout: 180s)..."
    if ! kubectl wait --for=condition=Ready node --all --timeout=180s 2>&1 | tee -a "${LOG_FILE}"; then
      kubectl get nodes -o wide || true
      diagnose_k3s_failure "node-not-ready"
      log_error_and_exit "K3s cluster verification failed."
    fi
    log_success "All nodes report Ready."

    # Wait for k3s HelmChart resources
    log_info "Waiting for HelmChart 'traefik' to appear..." 
    if ! run_with_retry "kubectl -n kube-system get helmchart traefik >/dev/null 2>&1" "HelmChart/traefik exists" 240 5; then
        log_error_and_exit "HelmChart 'traefik' not found; Traefik installation not started."
    fi
    log_success "HelmChart/traefik detected." 

    log_info "Waiting for job/helm-install-traefik-crd to succeed..." 
    if ! wait_helm_job_success "kube-system" "helm-install-traefik-crd" 360; then
        log_error_and_exit "job/helm-install-traefik-crd failed."
    fi
    wait_for_traefik_crds

    log_info "Waiting for job/helm-install-traefik to succeed..." 
    if ! wait_helm_job_success "kube-system" "helm-install-traefik" 600; then
        log_error_and_exit "job/helm-install-traefik failed."
    fi

    log_info "Waiting for Traefik Deployment to be created..." 
    if ! run_with_retry "kubectl -n kube-system get deploy traefik >/dev/null 2>&1" "Deployment/traefik exists" 240 5; then
        log_error_and_exit "Traefik Deployment not created."
    fi
    log_info "Waiting for Traefik Deployment rollout..." 
    if ! run_with_retry "kubectl -n kube-system rollout status deploy/traefik --timeout=90s" "Traefik Deployment rollout" 480 10; then
        log_error_and_exit "Traefik Deployment failed to roll out."
    fi
    log_success "Traefik Deployment is Ready." 

    log_info "Checking Service/traefik exposes required ports (80, 443, 7000)..."
    local ports_cmd="kubectl -n kube-system get svc traefik -o jsonpath='{.spec.ports[*].port}' | tr ' ' '\n' | sort -n | tr '\n' ' '"
    if ! run_with_retry "${ports_cmd} | grep -Eq '\b80\b' && ${ports_cmd} | grep -Eq '\b443\b' && ${ports_cmd} | grep -Eq '\b7000\b'" \
        "Service/traefik to expose 80,443,7000" 180 10; then
        echo "Observed ports: $(eval ${ports_cmd} 2>/dev/null || true)"
        diagnose_traefik_values_merge
        log_error_and_exit "Traefik Service does not expose required ports."
    fi
    log_success "Traefik Service exposes 80/443/7000."
}

# --- New: verify frps entryPoint & wildcard TLS readiness ---
function verify_frps_entrypoint_and_tls() {
    log_step 6 "Verify frps entryPoint listening and wildcard TLS readiness"

    # 1) Verify IngressRouteTCP exists and references entryPoint 'frps'
    if ! run_with_retry "kubectl -n frp-system get ingressroutetcp frps-tcp-ingress >/dev/null 2>&1" "IngressRouteTCP 'frps-tcp-ingress' present" 120 5; then
        log_info "Dumping IngressRouteTCP list in frp-system:"
        kubectl -n frp-system get ingressroutetcp -o yaml || true
        log_error_and_exit "IngressRouteTCP 'frps-tcp-ingress' not found."
    fi
    log_success "IngressRouteTCP 'frps-tcp-ingress' is present."

    # 2) Verify Traefik service exposes 7000 and external TCP is reachable
    #    This uses a TCP connect check against VPS_IP:7000
    local tcp_check_cmd="timeout 2 bash -lc '</dev/tcp/${VPS_IP}/7000' >/dev/null 2>&1"
    if ! run_with_retry "${tcp_check_cmd}" "External TCP connectivity to ${VPS_IP}:7000" 180 5; then
        log_info "Failed TCP connect to ${VPS_IP}:7000. Dumping diagnostics:"
        kubectl -n kube-system get svc traefik -o wide || true
        kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide || true
        kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --tail=100 || true
        log_warn "Possible external firewall or provider-level filtering on port 7000."
        log_error_and_exit "frps entryPoint is not externally reachable on ${VPS_IP}:7000."
    fi
    log_success "frps entryPoint is externally reachable on ${VPS_IP}:7000."

    # 3) Verify wildcard Certificate in frp-system namespace
    #    Name should match your manifest (e.g. wildcard-core01-prod-gglohh-top)
    local cert_name="wildcard-core01-prod-gglohh-top"
    if ! kubectl -n frp-system get certificate "${cert_name}" >/dev/null 2>&1; then
        log_warn "Certificate '${cert_name}' not found in namespace 'frp-system'. Skipping Ready wait."
        log_info "List certificates in frp-system for reference:"
        kubectl -n frp-system get certificate || true
    else
        if ! run_with_retry "kubectl -n frp-system wait --for=condition=Ready certificate/${cert_name} --timeout=100s" "Wildcard Certificate '${cert_name}' to be Ready" 320 10; then
            log_info "Certificate not Ready. Dumping certificate and cert-manager logs:"
            kubectl -n frp-system describe certificate "${cert_name}" || true
            kubectl -n cert-manager logs -l app.kubernetes.io/instance=cert-manager --all-containers --tail=100 || true
            log_error_and_exit "Wildcard certificate '${cert_name}' not Ready."
        fi
        log_success "Wildcard certificate '${cert_name}' is Ready."
    fi

    # 4) Verify TLS Secret exists for Traefik IngressRoute usage
    local tls_secret="wildcard-core01-prod-gglohh-top-tls"
    if ! run_with_retry "kubectl -n frp-system get secret ${tls_secret} >/dev/null 2>&1" "TLS Secret '${tls_secret}' present in frp-system" 120 5; then
        log_info "Dumping secrets in frp-system:"
        kubectl -n frp-system get secrets || true
        log_error_and_exit "TLS Secret '${tls_secret}' is missing in frp-system."
    fi
    log_success "TLS Secret '${tls_secret}' present in frp-system (for HTTPS on wildcard)."
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
    if ! run_with_retry "kubectl get application/argocd -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Argo CD to become Healthy and self-managed" 180; then
        log_info "Argo CD self-management sync failed. Dumping application status:"
        kubectl get application/argocd -n argocd -o yaml
        log_error_and_exit "Argo CD bootstrap failed at self-management step."
    fi

    log_success "Argo CD has been bootstrapped and is now self-managing via GitOps."
}

function deploy_applications() {
    log_step 5 "Deploy Core Applications via GitOps"

    # 1) 仅提交 cert-manager Application
    log_info "Applying cert-manager Application (only)..."
    kubectl apply -f kubernetes/apps/cert-manager-app.yaml

    # 2) API server 就绪门控，避免 Admission 注册过程的瞬时失败
    wait_apiserver_ready 180 5

    # 3) 等待 cert-manager 核心 Deployment 实际就绪（比直接看 Argo Application 更贴近事实）
    log_info "Waiting for cert-manager Deployments to become Available..."
    timeout 600 bash -lc 'until kubectl -n cert-manager get deploy cert-manager cert-manager-webhook >/dev/null 2>&1; do echo "    ...waiting for cert-manager deployments to appear"; sleep 5; done'
    if ! kubectl -n cert-manager rollout status deploy/cert-manager --timeout=7m; then
    kubectl -n cert-manager describe deploy cert-manager || true
    kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager --tail=200 || true
    log_error_and_exit "Deployment cert-manager failed to roll out."
    fi
    if ! kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=7m; then
    kubectl -n cert-manager describe deploy cert-manager-webhook || true
    kubectl -n cert-manager logs -l app.kubernetes.io/name=webhook --tail=200 || true
    log_error_and_exit "Deployment cert-manager-webhook failed to roll out."
    fi
    log_success "cert-manager core Deployments are Available."

    # 4) 再做一次 apiserver 就绪门控（webhook/CRD 安装后常见波动）
    wait_apiserver_ready 180 5

    # 5) 从 Argo 视角等待 cert-manager Application Healthy（延长超时以适应首次安装）
    log_info "Waiting for Cert-Manager application to become Healthy in Argo CD..."
    if ! run_with_retry "kubectl get application/cert-manager -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "Cert-Manager Argo CD App to be Healthy" 100 10; then
    kubectl get application/cert-manager -n argocd -o yaml || true
    kubectl -n cert-manager get pods -o wide || true
    kubectl -n cert-manager get events --sort-by=.lastTimestamp | tail -n 50 || true
    kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 50 || true
    log_error_and_exit "Cert-Manager deployment via Argo CD failed (not Healthy within timeout)."
    fi
    log_success "Cert-Manager application is Healthy in Argo CD."

    log_info "Applying remaining Applications (excluding n8n)..."
    # frps 独立管理
    kubectl apply -f kubernetes/apps/frps-app.yaml
    # core-manifests 仅包含 cluster-issuer
    kubectl apply -f kubernetes/apps/core-manifests-app.yaml
    # 新增两个静态 ingress 应用
    kubectl apply -f kubernetes/apps/argocd-ingress-app.yaml

    # 新增：provisioner 网关 Application
    kubectl apply -f kubernetes/apps/provisioner-app.yaml

    kubectl apply -f kubernetes/apps/authentik-ingress-static-app.yaml

    # 逐个等待 Healthy（放宽超时以适应首次签发/拉起）
    log_info "Waiting for core-manifests application to become Healthy..."
    if ! run_with_retry "kubectl get application/core-manifests -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "core-manifests Argo CD App to be Healthy" 600 10; then
    kubectl get application/core-manifests -n argocd -o yaml || true
    log_error_and_exit "core-manifests not Healthy."
    fi

    log_info "Waiting for argocd-ingress application to become Healthy..."
    if ! run_with_retry "kubectl get application/argocd-ingress -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "argocd-ingress Argo CD App to be Healthy" 600 10; then
    kubectl get application/argocd-ingress -n argocd -o yaml || true
    log_error_and_exit "argocd-ingress not Healthy."
    fi

    # 等待 provisioner Healthy（证书/Ingress 创建可能略慢，放宽超时）
    log_info "Waiting for provisioner application to become Healthy..."
    if ! run_with_retry "kubectl get application/provisioner -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "provisioner Argo CD App to be Healthy" 600 10; then
    kubectl get application/provisioner -n argocd -o yaml || true
    kubectl -n provisioner get pods -o wide || true
    kubectl -n provisioner get events --sort-by=.lastTimestamp | tail -n 50 || true
    log_error_and_exit "provisioner not Healthy."
    fi
    log_success "provisioner application is Healthy."

    log_info "Waiting for authentik-ingress-static application to become Healthy..."
    if ! run_with_retry "kubectl get application/authentik-ingress-static -n argocd -o jsonpath='{.status.health.status}' | grep -q 'Healthy'" "authentik-ingress-static Argo CD App to be Healthy" 600 10; then
    kubectl get application/authentik-ingress-static -n argocd -o yaml || true
    log_error_and_exit "authentik-ingress-static not Healthy."
    fi

    log_success "Remaining applications submitted and Healthy."
}

function final_verification() {
    log_step 6 "Final End-to-End Verification"
    wait_apiserver_ready 180 5

    log_info "Verifying ClusterIssuer 'cloudflare-staging' is ready..."
    if ! run_with_retry "kubectl wait --for=condition=Ready clusterissuer/cloudflare-staging --timeout=2m" "ClusterIssuer to be Ready" 120 10; then
        log_info "ClusterIssuer did not become ready. Dumping Cert-Manager logs:"
        kubectl logs -n cert-manager -l app.kubernetes.io/instance=cert-manager --all-containers
        log_error_and_exit "ClusterIssuer verification failed."
    fi

    log_info "Verifying ArgoCD IngressRoute certificate has been issued..."
    if ! run_with_retry "kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=5m" "Certificate to be Ready" 180 15; then
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

    log_info "Verifying Provisioner portal Certificate has been issued..."
    if ! run_with_retry "kubectl wait --for=condition=Ready certificate/portal-tls-staging -n provisioner --timeout=5m" "Portal Certificate to be Ready" 180 15; then
    kubectl -n provisioner describe certificate portal-tls-staging || true
    kubectl -n cert-manager logs -l app.kubernetes.io/instance=cert-manager --all-containers --tail=100 || true
    log_error_and_exit "Portal certificate issuance failed."
    fi

    # [ADD START] wait for provisioner gateway backend readiness and TLS secret presence
    log_info "Waiting for provisioner-gateway Deployment rollout..."
    if ! run_with_retry "kubectl -n provisioner rollout status deploy/provisioner-gateway --timeout=60s" "provisioner-gateway rollout to complete" 240 10; then
    kubectl -n provisioner describe deploy provisioner-gateway || true
    kubectl -n provisioner get pods -o wide || true
    log_error_and_exit "provisioner-gateway failed to roll out."
    fi

    log_info "Waiting for Service/provisioner-gateway endpoints to be populated..."
    if ! run_with_retry "kubectl -n provisioner get endpoints provisioner-gateway -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -E '.+'" "provisioner-gateway Endpoints to be Ready" 240 10; then
    kubectl -n provisioner get endpoints provisioner-gateway -o yaml || true
    log_error_and_exit "provisioner-gateway Endpoints not ready."
    fi

    log_info "Verifying TLS Secret 'portal-tls-staging' exists for Traefik..."
    if ! run_with_retry "kubectl -n provisioner get secret portal-tls-staging >/dev/null 2>&1" "Secret portal-tls-staging available" 180 10; then
    kubectl -n provisioner get secret || true
    log_error_and_exit "TLS Secret 'portal-tls-staging' is missing."
    fi

    # Give Traefik a short window to pick up the secret and router
    log_info "Allowing Traefik to resync TLS assets..."
    sleep 10
    # [ADD END]

    log_info "Performing reachability check on Portal URL: https://${PORTAL_FQDN}"
    # 以 200/3xx 为成功（echo-server 默认 200）
    if ! run_with_retry "curl -k -s -o /dev/null -w '%{http_code}' --resolve ${PORTAL_FQDN}:443:${VPS_IP} https://${PORTAL_FQDN}/ | egrep -q '^(200|30[12])$'" "Provisioner portal to be reachable (HTTP 200/30x)" 180 10; then
    kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --tail=120 || true
    kubectl -n provisioner logs deploy/provisioner-gateway --tail=200 || true
    log_error_and_exit "Portal end-to-end verification failed."
    fi
    log_success "Portal is reachable with valid TLS."

    # --- New: frps entryPoint + wildcard TLS verification ---
    verify_frps_entrypoint_and_tls
}

# --- [SECTION 4: MAIN EXECUTION] ---
main() { 
    # Pre-flight checks
    if [[ $EUID -ne 0 ]]; then log_error_and_exit "This script must be run as root."; fi
    if ! command -v docker &> /dev/null \vert{}\vert{} ! systemctl is-active --quiet docker; then log_error_and_exit "Docker is not installed or not running."; fi
    if ! command -v helm &> /dev/null; then log_error_and_exit "Helm is not installed. Please install Helm to proceed."; fi
    if ! command -v jq &> /dev/null; then log_error_and_exit "Command 'jq' is required but not found."; fi
    if ! command -v dig &> /dev/null; then log_error_and_exit "Command 'dig' is required but not found."; fi

    if [ ! -d "kubernetes/bootstrap" ] \vert{}\vert{} [ ! -d "kubernetes/apps" ]; then log_error_and_exit "Required directories 'kubernetes/bootstrap' and 'kubernetes/apps' not found. Run from repo root."; fi
    
    touch "${LOG_FILE}" &>/dev/null || { echo "FATAL ERROR: Cannot write to log file at ${LOG_FILE}." >&2; exit 1; } 
    exec &> >(tee -a "$LOG_FILE") 

    log_info "Deployment Bootstrapper (v23.1) initiated. Full log: ${LOG_FILE}" 

    ensure_cloudflare_wildcard_a
    perform_system_cleanup
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