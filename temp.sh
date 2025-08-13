#!/bin/bash

# ==============================================================================
#      Comprehensive Kubernetes & Application Diagnostics Script (v2.0)
# ==============================================================================
#
# This script is designed to be run after a deployment failure. It captures
# a focused snapshot of the cluster state, prioritizing logs from crashed
# containers and the configuration of key components.
#
# ==============================================================================

set -o pipefail
DIAG_LOG_FILE="diagnostics_dump_$(date +%Y%m%d_%H%M%S).log"
exec &> >(tee -a "${DIAG_LOG_FILE}")

# --- Configuration ---
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

export KUBECONFIG=~/.kube/config
if [ ! -f "$KUBECONFIG" ]; then
    echo "Kubeconfig not found at $KUBECONFIG. Aborting."
    exit 1
fi
echo "Using Kubeconfig from: $KUBECONFIG"
echo "Verifying kubectl connectivity..."
kubectl version --short || { echo "kubectl command failed. Is the cluster accessible?"; exit 1; }

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
kubectl get all,ingressroute,ingressroutetcp,ingressrouteudp,middleware,tlsstore,traefikservice -n traefik -o wide || echo "[INFO] Namespace 'traefik' might not exist or has no resources."

print_header "DIAG-PODS" "Pod descriptions in namespace: traefik"
kubectl describe pod -n traefik -l app.kubernetes.io/name=traefik || echo "[INFO] No pods found to describe in 'traefik' namespace."

print_header "DIAG-LOGS" "Pod logs in namespace: traefik (all logs)"
for pod in $(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o jsonpath='{.items[*].metadata.name}'); do
    echo "--- Logs for pod/container: $pod/traefik in traefik ---"
    kubectl logs "pod/$pod" -n traefik --all-containers=true --tail=200 || echo "[INFO] Could not retrieve current logs for $pod."
    echo "--- Logs for PREVIOUSLY CRASHED pod/container: $pod/traefik in traefik ---"
    kubectl logs "pod/$pod" -n traefik --all-containers=true --previous --tail=200 || echo "[INFO] No previous logs found for $pod (this is normal if it hasn't crashed yet)."
done

# 5. Deep Dive into Supporting Components
print_header "DIAG-NS" "Resources in namespace: cert-manager"
kubectl get all,clusterissuer,issuer,certificaterequest -n cert-manager -o wide || echo "[INFO] Namespace 'cert-manager' might not exist."

print_header "DIAG-PODS" "Pod descriptions in namespace: cert-manager"
kubectl describe pod -n cert-manager --selector app.kubernetes.io/instance=cert-manager || true

print_header "DIAG-LOGS" "Pod logs in namespace: cert-manager (all logs)"
for pod in $(kubectl get pods -n cert-manager -l app.kubernetes.io/instance=cert-manager -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n cert-manager -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in cert-manager ---"
        kubectl logs "$pod" -c "$container" -n cert-manager --tail=100 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

print_header "DIAG-NS" "Resources in namespace: argocd"
kubectl get all -n argocd -o wide || echo "[INFO] Namespace 'argocd' might not exist."

print_header "DIAG-PODS" "Pod descriptions in namespace: argocd"
kubectl describe pod -n argocd -l app.kubernetes.io/part-of=argocd || true

print_header "DIAG-LOGS" "Pod logs in namespace: argocd (all logs)"
for pod in $(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n argocd -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in argocd ---"
        kubectl logs "$pod" -c "$container" -n argocd --tail=100 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

# 6. Check Core System Components
print_header "DIAG-NS" "Resources in namespace: kube-system"
kubectl get all -n kube-system -o wide

print_header "DIAG-PODS" "Pod descriptions in namespace: kube-system"
kubectl describe pod -n kube-system || true

print_header "DIAG-LOGS" "Pod logs in namespace: kube-system (all logs)"
for pod in $(kubectl get pods -n kube-system -o jsonpath='{.items[*].metadata.name}'); do
    for container in $(kubectl get pod "$pod" -n kube-system -o jsonpath='{.spec.containers[*].name}'); do
        echo "--- Logs for pod/container: $pod/$container in kube-system ---"
        kubectl logs "$pod" -c "$container" -n kube-system --tail=100 || echo "[INFO] Could not get logs for $pod/$container."
    done
done

echo -e "\n\033[1;31m--- END OF DIAGNOSTICS ---\033[0m"
echo -e "\nDiagnostic data saved to: \033[1;32m${DIAG_LOG_FILE}\033[0m"