#!/bin/bash

# This script collects comprehensive diagnostic information from a Kubernetes cluster.
# It is designed to be non-interactive and to be run after a deployment failure.

set -o pipefail
LOG_FILE="diagnostics_dump_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${LOG_FILE}")

# --- Configuration ---
# Ensure these variables match your environment if needed.
VPS_IP="172.245.187.113"
SSH_USER="root"
SSH_PRIVATE_KEY_PATH="~/.ssh/id_rsa"
SSH_KEY_PATH_EXPANDED="${SSH_PRIVATE_KEY_PATH/#\~/$HOME}"
SSH_CMD="ssh -i ${SSH_KEY_PATH_EXPANDED} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

# --- Helper Function ---
print_header() {
    echo -e "\n\033[1;33m--- [$1] $2 ---\033[0m"
}

# --- Main Logic ---
echo -e "\033[1;31m##############################################################################\033[0m"
echo -e "\033[1;31m#             FAILURE DETECTED. INITIATING DIAGNOSTIC COLLECTION.            #\033[0m"
echo -e "\033[1;31m##############################################################################\033[0m"

# Ensure Kubeconfig is set
export KUBECONFIG=~/.kube/config
if [ ! -f "$KUBECONFIG" ]; then
    echo "Kubeconfig not found at $KUBECONFIG. Aborting."
    exit 1
fi
echo "Using Kubeconfig from: $KUBECONFIG"
echo "Verifying kubectl connectivity..."
kubectl version || { echo "kubectl command failed. Is the cluster accessible?"; exit 1; }

# 1. Host-level Diagnostics
print_header "DIAG-HOST" "Listening ports on host (ss -tlpn)"
${SSH_CMD} "${SSH_USER}@${VPS_IP}" "ss -tlpn" || echo "[ERROR] Failed to get host listening ports."

print_header "DIAG-HOST" "K3s service journal (last 200 lines from this boot)"
${SSH_CMD} "${SSH_USER}@${VPS_IP}" "journalctl --no-pager -u k3s --boot=0 | tail -n 200" || echo "[ERROR] Failed to get k3s journal."

# 2. Kubernetes Cluster-wide Diagnostics
print_header "DIAG-K8S" "Node status (kubectl get nodes -o wide)"
kubectl get nodes -o wide

print_header "DIAG-K8S" "All pods in all namespaces (kubectl get pods -A -o wide)"
kubectl get pods -A -o wide

# 3. ArgoCD Diagnostics
print_header "DIAG-ARGOCD" "All ArgoCD Applications (YAML output)"
kubectl get applications -A -o yaml

# 4. Deep Dive into Failing Components (Traefik)
print_header "DIAG-NS" "Resources in namespace: traefik"
kubectl get all -n traefik -o wide || echo "[INFO] Namespace 'traefik' might not exist or has no resources."

print_header "DIAG-PODS" "Pod descriptions in namespace: traefik"
kubectl describe pod -n traefik -l app.kubernetes.io/name=traefik || echo "[INFO] No pods found to describe in 'traefik' namespace."

print_header "DIAG-LOGS" "Pod logs in namespace: traefik (all logs)"
# Get logs from current and previous crashed container
POD_NAME=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' || echo "")
if [ -n "$POD_NAME" ]; then
    echo "--- Logs for pod/container: $POD_NAME/traefik in traefik ---"
    kubectl logs "pod/$POD_NAME" -n traefik --all-containers --tail=-1 || echo "[INFO] Could not retrieve current logs for $POD_NAME."
    echo "--- Logs for PREVIOUSLY CRASHED pod/container: $POD_NAME/traefik in traefik ---"
    kubectl logs "pod/$POD_NAME" -n traefik --all-containers --previous --tail=-1 || echo "[INFO] Could not retrieve previous logs for $POD_NAME (this is normal if it hasn't crashed)."
else
    echo "[INFO] No Traefik pod found to get logs from."
fi

# 5. Deep Dive into Supporting Components (Cert-Manager & ArgoCD itself)
print_header "DIAG-NS" "Resources in namespace: cert-manager"
kubectl get all -n cert-manager -o wide || echo "[INFO] Namespace 'cert-manager' might not exist or has no resources."

print_header "DIAG-PODS" "Pod descriptions in namespace: cert-manager"
kubectl describe pod -n cert-manager || echo "[INFO] No pods found to describe in 'cert-manager' namespace."

print_header "DIAG-LOGS" "Pod logs in namespace: cert-manager (all logs)"
for pod in $(kubectl get pods -n cert-manager -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n cert-manager -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in cert-manager ---"
        kubectl logs "$pod" -c "$container" -n cert-manager --tail=-1 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

print_header "DIAG-NS" "Resources in namespace: argocd"
kubectl get all -n argocd -o wide || echo "[INFO] Namespace 'argocd' might not exist or has no resources."

print_header "DIAG-PODS" "Pod descriptions in namespace: argocd"
kubectl describe pod -n argocd || echo "[INFO] No pods found to describe in 'argocd' namespace."

print_header "DIAG-LOGS" "Pod logs in namespace: argocd (all logs)"
for pod in $(kubectl get pods -n argocd -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n argocd -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in argocd ---"
        kubectl logs "$pod" -c "$container" -n argocd --tail=-1 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

# 6. Check Core System Components
print_header "DIAG-NS" "Resources in namespace: kube-system"
kubectl get all -n kube-system -o wide || echo "[INFO] Namespace 'kube-system' might not exist or has no resources."

print_header "DIAG-PODS" "Pod descriptions in namespace: kube-system"
kubectl describe pod -n kube-system || echo "[INFO] No pods found to describe in 'kube-system' namespace."

print_header "DIAG-LOGS" "Pod logs in namespace: kube-system (all logs)"
for pod in $(kubectl get pods -n kube-system -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n kube-system -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in kube-system ---"
        kubectl logs "$pod" -c "$container" -n kube-system --tail=-1 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

echo -e "\n\033[1;31m--- END OF DIAGNOSTICS ---\033[0m"
echo -e "\nDiagnostic data saved to: \033[1;32m${LOG_FILE}\033[0m"