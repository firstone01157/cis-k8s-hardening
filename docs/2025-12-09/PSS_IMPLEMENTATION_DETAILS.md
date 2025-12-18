# PSS Audit Scripts - Implementation Details

## Architecture Overview

All CIS 5.2.x audit scripts follow a unified pattern for namespace PSS compliance checking.

### Core Logic Flow

```
1. Initialize Variables
   └─ a_output (pass results)
   └─ a_output2 (fail results)

2. Verify Prerequisites
   ├─ Check kubectl availability
   └─ Check jq availability

3. Fetch Namespace Data
   └─ kubectl get ns -o json

4. Filter Missing PSS Labels
   └─ jq query to find namespaces without any of three labels:
       ├─ pod-security.kubernetes.io/enforce
       ├─ pod-security.kubernetes.io/warn
       └─ pod-security.kubernetes.io/audit

5. Evaluate Result
   ├─ If namespaces found → FAIL (return 1)
   └─ If no namespaces found → PASS (return 0)

6. Output Audit Report
   └─ Standard CIS format with [+] PASS or [-] FAIL
```

## JQ Filter Breakdown

The core jq filter used in all Level 1 scripts:

```jq
.items[] | 
  select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | 
  select(
    (.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and 
    (.metadata.labels["pod-security.kubernetes.io/audit"] == null)
  ) | 
  .metadata.name
```

### Step-by-Step Breakdown

1. `.items[]`
   - Iterate through each namespace

2. `select(.metadata.name != "kube-system" and .metadata.name != "kube-public")`
   - EXCLUDE system namespaces
   - Keep only user namespaces

3. `select((.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and ...)`
   - Find namespaces where ALL three labels are NULL
   - This selects the PROBLEMATIC namespaces (those WITHOUT labels)

4. `.metadata.name`
   - Output only the namespace name

### Result Interpretation

**If jq returns empty** (no namespaces):
- ✅ PASS - All namespaces have at least one PSS label
- Exit code: 0

**If jq returns namespace names**:
- ❌ FAIL - Those namespaces are missing all PSS labels
- Exit code: 1

## Label Presence Examples

### Scenario 1: PASS ✅
```yaml
Namespace: production
Labels:
  pod-security.kubernetes.io/enforce: restricted
  pod-security.kubernetes.io/warn: restricted
  pod-security.kubernetes.io/audit: restricted
```
Query result: NOT SELECTED (has enforce label) → PASS

### Scenario 2: PASS ✅
```yaml
Namespace: staging
Labels:
  pod-security.kubernetes.io/warn: baseline
```
Query result: NOT SELECTED (has warn label) → PASS

### Scenario 3: PASS ✅
```yaml
Namespace: dev
Labels:
  pod-security.kubernetes.io/audit: baseline
```
Query result: NOT SELECTED (has audit label) → PASS

### Scenario 4: FAIL ❌
```yaml
Namespace: default
Labels: {}
```
Query result: SELECTED (all three are null) → FAIL

### Scenario 5: FAIL ❌
```yaml
Namespace: app
Labels:
  other-label: value
```
Query result: SELECTED (no PSS labels) → FAIL

## Bash Wrapper Logic

```bash
# Execute jq query
missing_labels=$(echo "$ns_json" | jq -r '...')

# Test if any results returned
if [ -n "$missing_labels" ]; then
    # String is not empty = namespaces found = FAIL
    return 1
else
    # String is empty = no namespaces found = PASS
    return 0
fi
```

## Implementation Verification

All Level 1 PSS scripts follow this exact pattern:

```bash
audit_rule() {
    # Setup
    echo "[INFO] Starting check for X.X.X..."
    
    # Prerequisites
    if ! command -v kubectl &> /dev/null; then
        return 2  # ERROR
    fi
    if ! command -v jq &> /dev/null; then
        return 2  # ERROR
    fi
    
    # Fetch
    ns_json=$(kubectl get ns -o json 2>/dev/null)
    
    # Filter
    missing_labels=$(echo "$ns_json" | jq -r '.items[] | 
        select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | 
        select(
            (.metadata.labels["pod-security.kubernetes.io/enforce"] == null) and 
            (.metadata.labels["pod-security.kubernetes.io/warn"] == null) and 
            (.metadata.labels["pod-security.kubernetes.io/audit"] == null)
        ) | 
        .metadata.name')
    
    # Evaluate
    if [ -n "$missing_labels" ]; then
        echo "[INFO] Check Failed"
        # ... output failures ...
        return 1
    else
        echo "[INFO] Check Passed"
        # ... output success ...
        return 0
    fi
}
```

