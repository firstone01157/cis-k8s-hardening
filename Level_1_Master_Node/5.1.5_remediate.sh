#!/bin/bash
# CIS Benchmark: 5.1.5
# Title: Ensure that default service accounts are not actively used
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
echo "[INFO] Remediating 5.1.5..."

# 2. Pre-Check
# Manual check.

# 3. Apply Fix
echo "[WARN] Manual intervention required: Set automountServiceAccountToken: false for default service accounts."
echo "[INFO] Run: kubectl patch serviceaccount default -p '{\"automountServiceAccountToken\": false}'"

# 4. Verification
exit 0
