#!/bin/bash

# ==============================================================================
#      "Nuke and Rebuild" - Definitive Cluster Deployment Script (v2.2)
# ==============================================================================
# v2.2 Changes:
# - The script now parses the Kubeconfig and passes credentials directly as
#   variables to the `02-apps` Terraform module, removing the dependency on
#   remote state and fixing the "Unsupported attribute" error.
# - This solidifies the script's role as the master orchestrator.
# ==============================================================================

# --- Strict Error Handling & Configuration ---
set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="nuke_and_rebuild_v2.2_$(date +%Y%m%d_%H%M%S).log"
INFRA_DIR="01-infra"
APPS_DIR="02-apps"
ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="6.7.15" # A known stable version
# Bcrypt hash for "password"
ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$r8i.p3qV5.IqLgqvB..31eL9g/XyJc5lqJzCrHw5TKSg2Kx5i/fWu'
CLUSTER_API_WAIT_TIMEOUT="300s" # 5 minutes

# --- User Variables (Hardcoded as per request) ---
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
export TF_VAR_manage_dns_record="false"

# Expand SSH key path for direct use
SSH_KEY_PATH_EXPANDED="${TF_VAR_ssh_private_key_path/#\~/$HOME}"
API_SERVER_FQDN="api.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"

# --- Helper Function for Logging ---
log_step() {
    echo -e "\n# ============================================================================== #" | tee -a "${LOG_FILE}"
    echo "# STEP $1: $2" | tee -a "${LOG_FILE}"
    echo -e "# ============================================================================== #\n" | tee -a "${LOG_FILE}"
}

# --- Script Start ---
> "${LOG_FILE}"
exec &> >(tee -a "${LOG_FILE}")

echo "### NUKE AND REBUILD SCRIPT (v2.2 - Variable Injection) INITIATED AT $(date) ###"

# --- STEP 1: SURGICAL STRIKE REMOTE CLEANUP ---
log_step "1" "Executing Surgical Strike Cleanup on Remote Server: ${TF_VAR_vps_ip}"
ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" << 'EOF'
    echo "--> [REMOTE] Running K3s uninstall script..."
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
    if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi
    echo "--> [REMOTE] Stopping and removing our 'core-etcd' container..."
    if [ "$(docker ps -q -f name=core-etcd)" ]; then docker stop core-etcd && docker rm core-etcd; fi
    echo "--> [REMOTE] Deleting project-specific directories..."
    rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd
    echo "--> [REMOTE] Surgical Strike cleanup complete."
EOF

# --- STEP 2: LOCAL WORKSPACE CLEANUP ---
log_step "2" "Cleaning Local Terraform Workspaces and State"
rm -rf "${INFRA_DIR}/.terraform" "${INFRA_DIR}/.terraform.lock.hcl" "${APPS_DIR}/.terraform" "${APPS_DIR}/.terraform.lock.hcl"
rm -f ${INFRA_DIR}/terraform.tfstate* ${APPS_DIR}/terraform.tfstate*
echo "Local workspaces and state files cleaned."

# --- STEP 3: DEPLOY INFRASTRUCTURE (TERRAFORM) ---
log_step "3" "Deploying Infrastructure (01-infra) via Terraform"
cd "${INFRA_DIR}"
terraform init -upgrade
terraform apply -auto-approve
cd ..
echo "Infrastructure deployment complete."