## Exit Codes

All scripts use standard exit codes:

| Code | Meaning | Example |
|------|---------|---------|
| 0 | PASS ✅ | All namespaces have PSS labels |
| 1 | FAIL ❌ | Some namespaces missing labels |
| 2 | ERROR ⚠️ | kubectl/jq not found or command error |

## Output Format - PASS Example

```
[INFO] Starting check for 5.2.1...
[CMD] Executing: # Verify kubectl and jq are available
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without any PSS label (enforce/warn/audit)
[INFO] Check Passed
- Audit Result:
  [+] PASS
  - Check Passed: All non-system namespaces have PSS labels (enforce/warn/audit)
```

## Output Format - FAIL Example

```
[INFO] Starting check for 5.2.1...
[CMD] Executing: # Verify kubectl and jq are available
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without any PSS label (enforce/warn/audit)
[INFO] Check Failed
- Audit Result:
  [-] FAIL
  - Reason(s) for audit failure:
  - Check Failed: The following namespaces are missing PSS labels (enforce/warn/audit):
  - default
  - logging
  - monitoring
```

## Covered Scripts

### Configuration Verified

```
✅ Level_1_Master_Node/5.2.1_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.2_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.3_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.4_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.5_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.6_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.8_audit.sh   - Multi-label check
✅ Level_1_Master_Node/5.2.10_audit.sh  - Multi-label check
✅ Level_1_Master_Node/5.2.11_audit.sh  - Multi-label check
✅ Level_1_Master_Node/5.2.12_audit.sh  - Multi-label check

ℹ️  Level_2_Master_Node/5.2.7_audit.sh  - Pod-level check (runAsNonRoot)
ℹ️  Level_2_Master_Node/5.2.9_audit.sh  - Pod-level check (capabilities)
```

## SQL-Style Pseudocode

For those who prefer thinking in SQL terms:

```sql
SELECT namespace.name
FROM kubernetes.namespaces AS namespace
WHERE namespace.name NOT IN ('kube-system', 'kube-public')
AND (
    namespace.labels['pod-security.kubernetes.io/enforce'] IS NULL
    AND namespace.labels['pod-security.kubernetes.io/warn'] IS NULL
    AND namespace.labels['pod-security.kubernetes.io/audit'] IS NULL
);

IF result_count > 0 THEN
    RETURN FAIL (1)
ELSE
    RETURN PASS (0)
END IF
```

## Performance Characteristics

- **Time Complexity**: O(n) where n = number of namespaces
- **Typical Execution**: < 1 second for clusters with < 100 namespaces
- **Memory Usage**: Minimal (single JSON document + label comparisons)
- **Network Calls**: 
  - 1 × kubectl get ns -o json
  - 1 × jq filter (local processing)

## Troubleshooting Guide

### Symptom: "jq: command not found"
```bash
# Fix: Install jq
sudo apt-get install -y jq
# or
sudo yum install -y jq
```

### Symptom: "kubectl: command not found"
```bash
# Fix: Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Symptom: "error: unable to connect to the server"
```bash
# Fix: Ensure kubeconfig is set
export KUBECONFIG=/path/to/kubeconfig
# or for local cluster
export KUBECONFIG=~/.kube/config
```

### Symptom: "Unable to connect to the server: EOF"
```bash
# Fix: Verify cluster is running
kubectl cluster-info
kubectl get nodes
```

## Security Considerations

1. **Label Visibility**: PSS labels are readable by all users via `kubectl get ns --show-labels`
2. **Label Modification**: Users with namespace edit permissions can modify labels
3. **No Built-in Audit**: PSS label changes are not automatically audited
4. **Remediation Trust**: Assumes remediation scripts are run with proper RBAC permissions

## Testing the Implementation

### Manual Test 1: Create Non-Compliant Namespace
```bash
kubectl create namespace test-no-pss
bash 5.2.1_audit.sh
# Expected: FAIL - "test-no-pss" listed as missing labels
```

### Manual Test 2: Fix with Label
```bash
kubectl label ns test-no-pss pod-security.kubernetes.io/warn=baseline
bash 5.2.1_audit.sh
# Expected: PASS - "test-no-pss" now has label
```

### Manual Test 3: All Three Labels
```bash
kubectl label ns test-no-pss \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=baseline \
  --overwrite
bash 5.2.1_audit.sh
# Expected: PASS - Multiple labels still satisfies check
```

---

**Implementation Status**: ✅ Complete and Verified
**Kubernetes Version**: 1.25+ (PSS GA)
**Configuration**: Safety Mode Ready (enforce/warn/audit)
**Last Updated**: December 9, 2025
