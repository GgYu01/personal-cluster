#!/usr/bin/env bash

# ==============================================================================
#
#           ARGO CD DEEP DIVE DIAGNOSTIC SCRIPT
#
# ==============================================================================
#
#   PURPOSE: To be executed after a GitOps deployment failure to collect
#   detailed state information from ArgoCD and its managed resources.
#
# ==============================================================================

set -e

# Helper function for logging sections
log_section() {
    echo -e "\n\n\033[1;35m# --- DEBUG SECTION: $1 (Timestamp: $(date -u --iso-8601=seconds)) ---\033[0m"
}

log_info() {
    echo "--> DEBUG: $1"
}

# --- Start Diagnostics ---
log_info "Starting ArgoCD deep dive diagnostics..."
export KUBECONFIG="${HOME}/.kube/config"

# --- Section 1: ArgoCD Application Overview ---
log_section "ArgoCD Application Tree & Status"
log_info "Getting all Applications in 'argocd' namespace (wide view)..."
kubectl get applications -n argocd -o wide
log_info "Getting all Applications in 'argocd' namespace (YAML view for full status)..."
kubectl get applications -n argocd -o yaml

# --- Section 2: Individual Application Sync Status & Events ---
log_section "Individual Application Details"
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}'); do
    log_info "Describing Application: ${app}"
    kubectl describe application "${app}" -n argocd
    log_info "Getting sync status for Application: ${app}"
    # Using argocd CLI if available, otherwise skipping
    if command -v argocd &> /dev/null; then
        # Assuming already logged in or have context configured
        argocd app get "${app}" --show-operation || echo "argocd CLI command failed for ${app}, continuing..."
    else
        log_info "argocd CLI not found, skipping 'argocd app get'."
    fi
done

# --- Section 3: Logs from ArgoCD Controller Pods ---
log_section "ArgoCD Controller Logs"
log_info "Fetching logs from 'argocd-application-controller'..."
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=200
log_info "Fetching logs from 'argocd-repo-server'..."
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=200

# --- Section 4: Status of Managed Resources (Cert-Manager & Traefik) ---
log_section "Status of Key Managed Components"

log_info "Checking resources in 'cert-manager' namespace..."
kubectl get all,issuers,clusterissuers,certificates,certificaterequests,orders,challenges -n cert-manager -o wide || echo "Could not get resources from cert-manager namespace."
log_info "Describing all pods in 'cert-manager' namespace..."
kubectl describe pods -n cert-manager || echo "Could not describe pods in cert-manager namespace."

log_info "Checking resources in 'traefik' namespace..."
kubectl get all,ingressroutes,middlewares -n traefik -o wide || echo "Could not get resources from traefik namespace."
log_info "Describing all pods in 'traefik' namespace..."
kubectl describe pods -n traefik || echo "Could not describe pods in traefik namespace."

# --- Section 5: Cluster-wide Events ---
log_section "Recent Cluster-wide Events"
log_info "Fetching last 50 events across all namespaces, sorted by time..."
kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50

log_info "ArgoCD deep dive diagnostics complete."