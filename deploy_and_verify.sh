#!/bin/bash

# ==============================================================================
#                 Full Cluster Redeployment Orchestration Script - V2
# ==============================================================================
# This script is designed to be executed on your LOCAL development machine.
#
# V2 Changes:
# - Adds a pre-flight check to forcefully delete the 'argocd' namespace
#   on the remote cluster to prevent Helm ownership conflicts from previous runs.
# ==============================================================================

set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="redeploy_all_$(date +%Y%m%d_%H%M%S).log"
INFRA_DIR="01-infra"
APPS_DIR="02-apps"
ARGOCD_NS="argocd"

# --- Helper Function for Logging ---
log_step() {
    echo -e "\n==============================================================================" | tee -a "${LOG_FILE}"
    echo "==> STEP $1: $2" | tee -a "${LOG_FILE}"
    echo "==============================================================================" | tee -a "${LOG_FILE}"
}

# --- Script Start ---
# ... (rest of the script preamble remains the same)
if [ ! -d "$INFRA_DIR" ] || [ ! -d "$APPS_DIR" ]; then
    echo "ERROR: This script must be run from the root directory of the 'personal-cluster' repository." >&2
    exit 1
fi

> "${LOG_FILE}"
echo "Full cluster redeployment script started. All output will be logged to ${LOG_FILE}"

# --- STEP 1: Set Environment Variables for Terraform ---
log_step "1" "Exporting Terraform environment variables"
(
    # ... (variable exports remain the same)
    export TF_VAR_domain_name="gglohh.top"
    export TF_VAR_site_code="core01"
    export TF_VAR_environment="prod"
    export TF_VAR_vps_ip="172.245.187.113"
    export TF_VAR_ssh_user="root"
    export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
    export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
    export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
    echo "All TF_VAR_* variables have been exported."
) | tee -a "${LOG_FILE}"

# Re-export variables for the main script shell
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"

# --- NEW PRE-FLIGHT STEP: Forcefully clean the remote cluster ---
log_step "PRE-FLIGHT" "Forcefully cleaning '${ARGOCD_NS}' namespace on remote cluster"
(
    echo "This step ensures no lingering resources from previous failed attempts."
    # We need to get the kubeconfig content from the infra stage first to interact with the cluster.
    # We will run a targeted `terraform output` for this.
    echo "--- Temporarily initializing infra to get kubeconfig ---"
    cd "${INFRA_DIR}" && terraform init -upgrade >/dev/null && cd ..
    
    echo "--- Fetching kubeconfig from remote state ---"
    KUBECONFIG_CONTENT=$(cd "${INFRA_DIR}" && terraform output -raw kubeconfig_content)
    
    # Use a temporary file for the kubeconfig
    KUBECONFIG_TMP_FILE=$(mktemp)
    echo "${KUBECONFIG_CONTENT}" > "${KUBECONFIG_TMP_FILE}"
    
    echo "--- Deleting namespace '${ARGOCD_NS}' if it exists ---"
    kubectl --kubeconfig="${KUBECONFIG_TMP_FILE}" delete namespace "${ARGOCD_NS}" --ignore-not-found=true --wait=true
    
    # Clean up the temp file
    rm -f "${KUBECONFIG_TMP_FILE}"
    echo "Remote namespace cleaned."
) | tee -a "${LOG_FILE}" 2>&1

# --- STEP 2: Clean Local Terraform Workspaces ---
log_step "2" "Cleaning local Terraform workspaces"
(
    # ... (cleaning steps remain the same)
    echo "--- Cleaning ${INFRA_DIR} ---"
    rm -f "${INFRA_DIR}/.terraform.lock.hcl" "${INFRA_DIR}/terraform.tfstate" "${INFRA_DIR}/terraform.tfstate.backup"
    rm -rf "${INFRA_DIR}/.terraform"
    echo "Workspace for ${INFRA_DIR} cleaned."

    echo "--- Cleaning ${APPS_DIR} ---"
    rm -f "${APPS_DIR}/.terraform.lock.hcl" "${APPS_DIR}/terraform.tfstate" "${APPS_DIR}/terraform.tfstate.backup"
    rm -rf "${APPS_DIR}/.terraform"
    echo "Workspace for ${APPS_DIR} cleaned."
) | tee -a "${LOG_FILE}"

# --- STEP 3: Deploy Infrastructure Stage (01-infra) ---
log_step "3" "Deploying Infrastructure Stage (${INFRA_DIR})"
(
    cd "${INFRA_DIR}" && \
    echo "--- Initializing Terraform for ${INFRA_DIR} ---" && \
    terraform init && \
    echo "--- Applying Terraform plan for ${INFRA_DIR} ---" && \
    terraform apply -auto-approve
) | tee -a "${LOG_FILE}" 2>&1

# --- STEP 4: Deploy Applications Stage (02-apps) ---
log_step "4" "Deploying Applications Stage (${APPS_DIR})"
(
    cd "${APPS_DIR}" && \
    echo "--- Initializing Terraform for ${APPS_DIR} ---" && \
    terraform init && \
    echo "--- Applying Terraform plan for ${APPS_DIR} ---" && \
    terraform apply -auto-approve
) | tee -a "${LOG_FILE}" 2>&1

# --- STEP 5: Final Instructions ---
log_step "5" "Deployment Complete"
# ... (final instructions remain the same)
(
    echo "The entire cluster has been redeployed."
    echo "Please allow 5-10 minutes for ArgoCD to synchronize all applications and for Cert-Manager to issue the TLS certificate."
    echo "After this time, you can check the status by accessing:"
    echo "https://argocd.core01.prod.gglohh.top"
    echo ""
    echo "If you encounter any issues, please review the complete log file: ${LOG_FILE}"
) | tee -a "${LOG_FILE}"

echo -e "\n=============================================================================="
echo "==> REDEPLOYMENT SCRIPT FINISHED SUCCESSFULLY."
echo "=============================================================================="