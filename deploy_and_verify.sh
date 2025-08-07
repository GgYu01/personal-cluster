#!/bin/bash

# ==============================================================================
#           Definitive End-to-End Cluster Redeployment Script - V3
# ==============================================================================
# This script orchestrates the entire deployment, moving ArgoCD installation
# from Terraform to a script-based Helm CLI workflow for maximum control and
# to resolve ownership conflicts.
#
# Workflow:
# 1. Set environment variables.
# 2. Clean local Terraform state.
# 3. Deploy infrastructure (01-infra) with Terraform.
# 4. Extract Kubeconfig.
# 5. Forcefully clean and recreate the 'argocd' namespace.
# 6. Install ArgoCD CRDs using 'helm template | kubectl apply'.
# 7. Wait for CRDs to be established.
# 8. Install ArgoCD application using 'helm install --skip-crds'.
# 9. Wait for ArgoCD deployments to be ready.
# 10. Deploy the root application (02-apps) with Terraform.
# ==============================================================================

set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="redeploy_all_v3_$(date +%Y%m%d_%H%M%S).log"
INFRA_DIR="01-infra"
APPS_DIR="02-apps"
ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="8.2.4"
# Bcrypt hash for "password"
ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$r8i.p3qV5.IqLgqvB..31eL9g/XyJc5lqJzCrHw5TKSg2Kx5i/fWu'

# --- Helper Function for Logging ---
log_step() {
    echo -e "\n==============================================================================" | tee -a "${LOG_FILE}"
    echo "==> STEP $1: $2" | tee -a "${LOG_FILE}"
    echo "==============================================================================" | tee -a "${LOG_FILE}"
}

# --- Script Start ---
if [ ! -d "$INFRA_DIR" ] || [ ! -d "$APPS_DIR" ]; then
    echo "ERROR: This script must be run from the root directory of the 'personal-cluster' repository." >&2
    exit 1
fi

> "${LOG_FILE}"
exec &> >(tee -a "${LOG_FILE}") # Redirect all stdout/stderr to file and console

echo "Definitive cluster redeployment script (v3) started."
date

# --- STEP 1: Set Environment Variables ---
log_step "1" "Exporting Terraform environment variables"
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
# This variable was added in the previous step, ensure it's set.
export TF_VAR_manage_dns_record="false"
echo "Environment variables exported."

# --- STEP 2: Clean Local Terraform Workspaces ---
log_step "2" "Cleaning local Terraform workspaces"
rm -f "${INFRA_DIR}/.terraform.lock.hcl" "${INFRA_DIR}/terraform.tfstate" "${INFRA_DIR}/terraform.tfstate.backup"
rm -rf "${INFRA_DIR}/.terraform"
rm -f "${APPS_DIR}/.terraform.lock.hcl" "${APPS_DIR}/terraform.tfstate" "${APPS_DIR}/terraform.tfstate.backup"
rm -rf "${APPS_DIR}/.terraform"
echo "Local workspaces cleaned."

# --- STEP 3: Deploy Infrastructure Stage (01-infra) ---
log_step "3" "Deploying Infrastructure Stage with Terraform"
cd "${INFRA_DIR}"
terraform init -upgrade
terraform apply -auto-approve
cd ..

# --- STEP 4: Extract Kubeconfig ---
log_step "4" "Extracting Kubeconfig"
KUBECONFIG_CONTENT=$(cd "${INFRA_DIR}" && terraform output -raw kubeconfig_content)
KUBECONFIG_TMP_FILE=$(mktemp)
echo "${KUBECONFIG_CONTENT}" > "${KUBECONFIG_TMP_FILE}"
export KUBECONFIG="${KUBECONFIG_TMP_FILE}"
echo "Kubeconfig extracted and set for subsequent kubectl/helm commands."

# --- STEP 5: Clean and Recreate ArgoCD Namespace ---
log_step "5" "Forcefully cleaning and recreating '${ARGOCD_NS}' namespace"
kubectl delete namespace "${ARGOCD_NS}" --ignore-not-found=true
# Wait for the namespace to be fully gone before recreating
timeout 120s bash -c \
    'while kubectl get namespace '"${ARGOCD_NS}"' &> /dev/null; do echo -n "."; sleep 2; done'
echo -e "\nNamespace deleted."
kubectl create namespace "${ARGOCD_NS}"
echo "Namespace '${ARGOCD_NS}' created."

# --- STEP 6: Install ArgoCD CRDs using helm template ---
log_step "6" "Installing ArgoCD CRDs precisely"
helm repo add argo https://argoproj.github.io/argo-helm || echo "Helm repo argo already exists."
helm repo update
# Template the chart, grep for ONLY the CRD kinds, and apply them.
helm template argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" --set crds.install=true | \
    awk 'BEGIN {RS="---"; ORS="---"} /kind: CustomResourceDefinition/' | \
    kubectl apply -f -
echo "CRD manifests applied."

# --- STEP 7: Wait for CRDs to be Established ---
log_step "7" "Waiting for ArgoCD CRDs to become established"
kubectl wait --for condition=established --timeout=120s crd/applications.argoproj.io
kubectl wait --for condition=established --timeout=120s crd/applicationsets.argoproj.io
kubectl wait --for condition=established --timeout=120s crd/appprojects.argoproj.io
echo "All critical CRDs are established."

# --- STEP 8: Install ArgoCD Application using helm install ---
log_step "8" "Installing ArgoCD application with Helm CLI"
helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" \
    --set "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
    --skip-crds \
    --wait \
    --timeout 15m
echo "ArgoCD application Helm chart installed."

# --- STEP 9: Deploy Root Application with Terraform ---
log_step "9" "Deploying Root Application Stage with Terraform"
cd "${APPS_DIR}"
terraform init -upgrade
terraform apply -auto-approve
cd ..

# --- STEP 10: Cleanup and Final Instructions ---
log_step "10" "Deployment Complete"
rm -f "${KUBECONFIG_TMP_FILE}"
unset KUBECONFIG
echo "Temporary kubeconfig file cleaned up."
echo "The entire cluster has been redeployed."
echo "ArgoCD should now be synchronizing your applications."
echo "Access it at: https://argocd.core01.prod.gglohh.top"

date
echo "Definitive redeployment script finished successfully."