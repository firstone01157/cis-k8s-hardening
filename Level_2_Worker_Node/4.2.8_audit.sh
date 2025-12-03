#!/bin/bash
set -xe

# CIS Benchmark: 4.2.8
# Title: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)
# Level: Level 2 - Worker Node
# Description: Verify that eventRecordQPS is configured appropriately for event logging

SCRIPT_NAME="4.2.8_audit.sh"
echo "[INFO] Starting CIS Benchmark check: 4.2.8"
echo "[INFO] This is a MANUAL CHECK - eventRecordQPS should be reviewed for appropriateness"

# Initialize variables
audit_passed=true
failure_reasons=()
details=()

# Verify kubelet is running
echo "[INFO] Checking kubelet process..."
if ! ps -ef | grep -v grep | grep -q "kubelet"; then
    echo "[FAIL] kubelet process is not running"
    exit 1
fi

echo "[INFO] Checking kubelet eventRecordQPS configuration..."
# Extract eventRecordQPS from kubelet arguments
event_qps=$(ps -ef | grep -v grep | grep "kubelet" | tr ' ' '\n' | grep -A1 "^--event-record-qps$" | tail -1 || echo "NOT_FOUND")

if [ "$event_qps" = "NOT_FOUND" ] || [ -z "$event_qps" ]; then
    echo "[INFO] eventRecordQPS not explicitly set - using default value of 5"
    details+=("eventRecordQPS: Using default value (5)")
    echo "[INFO] Default of 5 events per second is generally acceptable"
else
    echo "[DEBUG] Extracted eventRecordQPS: $event_qps"
    details+=("eventRecordQPS: $event_qps")
    
    # Check if the value seems reasonable (between 0 and 100 for most deployments)
    if [ "$event_qps" -lt 1 ] || [ "$event_qps" -gt 1000 ]; then
        echo "[WARN] eventRecordQPS value may be outside recommended range: $event_qps"
        failure_reasons+=("eventRecordQPS appears to be misconfigured: $event_qps")
        audit_passed=false
    else
        echo "[PASS] eventRecordQPS is set to: $event_qps"
    fi
fi

# Final report
echo ""
echo "==============================================="
echo "[INFO] CIS 4.2.8 Audit Results:"
echo "Details:"
for detail in "${details[@]}"; do
    echo "  - $detail"
done

if [ "$audit_passed" = true ]; then
    echo "[PASS] CIS 4.2.8: eventRecordQPS appears to be appropriately configured"
    echo "[INFO] Recommended values:"
    echo "  - Low-traffic clusters: 5-10 QPS"
    echo "  - Medium-traffic clusters: 15-25 QPS"
    echo "  - High-traffic clusters: 50+ QPS"
    exit 0
else
    echo "[FAIL] CIS 4.2.8: eventRecordQPS may be misconfigured"
    echo "Reasons:"
    for reason in "${failure_reasons[@]}"; do
        echo "  - $reason"
    done
    exit 1
fi
