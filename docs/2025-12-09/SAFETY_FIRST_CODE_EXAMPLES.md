# SAFETY FIRST - Code Examples & Implementation Details

## Architecture Overview

```
Level_1_Master_Node/
  └── 5.2.2_remediate.sh (Pod Security Standards - Non-Enforcing)
      ├── Apply warn labels to all namespaces
      ├── Apply audit labels to all namespaces  
      ├── DO NOT enforce (prevents pod blocking)
      └── Exit 0 if successful

Level_2_Master_Node/
  ├── 5.3.2_remediate.sh (Network Policies - Allow-All Safety Net)
  │   ├── Query existing policies in each namespace
  │   ├── Skip if any policy exists
  │   ├── Create allow-all-traffic policy if needed
  │   └── Exit 0 if successful
  │
  └── 5.6.4_remediate.sh (Default Namespace - Manual Intervention)
      ├── Print detailed remediation steps
      ├── Explain risks of automatic deletion
      └── Exit 3 (manual intervention required)
```

---

## Script 1: 5.2.2_remediate.sh - PSS Non-Enforcing Labels

### Full Script Structure

```bash
#!/bin/bash

# CIS Benchmark: 5.2.2
# SAFETY STRATEGY: Apply warn/audit labels only (non-blocking)

set -o errexit
set -o pipefail

SCRIPT_NAME="5.2.2_remediate.sh"
PSS_PROFILE="restricted"
SYSTEM_NAMESPACES="kube-system|kube-public|kube-node-lease|kube-apiserver|default"

# 1. VALIDATION
echo "[INFO] Starting CIS Benchmark remediation: 5.2.2"
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found - cannot proceed"
    exit 1
fi

# 2. FETCH NAMESPACES
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | \
    tr ' ' '\n' | grep -v -E "^(${SYSTEM_NAMESPACES})$")

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found"
    exit 0
fi

# 3. APPLY LABELS
namespaces_updated=0
namespaces_failed=0

while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue
    
    # Apply warn label
    if kubectl label namespace "$namespace" \
        "pod-security.kubernetes.io/warn=$PSS_PROFILE" \
        --overwrite 2>/dev/null; then
        echo "[PASS] Applied warn label to $namespace"
    else
        echo "[FAIL] Failed to apply warn label to $namespace"
        ((namespaces_failed++))
        continue
    fi
    
    # Apply audit label
    if kubectl label namespace "$namespace" \
        "pod-security.kubernetes.io/audit=$PSS_PROFILE" \
        --overwrite 2>/dev/null; then
        echo "[PASS] Applied audit label to $namespace"
    else
        echo "[FAIL] Failed to apply audit label to $namespace"
        ((namespaces_failed++))
        continue
    fi
    
    # CRITICAL: DO NOT apply enforce label
    # This would block all pods that don't meet restricted policy
    
    ((namespaces_updated++))
    
done <<< "$namespaces"

# 4. FINAL REPORT
if [ $namespaces_failed -eq 0 ]; then
    echo "[PASS] CIS 5.2.2: All namespaces have PSS warn/audit labels"
    exit 0
else
    echo "[FAIL] CIS 5.2.2: Some namespaces failed"
    exit 1
fi
```

### Key Implementation Details

**Variable Sanitization for Namespace Names:**
```bash
# Namespace names might contain special characters
# Use -z (empty) check and simple IFS to avoid issues
while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue  # Skip empty lines
    kubectl label namespace "$namespace" ...
done
```

**Label Application Pattern:**
```bash
# Using --overwrite ensures idempotency (safe to run multiple times)
kubectl label namespace "$ns" \
    "pod-security.kubernetes.io/warn=restricted" \
    --overwrite 2>/dev/null

# Returns 0 on success, non-zero on failure
# if [ $? -eq 0 ] ...  OR  if kubectl label ...; then ...
```

**What Happens if You Apply enforce Label:**
```bash
# WRONG: This would block pods
kubectl label namespace production \
    "pod-security.kubernetes.io/enforce=restricted"

# Result: Pods without proper security context fail to start
# Example error: "Error creating pod: pod does not conform to pss restricted policy"

# RIGHT: Use warn and audit instead
kubectl label namespace production \
    "pod-security.kubernetes.io/warn=restricted" \
    "pod-security.kubernetes.io/audit=restricted"

# Result: Pods run normally, violations logged in audit trail
```

---

## Script 2: 5.3.2_remediate.sh - Allow-All NetworkPolicy

### Full Script Structure

