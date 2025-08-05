#!/bin/bash

# ==============================================================================
#      Personal Cluster Granular & Unattended Deployment Tool (Final Version)
# ==============================================================================
# This script executes a fine-grained, step-by-step deployment.
# It is strictly non-interactive and exits immediately on any error.
#
# USAGE:
#   ./deploy.sh [function_name]
#
#   - If no [function_name] is provided, it runs ALL steps sequentially.
#   - If a [function_name] (e.g., 'apply_dns') is provided, it runs only that step.
# ==============================================================================

# --- Strict Error Handling ---
set -e
set -o pipefail

# --- ANSI Color Codes ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# --- Helper Function ---
function print_header() {
    echo -e "\n${BLUE}>>>${NC} ${CYAN}$1${NC}"
}

# ==============================================================================
#                          !!! USER CONFIGURATION !!!
# ==============================================================================
export TF_VAR_domain_name="gglohh.top"
export TF_VAR_site_code="core01"
export TF_VAR_environment="prod"
export TF_VAR_vps_ip="172.245.187.113"
export TF_VAR_ssh_user="root"
export TF_VAR_ssh_private_key_path="~/.ssh/id_rsa"
export TF_VAR_gitops_repo_url="https://github.com/GgYu01/personal-cluster.git"
export TF_VAR_cf_api_token="vi7hkPq4FwD5ttV4dvR_IoNVEJSphydRPcT0LVD-"
# ==============================================================================

# ------------------------------------------------------------------------------
#                        STAGE 1: INFRASTRUCTURE (01-infra)
# ------------------------------------------------------------------------------

function init_infra() {
    print_header "1.1: Initializing Infrastructure Workspace (01-infra)"
    cd 01-infra
    terraform init -upgrade
    terraform validate
    cd ..
}

function apply_dns() {
    print_header "1.2: Applying DNS Record"
    cd 01-infra
    terraform apply -target="cloudflare_dns_record.cluster_wildcard[0]" -auto-approve
    cd ..
}

function verify_dns() {
    print_header "1.3: Verifying DNS Record"
    echo "Waiting 10 seconds for DNS propagation..."
    sleep 10
    local test_domain="test.${TF_VAR_site_code}.${TF_VAR_environment}.${TF_VAR_domain_name}"
    echo "Querying A record for '${test_domain}' via 1.1.1.1..."
    local result
    result=$(dig @1.1.1.1 "${test_domain}" +short)
    echo "Result: ${result}"
    if [[ "$result" != "$TF_VAR_vps_ip" ]]; then
        echo -e "${RED}DNS Verification FAILED. Expected '${TF_VAR_vps_ip}', got '${result}'.${NC}"
        exit 1
    fi
    echo -e "${GREEN}DNS Verification PASSED.${NC}"
}

function apply_etcd() {
    print_header "1.4: Applying etcd Setup on VPS"
    cd 01-infra
    terraform apply -target=terraform_data.vps_setup -auto-approve
    cd ..
}

function verify_etcd() {
    print_header "1.5: Verifying etcd Container"
    local ssh_key_path
    ssh_key_path=$(eval echo "$TF_VAR_ssh_private_key_path")
    echo "Checking for running 'core-etcd' container..."
    if ! ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "docker ps | grep -q 'core-etcd'"; then
        echo -e "${RED}etcd container 'core-etcd' is not running on remote host.${NC}"
        ssh -i "$ssh_key_path" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${TF_VAR_ssh_user}@${TF_VAR_vps_ip}" "docker ps" # Show what is running
        exit 1
    fi
    echo -e "${GREEN}etcd container is running.${NC}"
}

function apply_k3s() {
    print_header "1.6: Applying K3s Installation"
    cd 01-infra
    terraform apply -target=terraform_data.k3s_install -auto-approve
    cd ..
}

function verify_k3s_outputs() {
    print_header "1.7: Verifying K3s Installation & Outputs"
    cd 01-infra
    echo "Refreshing state to fetch outputs..."
    terraform refresh
    echo "Checking for non-empty cluster_host output..."
    if [[ -z "$(terraform output -raw cluster_host)" ]]; then
        echo -e "${RED}K3s verification FAILED: 'cluster_host' output is empty.${NC}"
        exit 1
    fi
    echo -e "${GREEN}K3s outputs are available.${NC}"
    cd ..
}

# ------------------------------------------------------------------------------
#                          STAGE 2: APPLICATIONS (02-apps)
# ------------------------------------------------------------------------------

function init_apps() {
    print_header "2.1: Initializing Applications Workspace (02-apps)"
    if [ ! -f "01-infra/terraform.tfstate" ]; then
        echo -e "${RED}ERROR: '01-infra/terraform.tfstate' not found. Stage 1 must be completed first.${NC}"
        exit 1
    fi
    cd 02-apps
    terraform init -upgrade
    terraform validate
    cd ..
}

function apply_argocd_helm() {
    print_header "2.2: Applying ArgoCD Helm Release"
    cd 02-apps
    local cluster_base_domain
    cluster_base_domain=$(cd ../01-infra && terraform output -raw cluster_base_domain)
    terraform apply -target=helm_release.argocd -var="cluster_base_domain=${cluster_base_domain}" -auto-approve
    cd ..
}

