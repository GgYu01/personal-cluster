#!/usr/bin/env bash

# This script is designed to reproduce the K3s startup failure and
# immediately collect critical, low-level diagnostic data.

set -e # Exit on first error

readonly FULL_LOG_FILE="$(pwd)/full_diagnostic_log_$(date +%Y%m%d-%H%M%S).txt"
touch "${FULL_LOG_FILE}"

# Redirect all output of this script to the log file
exec &> >(tee -a "${FULL_LOG_FILE}")

echo "=============================================================================="
echo "INFO: Starting failure reproduction and data collection."
echo "INFO: Full log will be saved to: ${FULL_LOG_FILE}"
echo "=============================================================================="

# Step 1: Execute the original deploy script to trigger the failure.
# The 'trap' inside deploy.sh will handle the failure dump.
echo -e "\n\n--- [SECTION 1: RE-RUNNING deploy.sh to reproduce failure] ---\n"
if [ -f ./deploy.sh ]; then
    chmod +x ./deploy.sh
    # We expect this command to fail, so we use '|| true' to prevent this script from exiting.
    ./deploy.sh || true
else
    echo "ERROR: deploy.sh not found in the current directory. Aborting."
    exit 1
fi

# Step 2: Immediately after failure, collect critical system and service logs.
echo -e "\n\n--- [SECTION 2: COLLECTING K3S SERVICE JOURNAL LOGS] ---\n"
echo "--> Capturing logs for k3s.service since current boot..."
journalctl -u k3s.service --no-pager -b

echo -e "\n\n--- [SECTION 3: COLLECTING ETCD CONTAINER LOGS] ---\n"
echo "--> Capturing logs for the core-etcd container..."
docker logs core-etcd

echo -e "\n\n--- [SECTION 4: COLLECTING SYSTEM NETWORK CONFIGURATION] ---\n"
echo "--> Capturing network interface details..."
ip a

echo -e "\n\n--- [SECTION 5: COLLECTING KERNEL MESSAGES] ---\n"
echo "--> Capturing last 100 lines of kernel messages..."
dmesg | tail -n 100

echo "=============================================================================="
echo "INFO: Diagnostic data collection complete."
echo "INFO: Please provide the full content of the file: ${FULL_LOG_FILE}"
echo "=============================================================================="