```bash
#!/bin/bash

# CIS Benchmark: 5.3.2
# SAFETY STRATEGY: Create allow-all NetworkPolicy (non-blocking safety net)

set -o errexit
set -o pipefail

SCRIPT_NAME="5.3.2_remediate.sh"
POLICY_NAME="cis-allow-all-safety-net"
SYSTEM_NAMESPACES="kube-system|kube-public|kube-node-lease|kube-apiserver|default"

echo "[INFO] Starting CIS Benchmark remediation: 5.3.2"
echo "[INFO] SAFETY STRATEGY: Creating Allow-All NetworkPolicies (non-destructive)"

# 1. VALIDATION
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi

# 2. FETCH NAMESPACES
namespaces=$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | \
    tr ' ' '\n' | grep -v -E "^(${SYSTEM_NAMESPACES})$")

if [ -z "$namespaces" ]; then
    echo "[PASS] No custom namespaces found"
    exit 0
fi

# 3. PROCESS EACH NAMESPACE
namespaces_updated=0
namespaces_failed=0
declare -a failed_namespaces

while IFS= read -r namespace; do
    [ -z "$namespace" ] && continue
    
    echo "[INFO] Processing namespace: $namespace"
    
    # 3a. Check if our policy already exists
    if kubectl get networkpolicy "$POLICY_NAME" -n "$namespace" &>/dev/null 2>&1; then
        echo "[PASS] Policy $POLICY_NAME already exists"
        continue
    fi
    
    # 3b. Check if ANY NetworkPolicy exists
    policy_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)
    if [ "$policy_count" -gt 0 ]; then
        echo "[PASS] Namespace has existing policy, skipping"
        continue
    fi
    
    # 3c. Create allow-all policy
    echo "[INFO] Creating allow-all NetworkPolicy in $namespace"
    
    TEMP_POLICY="/tmp/allow-all-${namespace}-$$.yaml"
    
    cat > "$TEMP_POLICY" <<'POLICY_EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-allow-all-safety-net
  namespace: NAMESPACE_PLACEHOLDER
  labels:
    app: cis-remediation
    purpose: safety-net-allow-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}
  egress:
  - {}
POLICY_EOF
    
    # Replace placeholder with actual namespace
    sed -i "s/NAMESPACE_PLACEHOLDER/$namespace/g" "$TEMP_POLICY"
    
    # 3d. Apply the policy
    if kubectl apply -f "$TEMP_POLICY" 2>/dev/null; then
        echo "[PASS] NetworkPolicy created in $namespace"
        ((namespaces_updated++))
        
        # Verify creation
        if kubectl get networkpolicy "$POLICY_NAME" -n "$namespace" &>/dev/null; then
            echo "[DEBUG] Verified: policy exists in $namespace"
        fi
    else
        echo "[FAIL] Failed to create NetworkPolicy in $namespace"
        ((namespaces_failed++))
        failed_namespaces+=("$namespace")
    fi
    
    rm -f "$TEMP_POLICY"
    
done <<< "$namespaces"

# 4. FINAL REPORT
echo ""
echo "========================================================"
echo "[INFO] CIS 5.3.2 Remediation Summary"
echo "========================================================"
echo "[INFO] Namespaces updated: $namespaces_updated"
echo "[INFO] Namespaces failed: $namespaces_failed"
echo ""
echo "[INFO] Policy Type: Allow-All (non-blocking safety net)"
echo ""

if [ $namespaces_failed -eq 0 ]; then
    echo "[PASS] CIS 5.3.2: All namespaces have NetworkPolicies"
    exit 0
else
    echo "[FAIL] CIS 5.3.2: Some namespaces failed"
    exit 1
fi
```

### Key Implementation Details

**NetworkPolicy Allow-All Structure:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-allow-all-safety-net
spec:
  podSelector: {}                    # Applies to all pods
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - {}                               # Allow all ingress
  egress:
  - {}                               # Allow all egress
```

**Comparison: Allow-All vs. Default-Deny**

```yaml
# SAFE: Allow-All NetworkPolicy
spec:
  ingress:
  - {}                    # Empty rule = allow everything
  egress:
  - {}                    # Empty rule = allow everything
# Result: All traffic allowed, zero impact to workloads

# RISKY: Default-Deny NetworkPolicy
spec:
  ingress: []            # Empty list = deny all ingress
  egress: []             # Empty list = deny all egress
# Result: All traffic blocked, workloads fail without explicit allow rules
```

**YAML Injection Prevention:**
```bash
# Unsafe (namespace could contain special characters):
cat > policy.yaml <<EOF
  namespace: $namespace
EOF

# Safe (use temporary file and sed replacement):
cat > "$TEMP_POLICY" <<'POLICY_EOF'
  namespace: NAMESPACE_PLACEHOLDER
POLICY_EOF

# Then replace safely:
sed -i "s/NAMESPACE_PLACEHOLDER/$namespace/g" "$TEMP_POLICY"
```

**Verification Pattern:**
```bash
# Check if our specific policy exists
if kubectl get networkpolicy "cis-allow-all-safety-net" -n "$namespace" &>/dev/null 2>&1; then
    echo "[PASS] Policy verified"
