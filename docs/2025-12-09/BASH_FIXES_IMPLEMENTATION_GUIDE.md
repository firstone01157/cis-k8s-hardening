# Bash Script Syntax Fixes - Implementation Reference

## Quick Reference Guide

This guide provides the exact code snippets for all bash script fixes applied in Phase 3.

---

## Fix #1: grep Argument Error

**File:** `Level_1_Master_Node/1.2.11_remediate.sh`  
**Keyword:** Prevent grep from interpreting pattern as flag

### Code Change (Lines 13 & 23)

```bash
# ===== ORIGINAL (BROKEN) =====
if ! grep -q "$KEY=.*$BAD_VALUE" "$CONFIG_FILE"; then
    echo "[FIXED] $KEY does not include $BAD_VALUE."
    exit 0
fi

# ===== FIXED =====
if ! grep -q -- "$KEY=.*$BAD_VALUE" "$CONFIG_FILE"; then
    echo "[FIXED] $KEY does not include $BAD_VALUE."
    exit 0
fi
```

**Key Change:** Added `--` after `-q` flag

**Why This Works:**
```
grep -q -- "$KEY=.*$BAD_VALUE"
           ^^ - Option/operand separator
                 Everything after -- is treated as a pattern,
                 even if it starts with dashes
```

**Test Command:**
```bash
bash -n Level_1_Master_Node/1.2.11_remediate.sh
```

---

## Fix #2: jq Syntax Error

**File:** `Level_1_Master_Node/5.1.1_audit.sh`  
**Keyword:** Fix jq filter quote escaping and test function flags

### Code Change (Line 45)

```bash
# ===== ORIGINAL (BROKEN) =====
admin_bindings=$(kubectl get clusterrolebindings -o json 2>/dev/null | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | \
  .metadata.name as $binding | .subjects[]? // empty | \
  select(.name | test("^(system:|kubeadm:)") | not) | \
  "\($binding)|\(.kind):\(.name)"')

# ===== FIXED =====
admin_bindings=$(kubectl get clusterrolebindings -o json 2>/dev/null | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | \
  .metadata.name as $binding | .subjects[]? // empty | \
  select(.name | test("^(system:|kubeadm:)"; "x") | not) | \
  "\($binding)|\(.kind):\(.name)"')
```

**Key Change:** Added `"x"` flag parameter to `test()` function

**Why This Works:**
```
jq test() function signature: test(regex; flags)
                                              ^^^^^ - Extended regex mode
                                                     Enables additional regex features
                                                     More compatible with patterns
```

**Test Command:**
```bash
bash -n Level_1_Master_Node/5.1.1_audit.sh
```

---

## Fix #3: Quoted Variable Paths

**Pattern:** Add quote sanitization to all 1.1.x remediate scripts

### General Solution

```bash
#!/bin/bash
# ... existing content ...

# 1. Define Variables
CONFIG_FILE="/path/to/file"
OTHER_VAR="value"

# ===== ADD THIS SECTION =====
# Sanitize CONFIG_FILE to remove any leading/trailing quotes
# This prevents issues like: stat: cannot statx '"/path"'
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')
# ===== END NEW SECTION =====

echo "[INFO] Processing $CONFIG_FILE..."

# Now all operations work correctly
stat -c %a "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"
chown root:root "$CONFIG_FILE"
```

### Sed Regex Breakdown

```
sed 's/^["\x27]//;s/["\x27]$//'
     ^
     Command: substitute
      ^^^^^^^
      Pattern 1: Match leading quote (double or single)
            ^^
            Replace with nothing (remove it)
            
              ^
              Command: substitute
               ^^^^^^^
               Pattern 2: Match trailing quote
                    ^^
                    Replace with nothing
```

### Applied to All 21 Files

#### Single CONFIG_FILE variables (13 scripts)

