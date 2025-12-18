# Bash Wrapper Best Practices Guide

**Version**: 1.0  
**Updated**: 2025-12-17  
**Target Audience**: Script developers for CIS K8s hardening remediation

---

## Overview

Bash remediation wrappers are critical components in the CIS hardening pipeline. They must:
1. Execute remediation securely and reliably
2. Communicate results clearly via exit codes and stdout
3. Integrate seamlessly with the parent orchestrator (`cis_k8s_unified.py`)

This guide provides templates and best practices for creating robust, maintainable wrappers.

---

## Quick Reference: Exit Code Semantics

| Exit Code | Meaning | Usage |
|-----------|---------|-------|
| **0** | Success/PASS/FIXED | Remediation completed successfully OR check already passed |
| **3** | Manual Intervention Required | Cannot automate; requires human decision |
| **1** | Failure/ERROR | Something went wrong; needs debugging |

**Critical Rule**: One exit code per execution. Use exit codes to signal status, NOT stdout messages.

---

## Core Principles

### 1. Exit Code is the Source of Truth

✅ **CORRECT**:
```bash
# Exit code tells parent runner the status
return 0  # or exit 0
```

❌ **INCORRECT**:
```bash
# Printing status is confusing - parent runner uses exit code, not stdout
echo "FIXED: Applied some config"
return 0
```

### 2. Only Print Logs, Never Status Messages

✅ **CORRECT**:
```bash
[INFO] Checking manifest...
[INFO] Applying fix...
# exit 0 signals success to parent
return 0
```

❌ **INCORRECT**:
```bash
echo "Manual intervention required"
return 0  # Confusing! Exit 0 means success, but message says manual needed
```

### 3. Separate SUCCESS Path from MANUAL path

✅ **CORRECT**:
```bash
if [[ condition ]]; then
    # Can automate the fix
    do_fix
    return 0  # Success
else
    # Cannot automate
    return 3  # Manual intervention marker
fi
```

❌ **INCORRECT**:
```bash
# Same code path for both cases
echo "Manual intervention or already fixed"
return 0  # Ambiguous!
```

---

## Template: Complete Bash Wrapper

```bash
#!/bin/bash
# CIS Benchmark: X.Y.Z
# Title: [Check Title]
# Level: Level [1|2] - [Master|Worker] Node
# Description: [What this check does]

set -e  # Exit on error
set -o pipefail  # Exit if pipe fails

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*" >&2
}

# ============================================================================
# REMEDIATE FUNCTION
# ============================================================================

remediate_rule() {
    local check_id="X.Y.Z"
    
    log_info "Starting remediation for CIS $check_id"
    
    # STEP 1: Check if remediation is applicable
    if ! can_remediate; then
        log_info "Remediation not applicable (manual intervention required)"
        return 3  # Manual - cannot automate
    fi
    
    # STEP 2: Check if already fixed
    if is_already_fixed; then
        log_info "Check already passed - no changes needed"
        return 0  # Success - already in desired state
    fi
    
    # STEP 3: Apply fix
    if apply_fix; then
        log_info "Remediation applied successfully"
        
        # STEP 4: Verify fix was applied
        if verify_fix; then
            log_info "Verification successful"
            return 0  # Success
        else
            log_error "Fix was applied but verification failed"
            return 1  # Failure - something went wrong
        fi
    else
        log_error "Failed to apply fix"
        return 1  # Failure
    fi
}

# ============================================================================
# HELPER FUNCTIONS - Implement as needed
# ============================================================================

can_remediate() {
    # Return 0 if this can be automated, 1 otherwise
    # Examples where you'd return 1:
    #   - Requires admin to make policy decision
    #   - Requires user configuration
    #   - Platform-specific (this is master, check is for worker)
    
    # Check if manifest exists
    if [[ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]]; then
        return 0
    fi
    
    return 1
}

is_already_fixed() {
    # Return 0 if check already passes, 1 if needs fixing
    # Example: Check if flag is already in manifest
    
    grep -q "some-flag=value" /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null
}

apply_fix() {
    # Return 0 on success, 1 on failure
    
    # Backup manifest
    cp -v /etc/kubernetes/manifests/kube-apiserver.yaml \
           /etc/kubernetes/manifests/kube-apiserver.yaml.backup.$(date +%s)
    
    # Apply fix using harden_manifests.py
    python3 /path/to/harden_manifests.py \
        --manifest /etc/kubernetes/manifests/kube-apiserver.yaml \
        --flag some-flag \
        --value value \
        --ensure present
    
    return $?
}

verify_fix() {
    # Return 0 if fix is verified, 1 otherwise
    
    # Wait for manifest to be reloaded
    sleep 2
    
    # Check if flag is now present
    if grep -q "some-flag=value" /etc/kubernetes/manifests/kube-apiserver.yaml; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

remediate_rule
exit $?
```

