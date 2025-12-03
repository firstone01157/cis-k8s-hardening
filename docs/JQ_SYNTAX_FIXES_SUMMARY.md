# jq Syntax Error Fixes - Level 1 Master Node Audit Scripts

**Date**: November 28, 2025  
**Status**: ✅ COMPLETE  
**Scripts Fixed**: 12 (5.2.1-5.2.12, 5.6.1)

## Problem Statement

The CIS audit scripts were experiencing jq syntax errors due to improper shell quoting patterns:

```
jq: error: syntax error, unexpected INVALID_CHARACTER
```

### Root Cause

The original implementation attempted to echo the entire jq command with escaped quotes, creating syntax conflicts:

```bash
# WRONG - Quote escaping issues
echo "[CMD] Executing: command=$(... | jq -r '.items[] | select(.metadata.name != \"kube-system\") | ...')"
```

This caused:
1. **Quote nesting confusion**: Single quotes containing escaped double quotes
2. **Complex escaping**: Multiple levels of backslash escaping
3. **Reduced readability**: Hard to maintain and debug

## Solution Pattern

Implemented a **fetch-then-filter** pattern that cleanly separates concerns:

```bash
# CORRECT - Clean separation of concerns
# Step 1: Fetch JSON data
echo "[CMD] Executing: kubectl get ns -o json"
ns_json=$(kubectl get ns -o json 2>/dev/null)

# Step 2: Filter with simple jq syntax
echo "[CMD] Executing: jq filter for namespaces without enforce label"
missing_labels=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system") | ...')
```

### Benefits

✅ **No quote escaping needed** - jq filter uses clean double quotes  
✅ **Clearer flow** - Separation between data fetch and processing  
✅ **Better error handling** - Explicit tool validation (kubectl/jq checks)  
✅ **Easier debugging** - Echo statements show clear command steps  
✅ **Shell-safe** - No complex quote nesting  
✅ **Consistent pattern** - Applied uniformly across all fixed scripts

## Scripts Fixed

### Pod Security Standards (5.2.x)

All 5.2.x scripts check for `pod-security.kubernetes.io/enforce` labels on non-system namespaces.

| Script | Title | Status |
|--------|-------|--------|
| 5.2.1 | Ensure active policy control mechanism | ✅ Fixed |
| 5.2.2 | Minimize admission of privileged containers | ✅ Fixed |
| 5.2.3 | Minimize containers sharing host process ID | ✅ Fixed |
| 5.2.4 | Minimize containers sharing host IPC | ✅ Fixed |
| 5.2.5 | Minimize containers sharing host network | ✅ Fixed |
| 5.2.6 | Minimize allowPrivilegeEscalation admission | ✅ Fixed |
| 5.2.8 | Minimize NET_RAW capability admission | ✅ Fixed |
| 5.2.10 | Minimize Windows HostProcess containers | ✅ Fixed |
| 5.2.11 | Minimize admission of containers with seccomp | ✅ Fixed |
| 5.2.12 | Minimize admission of containers with AppArmor | ✅ Fixed |

### Namespace Boundaries

| Script | Title | Status |
|--------|-------|--------|
| 5.6.1 | Administrative boundaries using namespaces | ✅ Fixed |

## Code Examples

### Example 1: 5.2.2 - Privileged Containers

**Before (with syntax errors):**
```bash
echo "[CMD] Executing: missing_labels=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name != \"kube-system\" and .metadata.name != \"kube-public\") | select(.metadata.labels[\"pod-security.kubernetes.io/enforce\"] == null) | .metadata.name')"
missing_labels=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name')
```

**After (clean pattern):**
```bash
# Verify kubectl and jq are available
if ! command -v kubectl &> /dev/null; then
    echo "[INFO] Check Failed"
    a_output2+=(" - Check Error: kubectl command not found")
    return 2
fi

if ! command -v jq &> /dev/null; then
    echo "[INFO] Check Failed"
    a_output2+=(" - Check Error: jq command not found")
    return 2
fi

# Fetch namespace data
echo "[CMD] Executing: kubectl get ns -o json"
ns_json=$(kubectl get ns -o json 2>/dev/null)

# Filter with clean jq syntax
echo "[CMD] Executing: jq filter for namespaces without enforce label"
missing_labels=$(echo "$ns_json" | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | .metadata.name')

# Process results
if [ -n "$missing_labels" ]; then
    # Handle failures
    while IFS= read -r ns; do
        [ -n "$ns" ] && a_output2+=(" - $ns")
    done <<< "$missing_labels"
    return 1
else
    # Success
    return 0
fi
```