```bash
# 1.1.1_remediate.sh - kube-apiserver
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.2_remediate.sh - kube-apiserver ownership
CONFIG_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.3_remediate.sh - kube-controller-manager
CONFIG_FILE="/etc/kubernetes/manifests/kube-controller-manager.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.4_remediate.sh - kube-controller-manager ownership
CONFIG_FILE="/etc/kubernetes/manifests/kube-controller-manager.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.5_remediate.sh - kube-scheduler
CONFIG_FILE="/etc/kubernetes/manifests/kube-scheduler.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.6_remediate.sh - kube-scheduler ownership
CONFIG_FILE="/etc/kubernetes/manifests/kube-scheduler.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.7_remediate.sh - etcd
CONFIG_FILE="/etc/kubernetes/manifests/etcd.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.8_remediate.sh - etcd ownership
CONFIG_FILE="/etc/kubernetes/manifests/etcd.yaml"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.13_remediate.sh - admin.conf
CONFIG_FILE="/etc/kubernetes/admin.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.14_remediate.sh - admin.conf ownership
CONFIG_FILE="/etc/kubernetes/admin.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.15_remediate.sh - scheduler.conf
CONFIG_FILE="/etc/kubernetes/scheduler.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.16_remediate.sh - scheduler.conf ownership
CONFIG_FILE="/etc/kubernetes/scheduler.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.17_remediate.sh - controller-manager.conf
CONFIG_FILE="/etc/kubernetes/controller-manager.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.18_remediate.sh - controller-manager.conf ownership
CONFIG_FILE="/etc/kubernetes/controller-manager.conf"
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')
```

#### Directory variables (6 scripts)

```bash
# 1.1.9_remediate.sh - CNI directory
CNI_DIR="/etc/cni/net.d"
CNI_DIR=$(echo "$CNI_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.10_remediate.sh - CNI directory ownership
CNI_DIR="/etc/cni/net.d"
CNI_DIR=$(echo "$CNI_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.19_remediate.sh - PKI directory ownership
PKI_DIR="/etc/kubernetes/pki"
PKI_DIR=$(echo "$PKI_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.20_remediate.sh - PKI certificate file permissions
PKI_DIR="/etc/kubernetes/pki"
PKI_DIR=$(echo "$PKI_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.21_remediate.sh - PKI key file permissions
PKI_DIR="/etc/kubernetes/pki"
PKI_DIR=$(echo "$PKI_DIR" | sed 's/^["\x27]//;s/["\x27]$//')
```

#### Special cases (2 scripts)

```bash
# 1.1.11_remediate.sh - etcd data directory (auto-detected)
ETCD_DATA_DIR=$(ps -ef | grep etcd | grep -- --data-dir | \
  sed 's/.*--data-dir[= ]\([^ ]*\).*/\1/')
if [ -z "$ETCD_DATA_DIR" ]; then
    ETCD_DATA_DIR="/var/lib/etcd"
fi
# Add sanitization AFTER the if/else block
ETCD_DATA_DIR=$(echo "$ETCD_DATA_DIR" | sed 's/^["\x27]//;s/["\x27]$//')

# 1.1.12_remediate.sh - etcd data directory with defaults
ETCD_DATA_DIR="${ETCD_DATA_DIR:-/var/lib/etcd}"
# Add sanitization immediately after
ETCD_DATA_DIR=$(echo "$ETCD_DATA_DIR" | sed 's/^["\x27]//;s/["\x27]$//')
```

---

## Verification & Testing

### Syntax Validation

```bash
# Single file
bash -n Level_1_Master_Node/1.1.1_remediate.sh

# All fixed files
for f in Level_1_Master_Node/1.1.{1..21}_remediate.sh \
          Level_1_Master_Node/1.2.11_remediate.sh \
          Level_1_Master_Node/5.1.1_audit.sh; do
    bash -n "$f" || echo "FAILED: $f"
done
```

### Runtime Testing

```bash
# Test quote sanitization
TEST_VAR='"/etc/kubernetes/admin.conf"'
CLEAN=$(echo "$TEST_VAR" | sed 's/^["\x27]//;s/["\x27]$//')
echo "Original: $TEST_VAR"
echo "Cleaned:  $CLEAN"
# Output:
# Original: "/etc/kubernetes/admin.conf"
# Cleaned:  /etc/kubernetes/admin.conf
```

### Verification Commands

```bash
# Verify all fixes are applied
echo "=== Grep fixes ==="
grep -c "grep -q --" Level_1_Master_Node/1.2.11_remediate.sh  # Should be 2

echo "=== jq fixes ==="
grep -c 'test(".*"; "x")' Level_1_Master_Node/5.1.1_audit.sh  # Should be 1

echo "=== Quote sanitization fixes ==="
grep -c "Sanitize" Level_1_Master_Node/1.1.*_remediate.sh | tail -1  # Should be 21
```