---

## Pattern 1: Configuration File Modification

```bash
#!/bin/bash
# CIS Benchmark: 1.2.1 - API Server encryption provider

remediate_rule() {
    local manifest="/etc/kubernetes/manifests/kube-apiserver.yaml"
    
    log_info "Checking if encryption-provider-config flag is set..."
    
    # Check if already set
    if grep -q "encryption-provider-config" "$manifest" 2>/dev/null; then
        log_info "Encryption provider already configured"
        return 0
    fi
    
    # Apply fix
    log_info "Applying encryption-provider-config flag..."
    python3 /path/to/harden_manifests.py \
        --manifest "$manifest" \
        --flag encryption-provider-config \
        --value /etc/kubernetes/encryption/config.yaml
    
    if [[ $? -eq 0 ]]; then
        log_info "Flag applied successfully"
        sleep 2  # Wait for kubelet to reload
        return 0
    else
        log_error "Failed to apply flag"
        return 1
    fi
}

remediate_rule
exit $?
```

---

## Pattern 2: File Permissions (chmod/chown)

```bash
#!/bin/bash
# CIS Benchmark: 1.1.1 - Ensure proper permissions on etcd data directory

remediate_rule() {
    local path="/var/lib/etcd"
    
    log_info "Checking permissions on $path..."
    
    # Get current permissions
    local current_perms=$(stat -c %a "$path" 2>/dev/null)
    
    if [[ "$current_perms" == "700" ]]; then
        log_info "Permissions already correct (700)"
        return 0
    fi
    
    log_info "Setting permissions to 700..."
    chmod 700 "$path"
    
    if [[ $? -eq 0 ]]; then
        log_info "Permissions updated successfully"
        return 0
    else
        log_error "Failed to update permissions"
        return 1
    fi
}

remediate_rule
exit $?
```

---

## Pattern 3: Network Policy (Manual)

```bash
#!/bin/bash
# CIS Benchmark: 5.3.1 - Ensure that all namespaces have NetworkPolicies

remediate_rule() {
    log_info "Checking if NetworkPolicies can be applied automatically..."
    
    # This check requires understanding of your network topology
    # It cannot be fully automated without admin input
    
    log_info "NetworkPolicy deployment requires understanding your cluster's network needs"
    log_info "Action: Review cluster topology and deploy appropriate NetworkPolicies"
    
    return 3  # Manual intervention required
}

remediate_rule
exit $?
```

---

## Pattern 4: RBAC Configuration (Automated)

```bash
#!/bin/bash
# CIS Benchmark: 5.1.1 - Ensure default service account is not used

remediate_rule() {
    log_info "Checking service account usage..."
    
    # Can be automated
    if kubectl get pods --all-namespaces -o json | \
       jq '.items[] | select(.spec.serviceAccountName=="default")' | grep -q .; then
        
        log_info "Found pods using default service account - remediating..."
        
        # Create restricted service account
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: default
EOF
        
        if [[ $? -eq 0 ]]; then
            log_info "Restricted service account created"
            return 0
        else
            log_error "Failed to create service account"
            return 1
        fi
    fi
    
    log_info "No pods using default service account"
    return 0
}

remediate_rule
exit $?
```

---

## Common Mistakes & How to Fix Them

### ❌ Mistake 1: Printing Status Instead of Using Exit Code

```bash
# BAD
if fix_applied; then
    echo "Manual intervention required"  # Confusing message!
    return 0  # Exit code says success
fi
```

**Fix**: Use exit codes consistently:
```bash
# GOOD
if fix_applied; then
    return 0  # Exit code 0 = success/fixed
else
    return 3  # Exit code 3 = manual intervention needed
fi
```

### ❌ Mistake 2: No Error Handling

```bash
# BAD
cp config.yaml config.yaml.backup
# If cp fails, script continues silently
apply_patch < patch.txt
```

**Fix**: Check errors and exit early:
```bash
# GOOD
set -e  # Exit on any error
set -o pipefail  # Exit if pipe fails

# or explicit checks:
if ! cp config.yaml config.yaml.backup; then
    log_error "Backup failed"
    return 1
fi
```

### ❌ Mistake 3: No Logging

