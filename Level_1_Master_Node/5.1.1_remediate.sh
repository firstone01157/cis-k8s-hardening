#!/bin/bash
# CIS Benchmark: 5.1.1
# Title: Ensure that the cluster-admin role is only used where necessary
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
echo "[INFO] Remediating 5.1.1..."

# 2. Pre-Check
# Manual check.

# 3. Apply Fix
echo "[WARN] Manual intervention required: Review ClusterRoleBindings for 'cluster-admin' and remove unnecessary subjects."
echo "[INFO] Run: kubectl get clusterrolebindings -o=custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECT:.subjects[*].name | grep cluster-admin"

# 4. Verification
exit 0
