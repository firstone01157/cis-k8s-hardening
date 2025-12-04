# Manual Exit Code Update Guide

## Overview
Update all remediation/audit scripts with `(Manual)` in their title to use **exit code 3** instead of `exit 0`.

---

## Option 1: Safe Batch Update Script (RECOMMENDED)

**Best for:** Production environments, requires verification

### Run the automated script:
```bash
cd /home/first/Project/cis-k8s-hardening
bash batch_update_manual_exit_codes.sh
```

**What it does:**
✓ Finds all scripts with `(Manual)` in title  
✓ Creates timestamped backups  
✓ Shows preview of changes  
✓ Asks for confirmation before updating  
✓ Verifies each change  
✓ Logs all modifications  
✓ Provides rollback instructions  

**Output:**
- `backups/manual_exit_code_update_YYYYMMDD_HHMMSS/` - Backup files
- `batch_update_changes_YYYYMMDD_HHMMSS.log` - Change log

---

## Option 2: Minimal One-Liner (Quick & Safe)

**Best for:** Quick verification without interactive prompts

```bash
cd /home/first/Project/cis-k8s-hardening && \
find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do \
    if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then \
        if grep -q "^exit 0$" "$f"; then \
            echo "[UPDATE] $f"; \
            sed -i 's/^exit 0$/exit 3/' "$f"; \
        fi; \
    fi; \
done
```

---

## Option 3: Preview Only (No Changes)

**Best for:** Seeing what would be changed without making updates

```bash
cd /home/first/Project/cis-k8s-hardening && \
find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do \
    if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then \
        if grep -q "^exit 0$" "$f"; then \
            echo "[WOULD UPDATE] $f"; \
            head -5 "$f" | grep "# Title:"; \
        fi; \
    fi; \
done
```

---

## Option 4: Safe Loop with Backup (Manual Control)

**Best for:** Scripts that require backup and verification

```bash
#!/bin/bash
BACKUP_DIR="/tmp/manual_scripts_backup_$(date +%s)"
mkdir -p "$BACKUP_DIR"

cd /home/first/Project/cis-k8s-hardening

find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do
    if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then
        if grep -q "^exit 0$" "$f"; then
            cp "$f" "$BACKUP_DIR/$(basename "$f")"
            echo "[BACKUP] $f → $BACKUP_DIR"
            sed -i 's/^exit 0$/exit 3/' "$f"
            echo "[UPDATED] $f"
        fi
    fi
done

echo "Backups saved to: $BACKUP_DIR"
```

---

## Verification Commands

### Check which scripts were updated:
```bash
cd /home/first/Project/cis-k8s-hardening && \
find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do \
    if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then \
        echo -n "$f: "; \
        tail -1 "$f"; \
    fi; \
done
```

### Count scripts by exit code:
```bash
cd /home/first/Project/cis-k8s-hardening && \
echo "Exit Code 3 (Manual):"; \
find . -name "*.sh" -type f ! -path "*/backups/*" -exec grep -l "^exit 3$" {} \; | wc -l && \
echo "Exit Code 0 (Standard):"; \
find . -name "*.sh" -type f ! -path "*/backups/*" -exec grep -l "^exit 0$" {} \; | wc -l
```

### View all scripts with exit code 3:
```bash
cd /home/first/Project/cis-k8s-hardening && \
find . -name "*.sh" -type f ! -path "*/backups/*" -exec grep -l "^exit 3$" {} \; | sort
```

---

## Rollback Instructions

### If using the batch script:
```bash
# Restore from the backup directory created during update
cp /home/first/Project/cis-k8s-hardening/backups/manual_exit_code_update_YYYYMMDD_HHMMSS/* \
   /home/first/Project/cis-k8s-hardening/
```

### If using Option 4 (manual backup):
```bash
# Restore from your backup directory
cp /tmp/manual_scripts_backup_TIMESTAMP/* \
   /home/first/Project/cis-k8s-hardening/
```

### Full rollback with git:
```bash
cd /home/first/Project/cis-k8s-hardening && git checkout -- "*.sh"
```

---

## Safety Features by Option

| Feature | Batch Script | One-Liner | Preview | Manual Loop | Git Rollback |
|---------|:---:|:---:|:---:|:---:|:---:|
| Backup Creation | ✓ | ✗ | ✗ | ✓ | ✗ |
| Preview Changes | ✓ | ✗ | ✓ | ✗ | ✗ |
| User Confirmation | ✓ | ✗ | ✗ | ✗ | ✗ |
| Verification | ✓ | ✗ | ✗ | ✗ | ✗ |
| Detailed Logging | ✓ | ✗ | ✗ | Partial | ✗ |
| Easy Rollback | ✓ | Manual | N/A | ✓ | ✓ |

---

## What Gets Changed

### Scripts affected (examples):
- `Level_1_Master_Node/1.2.1_audit.sh` - Anonymous auth check
- `Level_1_Worker_Node/4.2.4_remediate.sh` - ReadOnlyPort check
- `Level_2_Master_Node/2.7_audit.sh` - etcd CA check
- `Level_2_Master_Node/5.6.3_audit.sh` - Security context check
- And ~50+ other manual check scripts

### Exact change:
**Before:**
```bash
#!/bin/bash
# Title: Some Check (Manual)
echo "Check requires manual intervention"
exit 0  # ← CHANGED TO exit 3
```

**After:**
```bash
#!/bin/bash
# Title: Some Check (Manual)
echo "Check requires manual intervention"
exit 3  # ← Standard exit code for manual checks
```

---

## Integration with cis_k8s_unified.py

The updated scripts now work with the new `_parse_script_output()` method that checks:

1. **PRIORITY 1:** Exit code 3 → status = MANUAL
2. **PRIORITY 2:** Exit code 0 → status = PASS/FIXED
3. **PRIORITY 3:** Fallback to text-based detection

This means:
- Scripts with exit code 3 are immediately recognized as MANUAL
- No text parsing needed for consistent behavior
- Both audit and remediate modes support this pattern

---

## Questions & Troubleshooting

**Q: Will this break anything?**  
A: No. The exit code 3 is now recognized by `cis_k8s_unified.py` as MANUAL. Scripts behave the same way.

**Q: Can I run this multiple times?**  
A: Yes. Scripts already with exit code 3 are skipped. Safe to run repeatedly.

**Q: How do I verify the changes?**  
A: Use the verification commands above to count scripts by exit code.

**Q: What if a script doesn't have a standard exit code?**  
A: The batch script reports these and skips them. Check the log.

---

## Recommended Workflow

1. **Preview first:**
   ```bash
   bash batch_update_manual_exit_codes.sh  # Review, then confirm
   ```

2. **Verify results:**
   ```bash
   # Check exit codes
   cd /home/first/Project/cis-k8s-hardening && \
   find . -name "*.sh" | xargs grep "^exit" | sort | uniq -c
   ```

3. **Test with cis_k8s_unified.py:**
   ```bash
   python3 cis_k8s_unified.py
   # Run audit scan to verify MANUAL checks are recognized
   ```

---

