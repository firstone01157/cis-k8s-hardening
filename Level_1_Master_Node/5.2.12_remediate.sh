#!/bin/bash
# CIS Benchmark: 5.2.12
# Title: Minimize the admission of containers which use HostPorts
# Level: Level 1 - Master Node
# Remediation Script

# 1. Define Variables
echo "[INFO] Remediating 5.2.12..."

# 2. Pre-Check
# Manual check.

# 3. Apply Fix
echo "[WARN] Manual intervention required: Remove HostPorts from pods where not required."

# 4. Verification
exit 0