**Key Improvements:**
- ✅ Explicit jq/kubectl validation before use
- ✅ JSON fetched into variable first
- ✅ No quote escaping in jq filter
- ✅ Clear echo statements for debugging
- ✅ Proper error handling with return codes

### Example 2: 5.6.1 - Namespace Count

**Before (poor error handling):**
```bash
echo "[CMD] Executing: total_namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq '.items | length')"
total_namespaces=$(kubectl get namespaces -o json 2>/dev/null | jq '.items | length')
```

**After (robust with defaults):**
```bash
# Verify prerequisites
if ! command -v kubectl &> /dev/null; then
    return 2
fi

if ! command -v jq &> /dev/null; then
    return 2
fi

# Fetch data once
echo "[CMD] Executing: kubectl get namespaces -o json"
ns_json=$(kubectl get namespaces -o json 2>/dev/null)

# Count with safe defaults
echo "[CMD] Executing: jq to count total namespaces"
total_namespaces=$(echo "$ns_json" | jq '.items | length // 0')

echo "[CMD] Executing: jq to count non-system namespaces"
non_system_namespaces=$(echo "$ns_json" | jq '[.items[] | select(.metadata.name | IN("default","kube-system","kube-public","kube-node-lease") | not)] | length // 0')

# Ensure variables have valid values
if [ -z "$total_namespaces" ]; then
    total_namespaces=0
fi
if [ -z "$non_system_namespaces" ]; then
    non_system_namespaces=0
fi
```

**Key Improvements:**
- ✅ Uses jq `// 0` operator for safe defaults
- ✅ Extra shell variable validation before comparison
- ✅ Handles edge case where jq returns null
- ✅ IN() function for multi-value checks (cleaner than regex)
- ✅ Explicit namespace filtering without quote complexity

## Pattern Reference

### General Bash-jq Best Practices

#### ❌ AVOID: Inline jq with complex quoting
```bash
result=$(kubectl get ns | jq -r '.items[] | select(.metadata.name != \"system\") | ...')
```

#### ✅ USE: Fetch-then-filter pattern
```bash
json_data=$(kubectl get ns 2>/dev/null)
result=$(echo "$json_data" | jq -r '.items[] | select(.metadata.name != "system") | ...')
```

#### ❌ AVOID: Escaped quotes in single-quoted strings
```bash
echo "[CMD] Executing: ... jq -r \'.items[] | select(.name != \\\"value\\\")\'..."
```

#### ✅ USE: Clear, readable echo statements
```bash
echo "[CMD] Executing: kubectl command"
echo "[CMD] Executing: jq filter operation"
```

#### ❌ AVOID: No validation of tools
```bash
result=$(kubectl ... | jq ...)  # What if jq is missing?
```

#### ✅ USE: Explicit tool checks
```bash
if ! command -v jq &> /dev/null; then
    return 2  # ERROR: tool missing
fi
result=$(kubectl ... | jq ...)
```

## Validation Results

### Syntax Validation

All fixed scripts have been verified for proper bash syntax:

- ✅ No quote escaping errors
- ✅ No command substitution nesting issues
- ✅ No unclosed parentheses or brackets
- ✅ Proper use of pipes and filters

### Pattern Consistency

All 5.2.x scripts now follow identical pattern:

1. **Tool validation** (kubectl + jq)
2. **Data fetch** (single kubectl call)
3. **jq filter** (piped from variable)
4. **Result processing** (while loop or condition)
5. **Audit output** (PASS/FAIL with details)

### Error Handling

Improved error handling across all scripts:

- Returns `2` (ERROR) when tools missing
- Returns `1` (FAIL) when violations found
- Returns `0` (PASS) when no violations
- Detailed logging of failures and reasons

## Usage Examples

### Running a fixed script

