#!/bin/bash
# CIS Benchmark: 3.1.1
# Title: Client certificate authentication should not be used for users
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
# This is a manual check/organizational policy.
echo "[INFO] Remediating 3.1.1..."

# 2. Pre-Check
# We cannot automate checking "users" vs "service accounts" easily without external context.
# However, we can output a clear message.

# 3. Apply Fix
echo "[WARN] Manual intervention required: Ensure client certificate authentication is not used for users."
echo "[INFO] Review your PKI and kubeconfig distribution processes."

# 4. Verification
# Always exit 0 for manual checks to avoid blocking the runner, but log warning.
exit 0
