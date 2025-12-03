#!/bin/bash
set -xe

# CIS Benchmark: 5.4.1
# Title: Prefer using secrets as files over secrets as environment variables (Manual)
# Level: Level 2 - Master Node
# Description: Check if Secrets are mounted as files rather than environment variables

SCRIPT_NAME="5.4.1_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 5.4.1"
echo "[INFO] This is a MANUAL CHECK - requires human review"

# Initialize variables
audit_passed=true
failure_reasons=()
resources_with_secret_env=()

# Verify kubectl is available
echo "[INFO] Checking if kubectl is available..."
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

echo "[INFO] Searching for resources using secrets as environment variables..."
# Find all resources that use secretKeyRef (secrets as env vars)
echo "[DEBUG] Querying all resources with secretKeyRef..."
secret_env_resources=$(kubectl get all -A -o jsonpath='{range .items[?(@..secretKeyRef)]}{.kind}{" "}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

if [ -n "$secret_env_resources" ]; then
    echo "[WARN] Found resources using secretKeyRef (secrets as env variables):"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "[DEBUG] Resource: $line"
        resources_with_secret_env+=("$line")
        audit_passed=false
    done <<< "$secret_env_resources"
else
    echo "[INFO] No resources found using secretKeyRef (secrets as env variables)"
fi

# Final report
echo ""
echo "==============================================="
if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 5.4.1: No resources using secrets as environment variables found"
    echo "[INFO] Best practice: All secrets should be mounted as files in volumes"
    exit 0
else
    echo "[FAIL] CIS 5.4.1: Found resources using secrets as environment variables"
    echo "Resources requiring remediation:"
    for resource in "${resources_with_secret_env[@]}"; do
        echo "  - $resource"
    done
    echo ""
    echo "[INFO] Manual fix: Mount secrets as files instead of env variables:"
    echo "  volumes:"
    echo "  - name: secret-volume"
    echo "    secret:"
    echo "      secretName: my-secret"
    echo ""
    echo "  volumeMounts:"
    echo "  - name: secret-volume"
    echo "    mountPath: /etc/secrets"
    exit 1
fi
