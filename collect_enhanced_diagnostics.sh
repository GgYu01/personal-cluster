#!/usr/bin/env bash
#
# Enhanced Full System Diagnostics Script
#
# This script is designed to:
# 1. Execute the deploy.sh script to reproduce the failure.
# 2. Immediately capture critical system state, focusing on K3s process arguments
#    and Pod Security Admission (PSA) configurations.
# 3. Collect comprehensive logs and resource states for deep analysis.
#
# The entire output is redirected to a timestamped log file.

set -eo pipefail

# --- Configuration ---
readonly DIAG_LOG_FILE="$(pwd)/enhanced_diagnostics_$(date +%Y%m%d-%H%M%S).log"

# --- Helper Functions ---
log_header() {
    echo -e "\n\n# ============================================================================== #"
    echo -e "# DIAGNOSTIC SECTION: ${1}"
    echo -e "# Timestamp: $(date -u --iso-8601=seconds)"
    echo -e "# ============================================================================== #\n"
}

# Redirect all stdout and stderr to the log file and the console
exec &> >(tee -a "${DIAG_LOG_FILE}")

echo "### Enhanced Diagnostics Started ###"
echo "Full log will be saved to: ${DIAG_LOG_FILE}"

# --- [SECTION 1: Pre-run State Verification] ---
log_header "Pre-run State Verification"
echo "--> Verifying presence of required scripts..."
if [[ ! -f ./deploy.sh ]]; then
    echo "FATAL: deploy.sh not found in the current directory. Aborting." >&2
    exit 1
fi
chmod +x ./deploy.sh
echo "deploy.sh is present and executable."

echo "--> Displaying content of deploy.sh for verification:"
echo "--- deploy.sh content start ---"
cat ./deploy.sh
echo "--- deploy.sh content end ---"

# --- [SECTION 2: Reproduce the Failure] ---
log_header "Reproducing Failure by Running deploy.sh"
echo "--> Executing ./deploy.sh. This is expected to fail. The script will continue after failure."
# We use '|| true' to ensure this diagnostic script doesn't exit when deploy.sh fails.
./deploy.sh || true
echo "--> deploy.sh execution finished."

# --- [SECTION 3: Critical Post-failure State Capture] ---
log_header "Critical Post-failure State Capture"

echo "--> Displaying content of the admission config file as it exists on the system:"
if [ -f /etc/rancher/k3s/admission-config.yaml ]; then
    echo "--- /etc/rancher/k3s/admission-config.yaml content start ---"
    cat /etc/rancher/k3s/admission-config.yaml
    echo "--- /etc/rancher/k3s/admission-config.yaml content end ---"
else
    echo "WARN: /etc/rancher/k3s/admission-config.yaml NOT FOUND."
fi

echo "--> Capturing K3s server process and its full arguments. This is CRITICAL for PSS debugging."
# Using pgrep and ps to be robust. This shows the exact command line.
K3S_PID=$(pgrep -f "k3s server")
if [ -n "$K3S_PID" ]; then
    echo "K3s server process found with PID: $K3S_PID"
    ps -f -p "$K3S_PID"
else
    echo "WARN: K3s server process not found running."
fi

echo "--> Checking K3s service status..."
systemctl status k3s.service --no-pager || echo "WARN: Could not get k3s.service status."

echo "--> Dumping K3s journal (last 1000 lines from current boot)..."
journalctl -u k3s.service --no-pager -b -n 1000

# --- [SECTION 4: Kubernetes Resource State Dump] ---
log_header "Kubernetes Resource State Dump"

if [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
    echo "--> Kubeconfig found. Proceeding with kubectl commands."

    echo "--> Describing nodes..."
    kubectl describe nodes

    echo "--> Listing all pods in all namespaces..."
    kubectl get pods -A -o wide

    echo "--> Describing pods in 'traefik' namespace..."
    kubectl describe pods -n traefik

    echo "--> Getting logs from pods in 'traefik' namespace (if any are running)..."
    # This loop will only run if pods exist, and won't fail if they don't
    for pod in $(kubectl get pods -n traefik -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
        echo "---- Logs for pod: ${pod} ----"
        kubectl logs "${pod}" -n traefik --all-containers=true --tail=200 || echo "WARN: Could not get logs for pod ${pod}."
    done

    echo "--> Describing DaemonSet in 'traefik' namespace..."
    kubectl describe daemonset -n traefik

    echo "--> Describing ArgoCD Application 'traefik'..."
    kubectl describe application traefik -n argocd

    echo "--> Getting all events from 'traefik' namespace..."
    kubectl get events -n traefik --sort-by='.lastTimestamp'

else
    echo "WARN: Kubeconfig not found at $HOME/.kube/config. Skipping kubectl commands."
fi

# --- [SECTION 5: Docker and Network State] ---
log_header "Docker and Network State"

echo "--> Docker ps for ETCD container..."
docker ps -a | grep etcd

echo "--> Docker logs for ETCD container..."
docker logs "${ETCD_CONTAINER_NAME:-core-etcd}" --tail 200 || echo "WARN: Could not get logs for etcd container."

echo "--> Host network listeners (ss)..."
ss -tlpn

echo "### Enhanced Diagnostics Finished ###"
echo "Please provide the entire content of the file: ${DIAG_LOG_FILE}"s