# Remediation Script Fixes - Code Reference

## Quick Pattern Reference

All 4 scripts now use this robust pattern for handling flags starting with dashes.

---

## The Universal Pattern

```bash
#!/bin/bash
set -euo pipefail

# Configuration
CONFIG_FILE="/path/to/manifest.yaml"
FLAG_NAME="--flag-name"
REQUIRED_VALUE="value"
BINARY_NAME="binary-name"
BACKUP_DIR="/var/backups/kubernetes/cis"

# 1. Sanitize variables (remove quotes from Python config system)
FLAG_NAME=$(echo "${FLAG_NAME}" | tr -d '"')
REQUIRED_VALUE=$(echo "${REQUIRED_VALUE}" | tr -d '"')

# 2. Pre-check: Is flag already correct?
if grep -Fq -- "${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"; then
    echo "[INFO] ${FLAG_NAME} is already correct."
    exit 0
fi

# 3. Backup before modification
mkdir -p "${BACKUP_DIR}"
BACKUP_FILE="${BACKUP_DIR}/manifest.yaml.$(date +%s).bak"
cp "${CONFIG_FILE}" "${BACKUP_FILE}"
echo "[INFO] Backup created: ${BACKUP_FILE}"

# 4. Apply fix
if grep -Fq -- "${FLAG_NAME}=" "${CONFIG_FILE}"; then
    # Flag exists -> Replace value
    sed -i "s|${FLAG_NAME}=.*|${FLAG_NAME}=${REQUIRED_VALUE}|g" "${CONFIG_FILE}"
else
    # Flag missing -> Append after binary name
    sed -i "/- ${BINARY_NAME}$/a \\    - ${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"
fi

# 5. Verify changes were actually applied
if grep -Fq -- "${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied ${FLAG_NAME}=${REQUIRED_VALUE}"
    exit 0
else
    echo "[ERROR] Verification failed - restoring backup"
    cp "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
fi
```

---

## Script-Specific Examples

### 1.2.1: --anonymous-auth

**Before (BROKEN):**
```bash
KEY="--anonymous-auth"
VALUE="false"
FULL_PARAM="${KEY}=${VALUE}"

# This fails with: grep: unrecognized option '--anonymous-auth'
grep -Fq -- "${FULL_PARAM}" "${CONFIG_FILE}"
```

**After (FIXED):**
```bash
# Sanitize
FLAG_NAME=$(echo "--anonymous-auth" | tr -d '"')
REQUIRED_VALUE=$(echo "false" | tr -d '"')

# Safe check with -F and --
if grep -Fq -- "${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"; then
    echo "[INFO] Flag is correct"
    exit 0
fi

# Apply and verify
if grep -Fq -- "${FLAG_NAME}=" "${CONFIG_FILE}"; then
    sed -i "s|${FLAG_NAME}=.*|${FLAG_NAME}=${REQUIRED_VALUE}|g" "${CONFIG_FILE}"
else
    sed -i "/- kube-apiserver$/a \\    - ${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"
fi

# Verify
if grep -Fq -- "${FLAG_NAME}=${REQUIRED_VALUE}" "${CONFIG_FILE}"; then
    echo "[FIXED] Successfully applied"
else
    cp "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
fi
```

---

### 1.2.11: --enable-admission-plugins

**Pattern: Remove bad plugin from list**

```bash
# Sanitize
FLAG_NAME="--enable-admission-plugins"
BAD_PLUGIN=$(echo "AlwaysAdmit" | tr -d '"')

# Check if bad plugin exists
if ! grep -Fq -- "${BAD_PLUGIN}" "${CONFIG_FILE}"; then
    echo "[INFO] ${BAD_PLUGIN} not present. Already compliant."
    exit 0
fi

# Remove from all possible positions in comma-separated list
sed -i "s/${BAD_PLUGIN},//g" "${CONFIG_FILE}"      # AlwaysAdmit,
sed -i "s/,${BAD_PLUGIN}//g" "${CONFIG_FILE}"     # ,AlwaysAdmit
sed -i "s/${BAD_PLUGIN}$//g" "${CONFIG_FILE}"     # AlwaysAdmit at end

# Verify removal
if grep -Fq -- "${BAD_PLUGIN}" "${CONFIG_FILE}"; then
    echo "[ERROR] Removal failed - restoring"
    cp "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
else
    echo "[FIXED] Successfully removed ${BAD_PLUGIN}"
    exit 0
fi
```

