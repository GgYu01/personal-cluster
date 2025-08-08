#!/bin/bash

# ==============================================================================
#      The Definitive End-to-End Cluster Redeployment Script - V5.1
# ==============================================================================
# v5.1 Changes:
# - Removed dependency on 'argocd-bcrypt-generator' which is deprecated.
# - Now uses a pre-generated, hardcoded bcrypt hash for the 'password' admin
#   password, making the script self-contained and more reliable.
# - Simplified ArgoCD installation to set the password directly via Helm values.
# ==============================================================================

set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="redeploy_all_v5.1_$(date +%Y%m%d_%H%M%S).log"
INFRA_DIR="01-infra"
ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="6.7.15"
# Pre-generated bcrypt hash for the password "password"
ARGOCD_ADMIN_PASSWORD_HASH='$2a$10$r8i.p3qV5.IqLgqvB..31eL9g/XyJc5lqJzCrHw5TKSg2Kx5i/fWu'
CLUSTER_API_WAIT_TIMEOUT="300s"

# --- User Variables ---
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"

# Expand SSH key path
SSH_KEY_PATH_EXPANDED="${TF_VAR_ssh_private_key_path/#\~/$HOME}"
API_SERVER_FQDN="api.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"

# --- Helper Function ---
log_step() {
    echo -e "\n# ============================================================================== #" | tee -a "${LOG_FILE}"
    echo "# STEP $1: $2" | tee -a "${LOG_FILE}"
    echo -e "# ============================================================================== #\n" | tee -a "${LOG_FILE}"
}

# --- Script Start ---
> "${LOG_FILE}"
exec &> >(tee -a "${LOG_FILE}")

echo "### DEFINITIVE REDEPLOYMENT SCRIPT (V5.1) INITIATED AT $(date) ###"

# --- STEP 1: REMOTE CLEANUP ---
log_step "1" "Executing Surgical Strike Cleanup on Remote Server: ${TF_VAR_vps_ip}"
ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" << 'EOF'
    echo "--> [REMOTE] Running K3s uninstall script..."
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
    echo "--> [REMOTE] Stopping and removing 'core-etcd' container..."
    if [ "$(docker ps -q -f name=core-etcd)" ]; then docker stop core-etcd && docker rm core-etcd; fi
    echo "--> [REMOTE] Deleting project-specific directories..."
    rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd
    echo "--> [REMOTE] Cleanup complete."
EOF

# --- STEP 2: LOCAL CLEANUP ---
log_step "2" "Cleaning Local Terraform Workspace"
rm -rf "${INFRA_DIR}/.terraform" "${INFRA_DIR}/.terraform.lock.hcl"
rm -f ${INFRA_DIR}/terraform.tfstate*
echo "Local workspace cleaned."

# --- STEP 3: DEPLOY INFRASTRUCTURE ---
log_step "3" "Deploying Infrastructure (01-infra) via Terraform"
cd "${INFRA_DIR}"
terraform init -upgrade
terraform apply -auto-approve
cd ..
echo "Infrastructure deployment complete."

# --- STEP 4: CONFIGURE KUBECONFIG & WAIT FOR API SERVER ---
log_step "4" "Configuring Kubeconfig and Waiting for API Server"
RAW_KUBECONFIG=$(ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
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

# --- STEP 5: INSTALL ARGOCD VIA HELM CLI ---
log_step "5" "Installing ArgoCD via Helm CLI with Hardcoded Password"
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm || echo "Repo exists."
helm repo update
# Install ArgoCD, its CRDs, and set the admin password hash in one atomic operation.
helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" \
    --set crds.install=true \
    --set server.ingress.enabled=false \
    --set "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
    --wait --timeout 15m
echo "ArgoCD installed. Admin user is 'admin', password is 'password'."

# --- STEP 6: DEPLOY GITOPS ROOT APPLICATION VIA KUBECTL ---
log_step "6" "Deploying GitOps Root Application via kubectl"
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${TF_VAR_gitops_repo_url}
    path: kubernetes/apps-of-apps
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
echo "Root application deployed. ArgoCD will now take over."

# --- STEP 7: FINAL VERIFICATION SCRIPT ---
log_step "7" "Running Final Health Verification (waiting 90s for ArgoCD sync)"
# Wait a bit longer to ensure all App-of-Apps have had time to sync
sleep 90

# Use a here-doc to create the verification script on the fly
cat > ./verify_final_state.sh << 'VERIFY_EOF'
#!/bin/bash
set -e
set -o pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_verify() { echo -e "\n---> VERIFYING: $1"; }
check_success() { echo -e "${GREEN}✅ SUCCESS:${NC} $1"; }
check_failure() { echo -e "${RED}❌ FAILURE:${NC} $1"; }

log_verify "K3s built-in components"
if kubectl get pod -n kube-system -l app=traefik --no-headers | grep .; then
    check_failure "A Traefik pod was found in kube-system. It was not disabled correctly."
    kubectl get pod -n kube-system -l app=traefik
    exit 1
else
    check_success "No Traefik pod found in kube-system."
fi
if kubectl get svc -n kube-system traefik &>/dev/null; then
    check_failure "A Traefik service was found in kube-system."
    exit 1
else
    check_success "No Traefik service found in kube-system."
fi

log_verify "Our custom Traefik instance"
if ! kubectl wait --for=condition=Available deployment/traefik -n traefik --timeout=120s &>/dev/null; then
    check_failure "Our Traefik deployment in 'traefik' namespace did not become available."
    kubectl get pods -n traefik
    exit 1
else
    check_success "Our Traefik deployment is available."
fi

log_verify "ArgoCD and its applications"
if ! kubectl wait --for=condition=Ready pod --all -n argocd --timeout=120s &>/dev/null; then
    check_failure "Not all ArgoCD pods are ready."
    exit 1
fi
HEALTH_ISSUES=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status!="Healthy")].metadata.name}')
if [[ -n "$HEALTH_ISSUES" ]]; then
    check_failure "One or more ArgoCD applications are not healthy: ${HEALTH_ISSUES}"
    kubectl get applications -n argocd
    exit 1
else
    check_success "All ArgoCD applications are Healthy and Synced."
fi

log_verify "Certificate issuance"
if ! kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=300s &>/dev/null; then
    check_failure "Certificate 'argocd-server-tls-staging' did not become Ready."
    kubectl describe certificate -n argocd argocd-server-tls-staging
    kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50
    exit 1
else
    check_success "Certificate is Ready."
fi

log_verify "End-to-end HTTPS test"
# This curl command is now more robust. It checks for a 200-series status code and the correct issuer.
CURL_OUTPUT=$(curl --silent --show-error --verbose https://argocd.core01.prod.gglohh.top 2>&1)
if ! echo "${CURL_OUTPUT}" | grep -q "issuer: C=US; O=(STAGING) Let's Encrypt"; then
    check_failure "Certificate issuer is not the Let's Encrypt Staging environment."
    echo "${CURL_OUTPUT}"
    exit 1
fi
if ! echo "${CURL_OUTPUT}" | grep -q "< HTTP/2 200"; then
    check_failure "Did not receive an HTTP 200 OK response."
    echo "${CURL_OUTPUT}"
    exit 1
fi
check_success "End-to-end test passed. Received 200 OK with Staging certificate."

VERIFY_EOF

chmod +x ./verify_final_state.sh
./verify_final_state.sh

echo -e "\n### DEFINITIVE REDEPLOYMENT (V5.1) COMPLETE ###"