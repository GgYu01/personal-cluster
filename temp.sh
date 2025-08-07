#!/bin/bash

# ==============================================================================
#           Post-Deployment Health Verification Script (v1.0)
# ==============================================================================
# This script performs a comprehensive, non-interactive verification of the
# entire deployment stack, from Ingress to Application, and logs all findings.
#
# USAGE: ./verify_deployment_health.sh
# ==============================================================================

# --- Strict Error Handling & Configuration ---
set -e
set -o pipefail

# --- Configuration ---
LOG_FILE="deployment_health_check_$(date +%Y%m%d_%H%M%S).log"
EXPECTED_DOMAIN="argocd.core01.prod.gglohh.top"
ARGOCD_NS="argocd"
CERT_MANAGER_NS="cert-manager"
KUBE_SYSTEM_NS="kube-system"
EXPECTED_CERT_SECRET_NAME="argocd-server-tls-staging"

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Helper Functions ---
log_step() {
    echo -e "\n# ============================================================================== #"
    echo "# STEP $1: $2"
    echo -e "# ============================================================================== #\n"
}

check_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

check_failure() {
    echo -e "${RED}❌ FAILURE:${NC} $1"
    # Optional: exit on first failure
    # exit 1 
}

# --- Script Start ---
# Redirect all output to log file and console
> "${LOG_FILE}"
exec &> >(tee -a "${LOG_FILE}")

echo "### DEPLOYMENT HEALTH VERIFICATION INITIATED AT $(date) ###"

# --- STEP 1: Verify Kubeconfig and Basic Connectivity ---
log_step "1" "Verifying Kubeconfig and Cluster Connectivity"
if ! kubectl version &> /dev/null; then
    check_failure "Cannot connect to the Kubernetes cluster. Check your ~/.kube/config file."
    exit 1
fi
check_success "Successfully connected to the Kubernetes cluster."
echo "--- Cluster Nodes:"
kubectl get nodes -o wide

# --- STEP 2: Verify Traefik (Ingress Controller) State ---
log_step "2" "Verifying Traefik Ingress Controller State"
echo "--- Checking for Traefik pods ONLY in '${KUBE_SYSTEM_NS}'..."
if ! kubectl get pod -n "${KUBE_SYSTEM_NS}" -l app=traefik &> /dev/null; then
    check_failure "No Traefik pod found in '${KUBE_SYSTEM_NS}'."
else
    check_success "Found Traefik pod running in '${KUBE_SYSTEM_NS}' as expected."
    kubectl get pod -n "${KUBE_SYSTEM_NS}" -l app=traefik
fi

echo "--- Confirming NO Traefik namespace or pods exist..."
if kubectl get namespace traefik &> /dev/null; then
    check_failure "A 'traefik' namespace still exists, which is unexpected. Please check ArgoCD's 'core-services' app."
    kubectl get all -n traefik
else
    check_success "The dedicated 'traefik' namespace does not exist, as expected."
fi

# --- STEP 3: Verify ArgoCD State ---
log_step "3" "Verifying ArgoCD Application State"
echo "--- Checking status of all pods in '${ARGOCD_NS}' namespace..."
if ! kubectl wait --for=condition=Ready pod --all -n "${ARGOCD_NS}" --timeout=60s; then
    check_failure "Not all pods in '${ARGOCD_NS}' are ready."
    kubectl get pods -n "${ARGOCD_NS}"
else
    check_success "All pods in '${ARGOCD_NS}' are running and ready."
fi

echo "--- Checking the sync status of all ArgoCD Applications..."
# The 'jq' tool is great for this, but using kubectl's jsonpath for portability
if kubectl get applications -n "${ARGOCD_NS}" -o jsonpath='{.items[*].status.sync.status}' | grep -v "Synced"; then
    check_failure "One or more ArgoCD Applications are not in 'Synced' state."
    kubectl get applications -n "${ARGOCD_NS}" -o wide