function verify_argocd_crds() {
    print_header "2.3: Verifying ArgoCD CRDs are registered"
    echo "Generating temporary kubeconfig for verification..."
    cd 01-infra
    terraform output -raw kubeconfig_content > ../k3s-debug.yaml
    cd ..
    export KUBECONFIG="$(pwd)/k3s-debug.yaml"

    echo "Waiting for 'applications.argoproj.io' CRD to be available (up to 90s)..."
    local end_time=$((SECONDS+90))
    while ! kubectl get crd applications.argoproj.io > /dev/null 2>&1; do
        if [ $SECONDS -gt $end_time ]; then
            echo -e "${RED}Verification FAILED: Timed out waiting for ArgoCD CRDs.${NC}"
            kubectl get crds
            rm -f "$KUBECONFIG"
            unset KUBECONFIG
            exit 1
        fi
        sleep 5
    done
    
    echo -e "${GREEN}ArgoCD CRD 'applications.argoproj.io' is registered.${NC}"
    rm -f "$KUBECONFIG"
    unset KUBECONFIG
}

function apply_argocd_root_app() {
    print_header "2.4: Applying ArgoCD Root Application"
    cd 02-apps
    local cluster_base_domain
    cluster_base_domain=$(cd ../01-infra && terraform output -raw cluster_base_domain)
    terraform apply -target=kubernetes_manifest.app_of_apps -var="cluster_base_domain=${cluster_base_domain}" -auto-approve
    cd ..
}

function verify_deployment_complete() {
    print_header "2.5: Final Verification (Enhanced for Complex Deployments)"
    echo "Generating temporary kubeconfig for final check..."
    cd 01-infra
    terraform output -raw kubeconfig_content > ../k3s-debug.yaml
    cd ..
    export KUBECONFIG="$(pwd)/k3s-debug.yaml"

    # --- STAGE 1: Verify Critical Infrastructure (Longhorn StorageClass) ---
    echo "Waiting for 'longhorn' StorageClass to become available (up to 180s)..."
    local end_time=$((SECONDS+180))
    while ! kubectl get sc longhorn > /dev/null 2>&1; do
        if [ $SECONDS -gt $end_time ]; then
            echo -e "${RED}Verification FAILED: Timed out waiting for 'longhorn' StorageClass.${NC}"
            echo "Current StorageClasses:"
            kubectl get sc
            rm -f "$KUBECONFIG"
            unset KUBECONFIG
            exit 1
        fi
        echo "  'longhorn' StorageClass not found, retrying in 10 seconds..."
        sleep 10
    done
    echo -e "${GREEN}'longhorn' StorageClass is available.${NC}"

    # --- STAGE 2: Wait for all pods across key namespaces with a generous timeout ---
    # We now wait for a much longer period (10 minutes) because applications
    # like Minio and Casdoor depend on Longhorn and may take time to pull images and initialize.
    local total_timeout="600s"
    echo "Checking all pods status in argocd, traefik, longhorn-system, minio, casdoor namespaces (waiting up to ${total_timeout})..."
    
    # Wait for all deployments to be fully rolled out and available.
    # This is often more reliable than waiting for individual pods.
    if ! kubectl wait --for=condition=Available deployment --all --all-namespaces --timeout=${total_timeout}; then
        echo -e "${RED}Final verification FAILED: Not all Deployments are available after ${total_timeout}.${NC}"
        echo "Describing problematic pods..."
        # Find pods that are not ready and describe them for easier debugging
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running | grep -v "Completed" | awk 'NR>1 {print "-n "$1" "$2}' | xargs -L1 kubectl describe pod
        rm -f "$KUBECONFIG"
        unset KUBECONFIG
        exit 1
    fi

    echo -e "${GREEN}All Deployments are available.${NC}"

    # --- STAGE 3: Final Status Snapshot ---
    echo "Final cluster node status:"
    kubectl get nodes -o wide

    echo "Final pods status in key namespaces:"
    kubectl get pods -n argocd
    kubectl get pods -n traefik
    kubectl get pods -n longhorn-system
    
    rm -f "$KUBECONFIG"
    unset KUBECONFIG
}

# --- Main Execution Logic ---

# List of all functions to be called in order for a full deployment
ALL_STEPS=(
    init_infra
    # apply_dns
    # verify_dns
    apply_etcd
    verify_etcd
    apply_k3s
    verify_k3s_outputs
    init_apps
    apply_argocd_helm
    verify_argocd_crds
    apply_argocd_root_app
    verify_deployment_complete
)

# If a command-line argument is provided, try to run it as a function
if [ -n "$1" ]; then
    # Check if the provided argument is a valid function name in this script
    if declare -f "$1" > /dev/null; then
        # Call the function
        "$1"
        exit 0
    else
        echo -e "${RED}Error: Function '$1' not found.${NC}"
        echo "Available functions are:"
        # List all functions defined in the script
        declare -F | awk '{print $3}' | grep -v -E "^(print_header|main)$"
        exit 1
    fi
fi

# Default behavior: run all steps sequentially
print_header "🚀 STARTING FULL DEPLOYMENT 🚀"
for step in "${ALL_STEPS[@]}"; do
    # This calls each function name listed in the ALL_STEPS array
    "$step"
done
print_header "✅ DEPLOYMENT COMPLETE ✅"