# --- STEP 4: FETCH AND PROCESS KUBECONFIG (BASH) ---
log_step "4" "Fetching and Processing Kubeconfig"
RAW_KUBECONFIG=$(ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
if [ -z "${RAW_KUBECONFIG}" ]; then echo "FATAL: Failed to fetch kubeconfig" >&2; exit 1; fi
PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
echo "Kubeconfig processed successfully."

# --- STEP 5: DEPLOY KUBECONFIG & WAIT FOR API SERVER ---
log_step "5" "Deploying Kubeconfig Locally and Waiting for API Server"
mkdir -p ~/.kube
echo "${PROCESSED_KUBECONFIG}" > ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo "Local kubeconfig deployed. Polling for API server readiness..."
end_time=$((SECONDS + ${CLUSTER_API_WAIT_TIMEOUT%s}))
while [ $SECONDS -lt $end_time ]; do
    if kubectl get nodes &> /dev/null; then
        if kubectl wait --for=condition=Ready node --all --timeout=60s; then
            echo "SUCCESS: All nodes are in 'Ready' state."
            break
        fi
    else
        echo -n "."
        sleep 5
    fi
done
if [ $SECONDS -ge $end_time ]; then echo "FATAL: Timed out waiting for cluster." >&2; exit 1; fi

# --- STEP 6: INSTALL ARGOCD (HELM CLI) ---
log_step "6" "Installing ArgoCD via Helm CLI"
kubectl delete namespace "${ARGOCD_NS}" --ignore-not-found=true --wait=true
kubectl create namespace "${ARGOCD_NS}"
helm repo add argo https://argoproj.github.io/argo-helm || echo "Repo exists."
helm repo update
helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" \
    --set "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
    --set "server.extraArgs={--insecure}" \
    --wait --timeout 15m
echo "ArgoCD Helm chart installed successfully."

# --- STEP 7: DEPLOY GITOPS ROOT APPLICATION (TERRAFORM) ---
log_step "7" "Deploying GitOps Root Application (02-apps) via Terraform"
echo "Extracting credentials from Kubeconfig to pass to Terraform..."
# Use kubectl config view to parse the kubeconfig file reliably
CLUSTER_HOST=$(echo "${PROCESSED_KUBECONFIG}" | kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA_CERT_B64=$(echo "${PROCESSED_KUBECONFIG}" | kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
CLIENT_CERT_B64=$(echo "${PROCESSED_KUBECONFIG}" | kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-certificate-data}')
CLIENT_KEY_B64=$(echo "${PROCESSED_KUBECONFIG}" | kubectl config view --raw --minify -o jsonpath='{.users[0].user.client-key-data}')

# The providers expect PEM strings, not base64 encoded data, so we must decode them.
CLUSTER_CA_CERT_PEM=$(echo "${CLUSTER_CA_CERT_B64}" | base64 --decode)
CLIENT_CERT_PEM=$(echo "${CLIENT_CERT_B64}" | base64 --decode)
CLIENT_KEY_PEM=$(echo "${CLIENT_KEY_B64}" | base64 --decode)

cd "${APPS_DIR}"
terraform init -upgrade
# Pass the extracted credentials as variables to the terraform apply command
terraform apply -auto-approve \
    -var="cluster_host=${CLUSTER_HOST}" \
    -var="cluster_ca_certificate=${CLUSTER_CA_CERT_PEM}" \
    -var="client_certificate=${CLIENT_CERT_PEM}" \
    -var="client_key=${CLIENT_KEY_PEM}"
cd ..
echo "Root application deployed. ArgoCD will now take over."

# --- STEP 8: FINAL VERIFICATION ---
# ... (rest of the script is identical) ...
log_step "8" "Final Verification"
echo "Waiting 60 seconds for ArgoCD to sync and for IngressRoute to be processed..."
sleep 60
echo "--- Verifying certificate issuance for staging environment..."
if ! kubectl describe certificate -n argocd argocd-server-tls-staging &> /dev/null; then
    echo "WARNING: Certificate 'argocd-server-tls-staging' not found."
else
    if ! kubectl describe certificate -n argocd argocd-server-tls-staging | grep "Successfully issued"; then
        echo "WARNING: Staging certificate does not appear to be issued yet."
    else
        echo "SUCCESS: Staging certificate has been issued."
    fi
fi
echo -e "\n### NUKE AND REBUILD COMPLETE ###"
echo "------------------------------------------------------------------------------"
echo "Kubeconfig is at ~/.kube/config. ArgoCD UI at: https://argocd.core01.prod.gglohh.top"
echo "NOTE: Browser warning is expected due to STAGING certificate."
echo "------------------------------------------------------------------------------"
date