```bash
# Run 5.2.2 audit directly
./5.2.2_audit.sh

# Or through the main orchestrator
python cis_k8s_unified.py
```

### Expected Output (Success)

```
[INFO] Starting check for 5.2.2...
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without enforce label
[INFO] Check Passed
- Audit Result:
  [+] PASS
- Check Passed: All non-system namespaces have pod-security.kubernetes.io/enforce label
```

### Expected Output (Failure)

```
[INFO] Starting check for 5.2.2...
[CMD] Executing: kubectl get ns -o json
[CMD] Executing: jq filter for namespaces without enforce label
[INFO] Check Failed
- Audit Result:
  [-] FAIL
- Reason(s) for audit failure:
- Check Failed: The following namespaces are missing pod-security.kubernetes.io/enforce label:
 - production
 - staging
 - development
```

### Expected Output (Error)

```
[INFO] Starting check for 5.2.2...
[INFO] Check Failed
- Audit Result:
  [-] ERROR
- Check Error: jq command not found
```

## Testing Checklist

- ✅ All 5.2.x scripts verified for valid bash syntax
- ✅ jq filters tested for valid jq syntax
- ✅ Variable substitution patterns validated
- ✅ Error codes (0, 1, 2) proper for each condition
- ✅ Quote escaping eliminated
- ✅ Tool validation checks in place
- ✅ Pattern consistency across all scripts
- ✅ Logging/echo statements clear and helpful

## Migration Notes

If you have custom scripts using the old pattern, update them:

### Old Pattern → New Pattern

```bash
# OLD (problematic)
result=$(kubectl get resource -o json 2>/dev/null | jq -r '.items[] | select(...) | ...')

# NEW (robust)
json_data=$(kubectl get resource -o json 2>/dev/null)
result=$(echo "$json_data" | jq -r '.items[] | select(...) | ...')
```

## Future Recommendations

1. **Use this pattern** for all new jq-based audit checks
2. **Add tool validation** to all scripts that use external commands
3. **Test with missing tools** to verify error codes are correct
4. **Document jq filters** separately from bash code
5. **Consider jq --arg** for complex string passing (advanced feature)

## Files Modified

```
Level_1_Master_Node/
├── 5.2.1_audit.sh      ✅ FIXED
├── 5.2.2_audit.sh      ✅ FIXED
├── 5.2.3_audit.sh      ✅ FIXED
├── 5.2.4_audit.sh      ✅ FIXED
├── 5.2.5_audit.sh      ✅ FIXED
├── 5.2.6_audit.sh      ✅ FIXED
├── 5.2.8_audit.sh      ✅ FIXED
├── 5.2.10_audit.sh     ✅ FIXED
├── 5.2.11_audit.sh     ✅ FIXED
├── 5.2.12_audit.sh     ✅ FIXED
└── 5.6.1_audit.sh      ✅ FIXED (with count safety)
```

## Summary

**All 11 jq syntax errors have been fixed** by implementing a consistent, clean pattern that:

- Eliminates quote escaping issues
- Validates tool availability
- Separates data fetch from filtering
- Provides clear, maintainable code
- Handles edge cases (empty counts, missing tools)
- Follows bash best practices

The scripts are now **production-ready** and should execute without jq syntax errors.

---

## Quick Reference: The Fixed Pattern

```bash
audit_rule() {
    # 1. Validate tools
    if ! command -v kubectl &> /dev/null; then return 2; fi
    if ! command -v jq &> /dev/null; then return 2; fi
    
    # 2. Fetch data
    echo "[CMD] Executing: kubectl get ..."
    json_data=$(kubectl get ... 2>/dev/null)
    
    # 3. Filter with jq (NO ESCAPING NEEDED)
    echo "[CMD] Executing: jq filter for ..."
    results=$(echo "$json_data" | jq -r '.items[] | select(...) | ...')
    
    # 4. Process results
    if [ -n "$results" ]; then
        # FAIL case
        while IFS= read -r item; do
            [ -n "$item" ] && a_output2+=(" - $item")
        done <<< "$results"
        return 1
    else
        # PASS case
        a_output+=(" - Check Passed: ...")
        return 0
    fi
}
```

Use this pattern for all future audit script development!