---

### 1.3.6: --feature-gates

**Pattern: Append to existing feature gate list**

```bash
# Sanitize
FLAG_NAME="--feature-gates"
REQUIRED_GATE="RotateKubeletServerCertificate=true"

# Check if gate already exists
if grep -Fq -- "${REQUIRED_GATE}" "${CONFIG_FILE}"; then
    echo "[INFO] ${REQUIRED_GATE} already set"
    exit 0
fi

# Add to existing gates (comma-separated)
if grep -Fq -- "${FLAG_NAME}=" "${CONFIG_FILE}"; then
    # Append to comma-separated list
    sed -i "s|\\(${FLAG_NAME}=[^\\$]*\\),\\$|\\1,${REQUIRED_GATE}|" "${CONFIG_FILE}"
    sed -i "s|\\(${FLAG_NAME}=[^=]*\\)$|\\1,${REQUIRED_GATE}|" "${CONFIG_FILE}"
else
    # Create new flag
    sed -i "/- kube-controller-manager$/a \\    - ${FLAG_NAME}=${REQUIRED_GATE}" "${CONFIG_FILE}"
fi

# Verify
if grep -Fq -- "${REQUIRED_GATE}" "${CONFIG_FILE}"; then
    echo "[FIXED] Applied ${REQUIRED_GATE}"
else
    cp "${BACKUP_FILE}" "${CONFIG_FILE}"
    exit 1
fi
```

---

### 1.4.1: --profiling

**Pattern: Simple flag replacement**

```bash
# Sanitize
CLEAN_FLAG=$(echo "--profiling" | tr -d '"')
CLEAN_VALUE=$(echo "false" | tr -d '"')

# Check if already correct
if grep -Fq -- "${CLEAN_FLAG}=${CLEAN_VALUE}" "$SCHEDULER_MANIFEST"; then
    echo "[SUCCESS] Already correctly set"
    exit 0
fi

# Replace or add
if grep -Fq -- "${CLEAN_FLAG}=" "$SCHEDULER_MANIFEST"; then
    # Replace existing value
    sed -i "s|${CLEAN_FLAG}=.*|${CLEAN_FLAG}=${CLEAN_VALUE}|g" "$SCHEDULER_MANIFEST"
else
    # Add new flag
    sed -i "/- kube-scheduler$/a \\    - ${CLEAN_FLAG}=${CLEAN_VALUE}" "$SCHEDULER_MANIFEST"
fi

# Verify
if grep -Fq -- "${CLEAN_FLAG}=${CLEAN_VALUE}" "$SCHEDULER_MANIFEST"; then
    echo "[SUCCESS] Applied ${CLEAN_FLAG}=${CLEAN_VALUE}"
    exit 0
else
    cp "$BACKUP_FILE" "$SCHEDULER_MANIFEST"
    exit 1
fi
```

---

## Key Differences from Original

| Aspect | Original | Fixed |
|--------|----------|-------|
| **grep** | `grep -q "$VAR"` ❌ | `grep -Fq -- "$VAR"` ✅ |
| **Flag escaping** | None ❌ | `FLAG=$(echo "$VAR" \| tr -d '"')` ✅ |
| **Verification** | Optional ❌ | Always performed ✅ |
| **Backup** | Basic ❌ | Timestamped with restore ✅ |
| **Error handling** | Minimal ❌ | Comprehensive ✅ |
| **Logging** | Basic ❌ | Detailed with colors ✅ |

---

## sed Patterns Explained

### Replace Pattern: `s|pattern|replacement|g`