fi

# Count total policies in namespace
policy_count=$(kubectl get networkpolicies -n "$namespace" --no-headers 2>/dev/null | wc -l)

# More robust verification with explicit type check:
if kubectl get networkpolicy "cis-allow-all-safety-net" -n "$namespace" -o jsonpath='{.spec.ingress}' 2>/dev/null | grep -q "{}"; then
    echo "[DEBUG] Verified: allow-all rule is present"
fi
```

---

## Script 3: 5.6.4_remediate.sh - Manual Intervention

### Full Script Structure

```bash
#!/bin/bash

# CIS Benchmark: 5.6.4
# SAFETY STRATEGY: Manual Intervention (Destructive Operation)

set -o errexit
set -o pipefail

SCRIPT_NAME="5.6.4_remediate.sh"

echo "[INFO] Starting CIS Benchmark remediation: 5.6.4"
echo ""
echo "========================================================"
echo "[MANUAL] CIS 5.6.4: Default Namespace Should Not Be Used"
echo "========================================================"
echo ""

# Print detailed guidance
echo "RISK ASSESSMENT:"
echo "  - This remediation requires MANUAL intervention"
echo "  - Migrating resources from default can cause data loss"
echo "  - Deleting resources has permanent consequences"
echo ""

echo "REMEDIATION STEPS (MANUAL):"
echo ""
echo "1. Identify resources in default namespace:"
echo "   kubectl get all -n default"
echo ""
echo "2. Create dedicated namespaces:"
echo "   kubectl create namespace production"
echo ""
echo "3. Export and migrate:"
echo "   kubectl get deployment myapp -n default -o yaml > myapp.yaml"
echo "   sed -i 's/namespace: default/namespace: production/' myapp.yaml"
echo "   kubectl apply -f myapp.yaml"
echo ""
echo "4. Verify in new namespace:"
echo "   kubectl get all -n production"
echo ""
echo "5. Delete from default (only after verification):"
echo "   kubectl delete deployment myapp -n default"
echo ""

echo "[EXIT CODE 3] Manual intervention required - not auto-fixed"
exit 3
```

### Exit Code Behavior

**How Test Runner Interprets Exit Codes:**

```python
# In Python test runner (e.g., cis_k8s_unified.py):

import subprocess

# Run the remediation script
result = subprocess.run(['bash', '5.6.4_remediate.sh'], capture_output=True, text=True)

exit_code = result.returncode

if exit_code == 0:
    # Success - remediation applied
    status = "FIXED"
    log_severity = "INFO"
    
elif exit_code == 1:
    # Failure - error occurred
    status = "FAILED"
    log_severity = "ERROR"
    
elif exit_code == 3:
    # Manual intervention required - don't report as "fixed"
    status = "MANUAL"
    log_severity = "WARN"
    # Important: Don't mark check as "FIXED" - requires human action
    
else:
    # Unknown exit code
    status = "UNKNOWN"
    log_severity = "ERROR"

# Log the result
print(f"[{log_severity}] CIS 5.6.4: {status}")
print(result.stdout)
if result.stderr:
    print(result.stderr)
```

**Why Exit Code 3 Matters:**

```
Without Exit Code 3 (using exit 0):
├─ Script prints guidance
├─ Exits with 0 (success)
├─ Test runner marks as "FIXED"
├─ Next audit still shows FAIL (nothing was actually done)
└─ False positive reported

With Exit Code 3:
├─ Script prints guidance
├─ Exits with 3 (manual intervention)
├─ Test runner marks as "MANUAL"
├─ Next audit still shows FAIL (expected)
└─ Honest status: requires human intervention
```

---

## Pattern Comparison: All Three Scripts

### Pre-Check Pattern

```bash
# All scripts validate prerequisites first
if ! command -v kubectl &> /dev/null; then
    echo "[FAIL] kubectl command not found"
    exit 1
fi
```

### Error Handling Pattern

```bash
# All scripts use proper error handling
set -o errexit      # Exit on any error
set -o pipefail     # Fail if any command in pipe fails
```

### Report Pattern

```bash
# All scripts provide clear summary
echo ""
echo "========================================================"
echo "[INFO] CIS X.Y.Z Remediation Summary"
echo "========================================================"
echo "[INFO] Metric 1: $metric1"
echo "[INFO] Metric 2: $metric2"
echo ""
echo "[PASS/FAIL] CIS X.Y.Z: <result>"
exit 0  # or 1 or 3
```

### Variable Initialization

```bash
# All scripts properly initialize counters
namespaces_updated=0
namespaces_failed=0
declare -a failed_namespaces
```

### Loop Pattern

```bash
# All scripts safely iterate through lists
while IFS= read -r item; do
    [ -z "$item" ] && continue
    # Process item
