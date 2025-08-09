#!/bin/bash

# ==============================================================================
#      The Final Chapter: Sequential GitOps Bootstrapping Script (v6.0)
# ==============================================================================
# v6.0 Philosophy:
# - Abandon complex App-of-Apps and Sync-Waves.
# - The script takes full control of the deployment sequence.
# - Each critical component (Cert-Manager, Traefik) is deployed and its
#   health is VERIFIED before the next component is deployed.
# - This command-driven, sequential approach is the ultimate guarantee for success
#   in complex, dependency-heavy GitOps bootstrapping.
# ==============================================================================

set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="redeploy_all_v6.0_$(date +%Y%m%d_%H%M%S).log"
INFRA_DIR="01-infra"
ARGOCD_NS="argocd"
ARGOCD_CHART_VERSION="6.7.15"
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

# --- Helper Functions ---
log_step() {
    echo -e "\n# ============================================================================== #" | tee -a "${LOG_FILE}"
    echo "# STEP $1: $2" | tee -a "${LOG_FILE}"
    echo -e "# ============================================================================== #\n" | tee -a "${LOG_FILE}"
}

apply_argo_app() {
    local app_name=$1
    local app_path=$2
    echo "--> Applying ArgoCD Application: ${app_name}"
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${app_name}
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${TF_VAR_gitops_repo_url}
    path: ${app_path}
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    # Destination namespace is managed by the app itself via syncOptions
    namespace: ${app_name}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
}

# --- Script Start ---
> "${LOG_FILE}"
exec &> >(tee -a "${LOG_FILE}")

echo "### FINAL CHAPTER DEPLOYMENT (V6.0) INITIATED AT $(date) ###"

# --- STEP 1 & 2: Cleanup ---
log_step "1 & 2" "Performing Full Remote and Local Cleanup"
# (Cleanup steps are correct, keeping them as is)
ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" 'if [ -f /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi; if [ "$(docker ps -q -f name=core-etcd)" ]; then docker stop core-etcd && docker rm core-etcd; fi; rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /run/k3s /opt/etcd'
rm -rf "${INFRA_DIR}/.terraform" "${INFRA_DIR}/.terraform.lock.hcl" "${INFRA_DIR}/terraform.tfstate*"

# --- STEP 3: Deploy Infrastructure ---
log_step "3" "Deploying Pure K3s Infrastructure via Terraform"
cd "${INFRA_DIR}"
terraform init -upgrade
terraform apply -auto-approve
cd ..

# --- STEP 4: Configure Kubeconfig & Wait for API Server ---
log_step "4" "Configuring Kubeconfig and Waiting for API Server"
RAW_KUBECONFIG=$(ssh -i "${SSH_KEY_PATH_EXPANDED}" -o StrictHostKeyChecking=no "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "cat /etc/rancher/k3s/k3s.yaml")
PROCESSED_KUBECONFIG=$(echo "${RAW_KUBECONFIG}" | sed "s/127.0.0.1/${API_SERVER_FQDN}/")
mkdir -p ~/.kube && echo "${PROCESSED_KUBECONFIG}" > ~/.kube/config && chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
kubectl wait --for=condition=Ready node --all --timeout=${CLUSTER_API_WAIT_TIMEOUT}

# --- STEP 5: Install ArgoCD Core ---
log_step "5" "Installing ArgoCD Core via Helm CLI"
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm || echo "Repo exists."
helm repo update
helm install argocd argo/argo-cd --version "${ARGOCD_CHART_VERSION}" --namespace "${ARGOCD_NS}" \
    --set crds.install=true \
    --set "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}" \
    --wait --timeout 15m

# --- STEP 6: SEQUENTIAL GITOPS BOOTSTRAP ---
log_step "6.1" "Deploying Cert-Manager and WAITING for it to be healthy"
apply_argo_app "cert-manager" "kubernetes/applications/cert-manager.yaml"
# Wait for the CRDs to be established by the controller
kubectl wait --for condition=established --timeout=120s crd/certificates.cert-manager.io
kubectl wait --for condition=established --timeout=120s crd/clusterissuers.cert-manager.io
# Wait for the deployment to be fully available
kubectl wait --for=condition=Available deployment -n cert-manager --all --timeout=300s
echo "--> Cert-Manager is confirmed HEALTHY."

log_step "6.2" "Deploying Traefik and WAITING for it to be healthy"
apply_argo_app "traefik" "kubernetes/applications/traefik.yaml"
# Wait for the CRDs to be established
kubectl wait --for condition=established --timeout=120s crd/ingressroutes.traefik.io
# Wait for the deployment to be fully available
kubectl wait --for=condition=Available deployment -n traefik --all --timeout=300s
echo "--> Traefik is confirmed HEALTHY."

log_step "6.3" "Deploying Core Manifests (Issuers, Ingresses, etc.)"
apply_argo_app "core-manifests" "kubernetes/applications/manifests.yaml"
# Give it a moment to sync
sleep 15
echo "--> Core manifests application deployed."

# --- STEP 7: FINAL VERIFICATION ---
log_step "7" "Running Final Verification"
# The verification script from v5.1 is already robust enough. We'll reuse its logic.
cat > ./verify_final_state.sh << 'VERIFY_EOF'
#!/bin/bash
set -e
set -o pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_verify() { echo -e "\n---> VERIFYING: $1"; }
check_success() { echo -e "${GREEN}✅ SUCCESS:${NC} $1"; }
check_failure() { echo -e "${RED}❌ FAILURE:${NC} $1"; exit 1; }

log_verify "All ArgoCD applications are Healthy and Synced"
HEALTH_ISSUES=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.health.status}{"\n"}{end}' | grep -v "Healthy")
SYNC_ISSUES=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\n"}{end}' | grep -v "Synced")
if [[ -n "$HEALTH_ISSUES" || -n "$SYNC_ISSUES" ]]; then
    check_failure "One or more ArgoCD applications are not healthy/synced."
    echo "Health Issues:"
    echo "${HEALTH_ISSUES:-None}"
    echo "Sync Issues:"
    echo "${SYNC_ISSUES:-None}"
else
    check_success "All ArgoCD applications are Healthy and Synced."
fi

log_verify "Certificate has been issued successfully"
if ! kubectl wait --for=condition=Ready certificate/argocd-server-tls-staging -n argocd --timeout=300s; then
    check_failure "Certificate 'argocd-server-tls-staging' did not become Ready."
    kubectl describe certificate -n argocd argocd-server-tls-staging
    kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=50
fi
check_success "Certificate is Ready."

log_verify "End-to-end HTTPS test for https://argocd.core01.prod.gglohh.top"
CURL_OUTPUT=$(curl --silent --show-error --verbose https://argocd.core01.prod.gglohh.top 2>&1)
if ! echo "${CURL_OUTPUT}" | grep -q "issuer: C=US; O=(STAGING) Let's Encrypt"; then
    check_failure "Certificate issuer is not the Let's Encrypt Staging environment."
    echo "${CURL_OUTPUT}"
fi
if ! echo "${CURL_OUTPUT}" | grep -q "< HTTP/2 200"; then
    check_failure "Did not receive an HTTP 200 OK response."
    echo "${CURL_OUTPUT}"
fi
check_success "End-to-end test passed. Received 200 OK with Staging certificate."
VERIFY_EOF

chmod +x ./verify_final_state.sh
./verify_final_state.sh

echo -e "\n### FINAL CHAPTER DEPLOYMENT (V6.0) COMPLETE ###"
echo "### Your cluster is ready. ArgoCD UI: https://argocd.core01.prod.gglohh.top ###"