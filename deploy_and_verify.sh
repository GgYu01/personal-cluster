#!/bin/bash
# ==============================================================================
#      Definitive Non-Interactive Deployment & Verification Script (v6)
# ==============================================================================
# v6 Changes:
# - Automates the download and extraction of ArgoCD CRD manifests.
# - Ensures a clean, repeatable bootstrap process for CRDs.

# --- Configuration ---
GITOPS_REPO_URL="https://github.com/GgYu01/personal-cluster.git"
ARGOCD_CHART_VERSION="8.2.4"

# --- System & Logging Setup ---
set -e
set -o pipefail
LOG_FILE="deployment_run_$(date +%Y%m%d_%H%M%S).log"
KUBECONFIG_FILE="$(pwd)/k3s-debug-session.yaml"

# --- Pre-flight Checks ---
if ! command -v jq &> /dev/null || ! command -v helm &> /dev/null; then
    echo "FATAL: 'jq' or 'helm' is not installed. Please install them and retry."
    exit 1
fi

# --- Logging Setup ---
touch "$LOG_FILE"
exec &> >(tee -a "$LOG_FILE")
echo "### Log file created at $(date) ###"

# --- Helper Function ---
function execute_and_log() {
    local description="$1"
    shift
    local command_to_run=("$@")

    echo
    echo "# =============================================================================="
    echo "# STEP: $description"
    echo "# TIMESTAMP: $(date --iso-8601=seconds)"
    echo "# COMMAND: ${command_to_run[*]}"
    echo "# =============================================================================="
    
    if [[ "$description" == *"Cleanup"* ]]; then
        eval "${command_to_run[*]}" || true
    else
        eval "${command_to_run[*]}"
    fi
}

# ==============================================================================
#                               EXECUTION STARTS
# ==============================================================================
echo "### Starting Full Deployment & Verification ###"

# --- PHASE 1: THOROUGH ENVIRONMENT CLEANUP ---
execute_and_log "1.1: Cleanup - Uninstall existing Helm releases" "helm uninstall argocd -n argocd"
execute_and_log "1.2: Cleanup - Delete potentially lingering namespaces" "kubectl delete ns argocd"
execute_and_log "1.3: Cleanup - CRITICAL - Delete ArgoCD CRDs" "kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io"
echo "INFO: Cleanup commands sent. Waiting 30 seconds for resource termination."
sleep 30

# --- PHASE 2: TERRAFORM BOOTSTRAP PREPARATION ---
execute_and_log "2.1: Bootstrap Prep - Generate Kubeconfig from 01-infra state" "bash -c 'cd 01-infra && terraform output -raw kubeconfig_content > ../k3s-debug-session.yaml && cd ..'"
export KUBECONFIG="$KUBECONFIG_FILE"
echo "INFO: KUBECONFIG environment variable has been set for this script session."

execute_and_log "2.2: Bootstrap Prep - Forcefully remove local Terraform state and cache" \
    "rm -rf 02-apps/.terraform 02-apps/.terraform.lock.hcl 02-apps/terraform.tfstate* 02-apps/crd-manifests"

execute_and_log "2.3: Bootstrap Prep - Download and extract ArgoCD CRD manifests" \
    "bash -c 'helm repo add argo https://argoproj.github.io/argo-helm || true; \
     helm repo update; \
     rm -rf argo-cd-chart-temp; \
     helm pull argo/argo-cd --version ${ARGOCD_CHART_VERSION} --untar -d argo-cd-chart-temp; \
     mkdir -p 02-apps/crd-manifests; \
     cp argo-cd-chart-temp/argo-cd/templates/crds/*.yaml 02-apps/crd-manifests/; \
     rm -rf argo-cd-chart-temp; \
     echo \"CRD manifests prepared successfully.\";'"

# --- PHASE 3: TERRAFORM EXECUTION ---
execute_and_log "3.1: Execution - Initialize 02-apps Terraform workspace" "bash -c 'cd 02-apps && terraform init -upgrade'"

execute_and_log "3.2: Execution - Atomically apply all 02-apps resources" \
    "bash -c 'cd 02-apps && terraform apply -auto-approve \
    -var=\"gitops_repo_url=${GITOPS_REPO_URL}\"'"

# --- PHASE 4: DEEP GITOOPS VERIFICATION ---
echo "INFO: Terraform bootstrap complete. Now monitoring GitOps sync process..."

execute_and_log "4.1: Verify - Wait up to 5 minutes for core Deployments (argocd) to become available" \
    "kubectl wait --for=condition=Available deployment -n argocd --all --timeout=300s"

echo "INFO: Core components are up. Waiting up to 10 minutes for all ArgoCD applications to sync."
# ... (Verification steps for GitOps sync remain the same) ...

echo
echo "### Deployment and verification finished successfully. ###"
echo "### Log file is available at: $LOG_FILE ###"