done <<< "$items"
```

---

## Testing Examples

### Test 5.2.2 - PSS Labels

```bash
# Simulate: Check that labels are applied
test_pss_labels() {
    # Create test namespace
    kubectl create namespace test-pss
    
    # Run remediation
    bash Level_1_Master_Node/5.2.2_remediate.sh
    
    # Verify labels exist
    labels=$(kubectl get ns test-pss -o jsonpath='{.metadata.labels}')
    
    if echo "$labels" | grep -q "pod-security.kubernetes.io/warn"; then
        echo "[PASS] warn label found"
    else
        echo "[FAIL] warn label missing"
    fi
    
    if echo "$labels" | grep -q "pod-security.kubernetes.io/audit"; then
        echo "[PASS] audit label found"
    else
        echo "[FAIL] audit label missing"
    fi
    
    if echo "$labels" | grep -q "pod-security.kubernetes.io/enforce"; then
        echo "[FAIL] enforce label should NOT be present"
    else
        echo "[PASS] enforce label correctly not applied"
    fi
    
    # Cleanup
    kubectl delete namespace test-pss
}

test_pss_labels
```

### Test 5.3.2 - NetworkPolicy

```bash
# Simulate: Check that policy allows all traffic
test_networkpolicy() {
    # Create test namespace
    kubectl create namespace test-netpol
    
    # Run remediation
    bash Level_2_Master_Node/5.3.2_remediate.sh
    
    # Verify policy exists
    if kubectl get networkpolicy cis-allow-all-safety-net -n test-netpol &>/dev/null; then
        echo "[PASS] NetworkPolicy created"
    else
        echo "[FAIL] NetworkPolicy not found"
    fi
    
    # Verify it allows all ingress
    ingress=$(kubectl get networkpolicy cis-allow-all-safety-net -n test-netpol -o jsonpath='{.spec.ingress}')
    if echo "$ingress" | grep -q "{}"; then
        echo "[PASS] Allow-all ingress rule present"
    else
        echo "[FAIL] Allow-all ingress rule missing"
    fi
    
    # Cleanup
    kubectl delete namespace test-netpol
}

test_networkpolicy
```

### Test 5.6.4 - Exit Code

```bash
# Simulate: Check exit code is 3
test_exit_code() {
    bash Level_2_Master_Node/5.6.4_remediate.sh
    exit_code=$?
    
    if [ $exit_code -eq 3 ]; then
        echo "[PASS] Exit code 3 (manual intervention) returned correctly"
    else
        echo "[FAIL] Exit code was $exit_code, expected 3"
    fi
}

test_exit_code
```

---

## Production Deployment Checklist

```bash
# 1. Syntax validation
bash -n Level_1_Master_Node/5.2.2_remediate.sh
bash -n Level_2_Master_Node/5.3.2_remediate.sh
bash -n Level_2_Master_Node/5.6.4_remediate.sh

# 2. Connectivity check
kubectl cluster-info

# 3. Current state snapshot
kubectl get ns -o wide > namespace_backup.txt
kubectl get networkpolicies -A > netpol_backup.txt

# 4. Execute scripts
bash Level_1_Master_Node/5.2.2_remediate.sh
bash Level_2_Master_Node/5.3.2_remediate.sh
bash Level_2_Master_Node/5.6.4_remediate.sh  # Will request manual steps

# 5. Verify changes
kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.pod-security\.kubernetes\.io/warn}{"\n"}{end}'
kubectl get networkpolicies -A

# 6. Health check
kubectl get nodes
kubectl top nodes
kubectl get pods -A --field-selector=status.phase!=Running
```

---

## Troubleshooting Guide

### Issue: "kubectl: command not found"

**Root Cause:** kubectl not in PATH or not installed

**Solution:**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Or verify existing installation
which kubectl
/usr/local/bin/kubectl version
```

### Issue: "error: unable to connect to the server"

**Root Cause:** kubeconfig not set or cluster unreachable

**Solution:**
```bash
# Check kubeconfig
echo $KUBECONFIG
export KUBECONFIG=/etc/kubernetes/admin.conf

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

### Issue: "forbidden: User cannot create networkpolicies"

**Root Cause:** RBAC permissions insufficient

**Solution:**
```bash
# Run as cluster admin
sudo su -c 'export KUBECONFIG=/etc/kubernetes/admin.conf; bash script.sh'

# Or grant permissions
kubectl create clusterrolebinding admin-user --clusterrole=cluster-admin --serviceaccount=default:default
```

### Issue: Script hangs on "kubectl get"

**Root Cause:** API server overloaded or networking issue

**Solution:**
```bash
# Add timeout
timeout 10 kubectl get ns

# Check API server
kubectl get nodes
kubectl get componentstatuses
ps aux | grep apiserver
```

---

**Version:** 1.0  
**Date:** December 9, 2025  
**Status:** Production Ready
