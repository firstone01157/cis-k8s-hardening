# PSS Audit Verification - Exact Commands

## Verify Your Setup

Run these commands to verify your PSS audit scripts are correctly configured:

### 1. Check Current Namespace Labels
```bash
# View all namespaces with labels
kubectl get ns --show-labels

# View just the namespace names and their PSS labels
kubectl get ns -o json | jq '.items[] | {name: .metadata.name, pss_labels: {enforce: .metadata.labels["pod-security.kubernetes.io/enforce"], warn: .metadata.labels["pod-security.kubernetes.io/warn"], audit: .metadata.labels["pod-security.kubernetes.io/audit"]}}'

# Count namespaces with at least one PSS label
kubectl get ns -o json | jq '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] or .metadata.labels["pod-security.kubernetes.io/warn"] or .metadata.labels["pod-security.kubernetes.io/audit"])] | length'

# Count namespaces WITHOUT any PSS label
kubectl get ns -o json | jq '[.items[] | select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and (.metadata.labels["pod-security.kubernetes.io/audit"] == null))] | length'
```

### 2. The Exact JQ Query Used in Audit Scripts
```bash
# This is the EXACT query that audit scripts use to find non-compliant namespaces
kubectl get ns -o json | jq -r '.items[] | 
  select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | 
  select(
    (.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/audit"] == null)
  ) | 
  .metadata.name'

# Result interpretation:
# - EMPTY OUTPUT = All namespaces compliant = PASS
# - NAMESPACE NAMES = Those namespaces need labels = FAIL
```

### 3. Manual Audit Check (Do This Yourself)
```bash
#!/bin/bash
# This is exactly what the audit scripts do

# Step 1: Get namespace data
ns_json=$(kubectl get ns -o json)

# Step 2: Find namespaces without any PSS label
missing_labels=$(echo "$ns_json" | jq -r '.items[] | 
  select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | 
  select(
    (.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/audit"] == null)
  ) | 
  .metadata.name')

# Step 3: Evaluate result
if [ -n "$missing_labels" ]; then
    echo "[FAIL] These namespaces are missing PSS labels:"
    echo "$missing_labels"
    exit 1
else
    echo "[PASS] All namespaces have PSS labels (enforce/warn/audit)"
    exit 0
fi
```

### 4. Fix Non-Compliant Namespaces
```bash
# Option A: Label all namespaces at once
kubectl label namespace --all \
  pod-security.kubernetes.io/warn=baseline \
  --overwrite

# Option B: Label specific namespaces
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
    if [ "$ns" != "kube-system" ] && [ "$ns" != "kube-public" ]; then
        kubectl label namespace "$ns" \
          pod-security.kubernetes.io/warn=baseline \
          --overwrite
    fi
done

# Option C: Run the remediation script
bash Level_1_Master_Node/5.2.1_remediate.sh
```

### 5. Verify Fix Works
```bash
# Re-run the audit
bash Level_1_Master_Node/5.2.1_audit.sh

# Expected output:
# [+] PASS
# - Check Passed: All non-system namespaces have PSS labels (enforce/warn/audit)
```

## Understanding the Logic

### What Gets PASSED
Any namespace (except kube-system, kube-public) that has:
```
✅ pod-security.kubernetes.io/enforce=restricted
✅ pod-security.kubernetes.io/enforce=baseline
✅ pod-security.kubernetes.io/warn=restricted
✅ pod-security.kubernetes.io/warn=baseline
✅ pod-security.kubernetes.io/audit=restricted
✅ pod-security.kubernetes.io/audit=baseline
✅ Any combination of the above (multiple labels)
```

### What Gets FAILED
Any namespace (except kube-system, kube-public) that has:
```
❌ No PSS labels at all
❌ Only non-PSS labels
❌ PSS labels with value "unrestricted"
```

## One-Liner Health Check

Check compliance without running full audit script:
```bash
# If this returns nothing, all namespaces are compliant
kubectl get ns -o json | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and (.metadata.labels["pod-security.kubernetes.io/audit"] == null)) | .metadata.name'

# If this returns namespace names, those need labels
```

## Kubernetes API Check

Using raw Kubernetes API if kubectl JSON output isn't available:
```bash
# Get namespace details via API
curl -k -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc.cluster.local/api/v1/namespaces \
  | jq '.items[] | {name: .metadata.name, labels: .metadata.labels}'
```

## Troubleshooting Commands

### Check if jq is installed
```bash
jq --version
# If not:
apt-get install -y jq
```

### Check if kubectl works
```bash
kubectl cluster-info
kubectl get ns
```

### Test jq with simple query
```bash
kubectl get ns -o json | jq '.items[] | .metadata.name'
# Should list all namespace names
```

### Debug: Show full namespace labels
```bash
kubectl get ns -o json | jq '.items[] | {name: .metadata.name, all_labels: .metadata.labels}'
```

### Debug: Show only PSS labels
```bash
kubectl get ns -o json | jq '.items[] | {
  name: .metadata.name,
  enforce: .metadata.labels["pod-security.kubernetes.io/enforce"],
  warn: .metadata.labels["pod-security.kubernetes.io/warn"],
  audit: .metadata.labels["pod-security.kubernetes.io/audit"]
}'
```

## Performance Test

Time how long the audit takes:
```bash
time bash Level_1_Master_Node/5.2.1_audit.sh

# Typical output:
# real    0m0.850s
# user    0m0.250s
# sys     0m0.100s
```

## Batch Audit All PSS Scripts

Run all PSS audits in one go:
```bash
cd Level_1_Master_Node

echo "Running all PSS audits..."
failed=0
passed=0

for script in 5.2.{1,2,3,4,5,6,8,10,11,12}_audit.sh; do
    echo "=== Testing $script ==="
    if bash "$script" > /dev/null 2>&1; then
        echo "✓ PASS"
        ((passed++))
    else
        echo "✗ FAIL"
        ((failed++))
    fi
done

echo ""
echo "Summary: $passed passed, $failed failed"
```

## Safety Mode Validation

Ensure you're in Safety Mode correctly:
```bash
# Check if PSA admission plugin is enabled
kubectl get deployment -n kube-system | grep -i pod-security

# Check for warnings in kubectl output
kubectl create pod --image=nginx -o yaml --dry-run | kubectl apply -f - -n default --validate=warn

# Check audit logs for PSS events
journalctl -u kubelet -f | grep -i "pod-security"
```

---

**These are the exact commands used by the audit scripts.**
**Use them to verify your setup is correct before running full audits.**