else
    check_success "All ArgoCD Applications are in 'Synced' state."
fi

# --- STEP 4: Verify Cert-Manager and Certificate Issuance ---
log_step "4" "Verifying Cert-Manager and Certificate Issuance"
echo "--- Checking the status of the IngressRoute for '${EXPECTED_DOMAIN}'..."
if ! kubectl get ingressroute -n "${ARGOCD_NS}" argocd-server-https &> /dev/null; then
    check_failure "IngressRoute 'argocd-server-https' not found in '${ARGOCD_NS}'."
else
    check_success "IngressRoute 'argocd-server-https' found."
    kubectl get ingressroute -n "${ARGOCD_NS}" argocd-server-https -o yaml
fi

echo "--- Checking for the existence of the Certificate resource..."
if ! kubectl get certificate -n "${ARGOCD_NS}" "${EXPECTED_CERT_SECRET_NAME}" &> /dev/null; then
    check_failure "Certificate resource '${EXPECTED_CERT_SECRET_NAME}' not found. This indicates Cert-Manager did not process the IngressRoute."
    echo "--- Last 50 lines of cert-manager logs:"
    kubectl logs -n "${CERT_MANAGER_NS}" -l app.kubernetes.io/name=cert-manager --tail=50
    exit 1
fi
check_success "Certificate resource '${EXPECTED_CERT_SECRET_NAME}' was created."

echo "--- Describing the Certificate to check its status..."
CERT_DESCRIBE=$(kubectl describe certificate -n "${ARGOCD_NS}" "${EXPECTED_CERT_SECRET_NAME}")
echo "${CERT_DESCRIBE}"

if ! echo "${CERT_DESCRIBE}" | grep -q "Certificate is valid"; then
    check_failure "Certificate is not yet valid."
    if echo "${CERT_DESCRIBE}" | grep -q "RateLimited"; then
        echo -e "${YELLOW}NOTE: The certificate issuance is currently rate-limited by Let's Encrypt. This is the root cause.${NC}"
    fi
else
    check_success "Certificate has been successfully issued and is valid."
fi

# --- STEP 5: End-to-End Test via HTTPS ---
log_step "5" "Performing End-to-End HTTPS Test for '${EXPECTED_DOMAIN}'"
echo "--- Performing verbose curl to check certificate issuer and response..."
# The --insecure flag is used because we are connecting to a staging issuer,
# which is not trusted by default. The -v flag lets us inspect the certificate.
CURL_OUTPUT=$(curl -v --insecure "https://${EXPECTED_DOMAIN}" 2>&1)

echo "${CURL_OUTPUT}"

echo "--- Analyzing curl results..."
# Check 1: Was the certificate from the Staging environment?
if ! echo "${CURL_OUTPUT}" | grep -q "issuer: C=US; O=\(STAGING\) Let's Encrypt"; then
    check_failure "The certificate was NOT issued by Let's Encrypt's Staging environment. It might be the default Traefik cert."
else
    check_success "Certificate was correctly issued by '(STAGING) Let's Encrypt'."
fi

# Check 2: Did we get a successful HTTP response (not a 404)?
# ArgoCD should return a 200 OK with a redirect in its body, or a 302 redirect.
if echo "${CURL_OUTPUT}" | grep -q "HTTP/2 404"; then
    check_failure "Received a '404 Not Found' response. Traefik is not routing the request to the ArgoCD service correctly."
    echo "--- Checking Traefik logs:"
    TRAEFIK_POD=$(kubectl get pod -n ${KUBE_SYSTEM_NS} -l app=traefik -o name | head -n1)
    kubectl logs -n "${KUBE_SYSTEM_NS}" "${TRAEFIK_POD}" --tail=50
else
    check_success "Received a valid HTTP response (not 404). Routing appears to be working."
fi

echo -e "\n### HEALTH VERIFICATION COMPLETE ###"
echo "### Please review the results above and in the log file: ${LOG_FILE} ###"