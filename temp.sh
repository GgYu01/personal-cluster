#!/bin/bash
# ==============================================================================
#      Definitive Scorched Earth Cleanup Script
# ==============================================================================
# WARNING: This script will forcefully remove ALL traces of ArgoCD.

set -e
set -o pipefail

function print_header() { echo; echo "--- $1 ---"; echo; }

print_header "STEP 1: Deleting all ArgoCD Applications to trigger finalizers"
# --cascade=false is intentional here. We want to delete the app definitions first,
# then manually clean up the resources to avoid getting stuck.
kubectl delete application --all -n argocd || true

print_header "STEP 2: Uninstalling Helm release to detach its resource tracking"
helm uninstall argocd -n argocd --ignore-not-found

print_header "STEP 3: Forcefully deleting the 'argocd' namespace"
# This will delete most ArgoCD resources, but might leave CRDs and ClusterRoles.
kubectl delete namespace argocd --force --grace-period=0 || true

print_header "STEP 4: Deleting all ArgoCD Custom Resource Definitions (CRDs)"
# This is critical to ensure a clean re-installation.
kubectl delete crd applications.argoproj.io --ignore-not-found
kubectl delete crd applicationsets.argoproj.io --ignore-not-found
kubectl delete crd appprojects.argoproj.io --ignore-not-found

print_header "STEP 5: Deleting leftover ClusterRoles and ClusterRoleBindings"
# These are often left behind after a namespace deletion.
kubectl delete clusterrole -l app.kubernetes.io/part-of=argocd --ignore-not-found
kubectl delete clusterrolebinding -l app.kubernetes.io/part-of=argocd --ignore-not-found

print_header "STEP 6: Waiting 30 seconds for all resources to terminate"
sleep 30

print_header "STEP 7: Final verification of cleanup"
echo "Checking for lingering ArgoCD resources..."
if kubectl get ns argocd > /dev/null 2>&1; then
    echo "ERROR: 'argocd' namespace still exists."
    exit 1
fi
if kubectl get crds | grep -q "argoproj.io"; then
    echo "ERROR: ArgoCD CRDs still exist."
    exit 1
fi
echo "SUCCESS: Scorched Earth Cleanup Complete. The cluster is clean."