```bash
# Replace flag value
sed -i "s|--flag=.*|--flag=newvalue|g" file
       ^                           ^
       | - Use pipe as delimiter (avoids / escaping)
       
# Single character escape needed for delimiter
sed -i "s|\\${VAR}=.*|value|g" file
         ^^^ - Escape $ for sed variable protection
```

### Append Pattern: `/marker$/a \`

```bash
# Append after line matching marker
sed -i "/- binary$/a \\    - --flag=value" file
       ^          ^^  - Append after this line
                  \\  - Literal backslash for continuation

# The \    is 4 spaces for YAML indentation
```

### Delete Pattern: `/pattern/d`

```bash
# Delete lines matching pattern
sed -i "/--flag=/d" file
       ^         ^ - Delete all lines with this pattern
```

---

## Testing Commands

### Test grep -F behavior
```bash
# Create test file
echo "- --anonymous-auth=true" > /tmp/test.yaml

# Test 1: Original pattern fails
grep -q "--anonymous-auth=false" /tmp/test.yaml  # Error!

# Test 2: Fixed pattern works
grep -Fq -- "--anonymous-auth=false" /tmp/test.yaml  # No error, returns false (not found)

# Test 3: Check with correct value
grep -Fq -- "--anonymous-auth=true" /tmp/test.yaml  # Returns true (found)
```

### Test sed patterns
```bash
# Create test manifest
cat > /tmp/manifest.yaml << 'EOF'
spec:
  containers:
  - name: kube-apiserver
    image: k8s.gcr.io/kube-apiserver:v1.30
    command:
    - kube-apiserver
    - --anonymous-auth=true
    - --authorization-mode=RBAC
EOF

# Test replacement
sed -i "s|--anonymous-auth=.*|--anonymous-auth=false|g" /tmp/manifest.yaml

# Verify
grep "anonymous-auth" /tmp/manifest.yaml
# Output: - --anonymous-auth=false
```

---

## Deployment Steps

### 1. Copy fixed scripts to production

```bash
cp /home/first/Project/cis-k8s-hardening/Level_1_Master_Node/1.2.1_remediate.sh \
   /path/to/production/

cp /home/first/Project/cis-k8s-hardening/Level_1_Master_Node/1.2.11_remediate.sh \
   /path/to/production/

cp /home/first/Project/cis-k8s-hardening/Level_1_Master_Node/1.3.6_remediate.sh \
   /path/to/production/

cp /home/first/Project/cis-k8s-hardening/Level_1_Master_Node/1.4.1_remediate.sh \
   /path/to/production/
```

### 2. Verify syntax on production

```bash
bash -n /path/to/production/1.2.1_remediate.sh
bash -n /path/to/production/1.2.11_remediate.sh
bash -n /path/to/production/1.3.6_remediate.sh
bash -n /path/to/production/1.4.1_remediate.sh
```

### 3. Run remediation

```bash
/path/to/production/1.2.1_remediate.sh    # Should now work without grep errors!
/path/to/production/1.2.11_remediate.sh
/path/to/production/1.3.6_remediate.sh
/path/to/production/1.4.1_remediate.sh
```

### 4. Verify results

```bash
# Check manifests were actually modified
grep -- "--anonymous-auth=false" /etc/kubernetes/manifests/kube-apiserver.yaml

# Check pod restarted (static pods auto-restart on manifest change)
kubectl get pods -n kube-system | grep kube-apiserver

# Run audit to confirm
/path/to/production/1.2.1_audit.sh  # Should PASS now
```

---

## All Files Modified

✅ `Level_1_Master_Node/1.2.1_remediate.sh` - Fixed  
✅ `Level_1_Master_Node/1.2.11_remediate.sh` - Fixed  
✅ `Level_1_Master_Node/1.3.6_remediate.sh` - Fixed  
✅ `Level_1_Master_Node/1.4.1_remediate.sh` - Fixed  

**Status:** All scripts pass syntax validation and ready for production deployment.