```bash
# BAD
python3 harden_manifests.py --manifest kube-apiserver.yaml --flag foo --value bar
```

**Fix**: Add informative logging:
```bash
# GOOD
log_info "Applying flag to manifest..."
if python3 harden_manifests.py \
    --manifest kube-apiserver.yaml \
    --flag foo \
    --value bar; then
    log_info "Flag applied successfully"
    return 0
else
    log_error "Failed to apply flag"
    return 1
fi
```

### ❌ Mistake 4: Hardcoded Paths

```bash
# BAD
python3 /home/admin/scripts/harden.py  # What if path changes?
```

**Fix**: Use dynamic discovery or environment variables:
```bash
# GOOD
HARDENER_PATH="${HARDENER_PATH:-/opt/cis-hardening/harden_manifests.py}"
if [[ ! -f "$HARDENER_PATH" ]]; then
    log_error "Hardener script not found at $HARDENER_PATH"
    return 1
fi
python3 "$HARDENER_PATH" ...
```

---

## Exit Code Usage Summary

### Exit 0: Success - Use When:
- ✅ Remediation was applied and verified
- ✅ Check already passed (no changes needed)
- ✅ Both cases: automation succeeded OR nothing to do

### Exit 3: Manual - Use When:
- ⚠️ Cannot automate (requires policy decision)
- ⚠️ Requires human review
- ⚠️ Administrator must configure manually
- **Note**: NOT a failure - it's expected for some checks

### Exit 1: Failure - Use When:
- ❌ Remediation was attempted but failed
- ❌ Verification failed after fix
- ❌ Unexpected error occurred
- ❌ Script encountered unrecoverable issue

---

## Testing Your Wrapper

### Manual Testing

```bash
# Run the script directly
./1_2_1_remediate.sh

# Check exit code
echo $?

# Expected: 0 (success), 3 (manual), or 1 (failure)
```

### Integration Testing with Orchestrator

```bash
# Run orchestrator in remediate mode
python3 cis_k8s_unified.py --remediate --level 1 --role master

# Check results
# - If exit 0: Shows as PASS/FIXED
# - If exit 3: Shows as MANUAL
# - If exit 1: Shows as FAIL
```

### Debug Mode

```bash
# Enable debug output
DEBUG=1 ./1_2_1_remediate.sh

# Parent runner with verbose output
python3 cis_k8s_unified.py --remediate -vv
```

---

## Troubleshooting Wrapper Issues

### Problem: Exit Code Inconsistency

**Symptom**: Script prints "success" but exits with code 1

**Solution**:
1. Check for unhandled errors: Add `set -e` and `set -o pipefail`
2. Verify all subcommands return correct codes
3. Test with `echo $?` after each critical step

### Problem: Manual Checks Appearing as FAILURES

**Symptom**: Exit 3 items show as [FAIL] in reports

**Solution**:
- Exit 3 is correct for manual checks
- Parent orchestrator should handle it properly
- Verify orchestrator version is up to date

### Problem: Manifest Not Found Error

**Symptom**: `harden_manifests.py` fails with "No command section found"

**Solution**:
1. Verify manifest path is correct
2. Check manifest syntax: `python3 -m yaml < /path/to/manifest.yaml`
3. Ensure manifest has proper `command:` section
4. Use verbose mode: `python3 harden_manifests.py ... --verbose`

---

## Security Considerations

### 1. Backup Before Modifying

```bash
BACKUP_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml.backup.$(date +%s)"
cp /etc/kubernetes/manifests/kube-apiserver.yaml "$BACKUP_FILE"
log_info "Backup created: $BACKUP_FILE"
```

### 2. Verify Changes

```bash
# Always verify after applying
if grep -q "your-flag" /path/to/manifest; then
    log_info "Verification successful"
    return 0
else
    log_error "Verification failed - reverting"
    cp "$BACKUP_FILE" /etc/kubernetes/manifests/kube-apiserver.yaml
    return 1
fi
```

### 3. Handle Race Conditions

```bash
# Wait for kubelet to reload manifests
sleep 2

# Check pod is still running
if kubectl get pods -n kube-system | grep -q "running"; then
    log_info "Cluster stable after changes"
else
    log_error "Cluster became unhealthy - requires manual intervention"
    return 1
fi
```

### 4. Preserve File Permissions