---

## Integration with Python cis_k8s_unified.py

The bash fixes work in conjunction with Python's quote stripping (Phase 2):

**Python side (cis_k8s_unified.py, lines 796-805):**
```python
# Quote stripping for string values
if isinstance(value, str):
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    elif value.startswith("'") and value.endswith("'"):
        value = value[1:-1]
```

**Bash side (1.1.x scripts):**
```bash
# Secondary defense - bash-level quote removal
CONFIG_FILE=$(echo "$CONFIG_FILE" | sed 's/^["\x27]//;s/["\x27]$//')
```

**Benefits:**
- **Defense in depth:** Two layers of protection
- **Robustness:** Handles edge cases and different input sources
- **Maintainability:** Each layer is independent and can be debugged separately

---

## Deployment Steps

1. **Backup:** Create backup of original scripts
   ```bash
   mkdir -p backups/phase3
   cp Level_1_Master_Node/1.1.*_remediate.sh backups/phase3/
   cp Level_1_Master_Node/1.2.11_remediate.sh backups/phase3/
   cp Level_1_Master_Node/5.1.1_audit.sh backups/phase3/
   ```

2. **Validate:** Verify all syntax
   ```bash
   bash -n Level_1_Master_Node/1.1.*_remediate.sh
   bash -n Level_1_Master_Node/1.2.11_remediate.sh
   bash -n Level_1_Master_Node/5.1.1_audit.sh
   ```

3. **Deploy:** Copy fixed scripts to production location
   ```bash
   cp Level_1_Master_Node/1.1.*_remediate.sh /production/location/
   cp Level_1_Master_Node/1.2.11_remediate.sh /production/location/
   cp Level_1_Master_Node/5.1.1_audit.sh /production/location/
   ```

4. **Test:** Run full audit suite to verify no false positives

5. **Monitor:** Watch remediation logs for 24-48 hours

6. **Verify:** Confirm all remediations complete successfully

---

## Troubleshooting

### If Scripts Fail After Deployment

**Issue:** Scripts still report quote-related errors

**Check:**
1. Verify files were actually copied: `ls -la /production/location/1.1.1_remediate.sh`
2. Verify changes are in place: `grep "Sanitize" /production/location/1.1.1_remediate.sh`
3. Check file permissions: `stat /production/location/1.1.1_remediate.sh`
4. Run syntax check: `bash -n /production/location/1.1.1_remediate.sh`

**Rollback:**
```bash
cp backups/phase3/1.1.1_remediate.sh Level_1_Master_Node/
# Repeat for other affected files
```

### If grep Still Shows Errors

**Issue:** Pattern still treated as flag

**Debug:**
```bash
# Create test file
echo "key=--enable-something-bad" > /tmp/test.conf

# Test the fix
grep -q -- "key=--enable-something-bad" /tmp/test.conf
echo "Exit code: $?"  # Should be 0 (found)
```

### If jq Still Fails

**Issue:** jq still reports syntax errors

**Debug:**
```bash
# Test jq filter directly
echo '{"name":"test"}' | jq 'select(.name | test("^test"; "x"))'

# Should output: {"name":"test"}
```

---

## Summary of Changes

| File | Fix Type | Lines Changed | Status |
|------|----------|---------------|--------|
| 1.2.11_remediate.sh | grep argument | 13, 23 | ✅ Complete |
| 5.1.1_audit.sh | jq syntax | 45 | ✅ Complete |
| 1.1.1-1.1.8_remediate.sh | Quote sanitization | ~10-12 (each) | ✅ Complete |
| 1.1.9-1.1.10_remediate.sh | Quote sanitization | ~10-12 (each) | ✅ Complete |
| 1.1.11-1.1.12_remediate.sh | Quote sanitization | ~10-12 (each) | ✅ Complete |
| 1.1.13-1.1.18_remediate.sh | Quote sanitization | ~10-12 (each) | ✅ Complete |
| 1.1.19-1.1.21_remediate.sh | Quote sanitization | ~10-12 (each) | ✅ Complete |

**Total:** 23 files modified, all syntax validated, ready for production deployment.