```bash
# Use -p flag with cp to preserve permissions
cp -p original.yaml original.yaml.backup

# Or explicitly set
chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml
chown root:root /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## Checklist: Before Committing a Wrapper

- [ ] Script has clear comments explaining what it does
- [ ] Uses exit codes: 0 (success), 3 (manual), 1 (failure)
- [ ] Includes info/error logging with `log_info` and `log_error`
- [ ] Has `set -e` and `set -o pipefail` at the top
- [ ] Checks for prerequisites (files exist, commands available)
- [ ] Includes backup mechanism before modifying files
- [ ] Verifies changes after applying them
- [ ] Handles errors gracefully (doesn't silently fail)
- [ ] Uses variables for paths (no hardcoded /home/admin style paths)
- [ ] Tested manually and with orchestrator
- [ ] Works on both clean and dirty systems
- [ ] Cleans up temporary files if created
- [ ] Logs are informative (not too verbose, not too silent)

---

## Examples: Real-World Wrappers

### Example 1: Simple Flag Addition

**File**: `1.2.1_remediate.sh`

```bash
#!/bin/bash
set -e
set -o pipefail

remediate_rule() {
    local manifest="/etc/kubernetes/manifests/kube-apiserver.yaml"
    
    [[ -f "$manifest" ]] || {
        echo "[ERROR] Manifest not found" >&2
        return 3  # Cannot remediate without manifest
    }
    
    # Already fixed?
    grep -q "encryption-provider-config" "$manifest" 2>/dev/null && return 0
    
    # Apply
    python3 /opt/cis-hardening/harden_manifests.py \
        --manifest "$manifest" \
        --flag encryption-provider-config \
        --value /etc/kubernetes/encryption/config.yaml
    
    # Verify
    sleep 2
    grep -q "encryption-provider-config" "$manifest" && return 0
    return 1
}

remediate_rule
exit $?
```

### Example 2: Complex Decision Logic

**File**: `5.3.1_remediate.sh`

```bash
#!/bin/bash

remediate_rule() {
    # NetworkPolicy application requires understanding cluster topology
    # Cannot be fully automated
    
    echo "[INFO] Checking if NetworkPolicies can be auto-deployed..."
    
    # Check if cluster has default deny policy
    if kubectl get networkpolicies --all-namespaces 2>/dev/null | grep -q "deny-all"; then
        echo "[INFO] Default deny NetworkPolicy already exists"
        return 0
    fi
    
    # Cannot automate without understanding business requirements
    echo "[INFO] NetworkPolicy deployment requires policy decision"
    echo "[INFO] Action: Review cluster architecture and deploy NetworkPolicies"
    
    return 3  # Manual intervention required
}

remediate_rule
exit $?
```

---

## FAQ

**Q: When should I use exit code 3?**

A: When you cannot fully automate the check. Examples:
- Requires administrator decision on cluster topology
- Requires understanding of business policy
- Requires manual configuration by authorized admin
- Requires customer input (e.g., "Do you want encryption?")

**Q: Can I print to stdout in my wrapper?**

A: Yes! But only info/debug messages. Never print status. Examples:
- ✅ `[INFO] Checking manifest...`
- ✅ `[DEBUG] Found flag at line 42`
- ❌ `Manual intervention required`
- ❌ `Successfully applied`

The exit code signals the status, not the stdout message.

**Q: What if the fix takes a long time?**

A: Add logging to show progress:
```bash
echo "[INFO] Deploying network policies... this may take 30 seconds"
for policy in /etc/policies/*.yaml; do
    kubectl apply -f "$policy"
    echo "[INFO] Applied $(basename $policy)"
done
```

**Q: How do I handle platform differences (Master vs Worker)?**

A: Check at the start:
```bash
if [[ "$TARGET_ROLE" != "master" ]]; then
    echo "[INFO] This check only applies to master nodes"
    return 0  # Or return 3 if it must be skipped
fi
```

**Q: Can I have interactive prompts?**

A: No! Automation scripts must be non-interactive. If you need user input:
```bash
# Instead of: read -p "Enable encryption? " answer
# Do this:
if [[ "${ENABLE_ENCRYPTION:-false}" == "true" ]]; then
    # Apply encryption
fi
# Parent runner can set ENABLE_ENCRYPTION env var
```

---

## Conclusion

Well-designed bash wrappers are essential to the success of the CIS hardening automation. By following these best practices:

1. ✅ Your scripts will integrate seamlessly with the orchestrator
2. ✅ Exit codes will communicate status clearly
3. ✅ Logs will help troubleshoot issues
4. ✅ Your automation will be reliable and maintainable
5. ✅ Manual checks won't be confused with failures

For questions or issues, refer to the main project documentation or file an issue.

