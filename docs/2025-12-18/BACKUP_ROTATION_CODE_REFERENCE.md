# Backup Rotation - Code Reference

**Version:** 1.0  
**Date:** December 18, 2025  

---

## 📍 Code Locations

### New Method: `_rotate_backups()`
```
File: cis_k8s_unified.py
Lines: 1801-1843
Size: 43 lines
Type: Private method (helper)
Access: Called from perform_backup()
```

### Modified Method: `perform_backup()`
```
File: cis_k8s_unified.py
Lines: 1844-1882
Size: 39 lines
Changes: 4 lines added (logging + rotation call)
Type: Public method
Access: Called from remediation workflow
```

---

## 🔧 Complete Code Implementation

### Method 1: `_rotate_backups()`

```python
def _rotate_backups(self, max_backups=5):
    """
    Maintain only the N most recent backup folders.
    Deletes older backups automatically to save disk space.
    
    Args:
        max_backups (int): Maximum number of backups to keep (default: 5)
    """
    if not os.path.exists(self.backup_dir):
        return
    
    try:
        # List all backup directories (format: backup_YYYYMMDD_HHMMSS)
        backup_folders = []
        for item in os.listdir(self.backup_dir):
            item_path = os.path.join(self.backup_dir, item)
            if os.path.isdir(item_path) and item.startswith("backup_"):
                # Get modification time for sorting
                mtime = os.path.getmtime(item_path)
                backup_folders.append((item_path, item, mtime))
        
        # Sort by modification time (newest first)
        backup_folders.sort(key=lambda x: x[2], reverse=True)
        
        # Delete old backups beyond the limit
        if len(backup_folders) > max_backups:
            removed_count = 0
            for backup_path, backup_name, _ in backup_folders[max_backups:]:
                try:
                    shutil.rmtree(backup_path)
                    removed_count += 1
                    self.log_activity("BACKUP_ROTATION", 
                                    f"Removed old backup: {backup_name}")
                    print(f"{Colors.YELLOW}[INFO] Cleaned up old backups: removed {backup_name}{Colors.ENDC}")
                except Exception as e:
                    print(f"{Colors.RED}[!] Failed to delete backup {backup_name}: {e}{Colors.ENDC}")
            
            if removed_count > 0:
                print(f"{Colors.GREEN}[+] Backup rotation complete: {removed_count} old backup(s) removed{Colors.ENDC}")
    
    except Exception as e:
        print(f"{Colors.RED}[!] Backup rotation error: {e}{Colors.ENDC}")
```

---

### Method 2: `perform_backup()` (Enhanced)

```python
def perform_backup(self):
    """
    Create backup of critical Kubernetes configs with automatic rotation.
    สร้างสำรองข้อมูลของการตั้งค่า Kubernetes ที่สำคัญพร้อมการหมุนเวียนอัตโนมัติ
    
    Features:
    - Backs up critical Kubernetes configuration files
    - Automatically rotates backups (keeps only 5 most recent)
    - Logs all backup operations
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = os.path.join(self.backup_dir, f"backup_{timestamp}")
    os.makedirs(backup_path, exist_ok=True)
    
    print(f"\n{Colors.CYAN}[*] Creating Backup...{Colors.ENDC}")
    
    targets = ["/etc/kubernetes/manifests", "/var/lib/kubelet/config.yaml"]
    
    for target in targets:
        if not os.path.exists(target):
            continue
        
        try:
            name = os.path.basename(target)
            if os.path.isdir(target):
                shutil.copytree(target, os.path.join(backup_path, name))
            else:
                shutil.copy2(target, backup_path)
        except Exception as e:
            print(f"{Colors.RED}[!] Backup error {target}: {e}{Colors.ENDC}")
    
    print(f"   -> Saved to: {backup_path}")
    self.log_activity("BACKUP_CREATED", f"New backup created: backup_{timestamp}")
    
    # Perform automatic backup rotation
    print(f"{Colors.CYAN}[*] Checking for old backups...{Colors.ENDC}")
    self._rotate_backups(max_backups=5)
```

---

## 🔑 Key Concepts

### 1. Directory Listing & Filtering
```python
backup_folders = []
for item in os.listdir(self.backup_dir):
    item_path = os.path.join(self.backup_dir, item)
    if os.path.isdir(item_path) and item.startswith("backup_"):
        # Only backup directories, not files
        mtime = os.path.getmtime(item_path)
        backup_folders.append((item_path, item, mtime))
```

**Purpose:** Get list of all backup directories with their modification times

### 2. Sorting by Time
```python
backup_folders.sort(key=lambda x: x[2], reverse=True)
```

**Purpose:** Sort newest first (reverse=True means descending order)

**Result:** 
- Index 0-4: 5 newest backups
- Index 5+: Old backups to delete

### 3. Conditional Deletion
```python
if len(backup_folders) > max_backups:  # Only delete if over limit
    for backup_path, backup_name, _ in backup_folders[max_backups:]:
        # Delete each old backup
```

**Purpose:** Skip deletion if under limit (safe default)

### 4. Error Handling
```python
try:
    shutil.rmtree(backup_path)  # Delete directory recursively
    removed_count += 1
except Exception as e:
    # Report error but continue
    print(f"[!] Failed to delete backup: {e}")
```

**Purpose:** Don't stop if one deletion fails

---

## 📊 Data Flow Diagram

```
perform_backup() [START]
  │
  ├─ Create timestamp: "20251218_143022"
  ├─ Create path: "backups/backup_20251218_143022"
  ├─ Copy configs to path
  ├─ Print success message
  ├─ Log activity: BACKUP_CREATED
  │
  └─ _rotate_backups(max_backups=5)
     │
     ├─ Check if backup_dir exists
     ├─ List all items in backup_dir
     ├─ Filter: keep only backup_* directories
     ├─ Extract: modification times for each
     ├─ Create: list of (path, name, mtime) tuples
     │
     ├─ Sort: by mtime, reverse=True (newest first)
     │   Result: [newest, ..., oldest]
     │
     ├─ Check: if len(backups) > 5
     │   YES: continue to deletion
     │   NO: return early (nothing to delete)
     │
     ├─ For each backup in backups[5:]:  # Old ones
     │  ├─ Delete: shutil.rmtree(backup_path)
     │  ├─ Log: BACKUP_ROTATION
     │  ├─ Print: removal message
     │  └─ Increment: removed_count
     │
     ├─ Print: summary message
     │
     └─ Return: (rotation complete)
```

---

## 🔀 Sorting Example

### Scenario: 8 Backups Exist

**Initial State:**
```
backup_20251216_100000  (oldest)
backup_20251217_100000
backup_20251218_100000
backup_20251218_110000
backup_20251218_120000
backup_20251218_130000
backup_20251218_140000
backup_20251218_150530  (newest)
```

**After Sort (by mtime, newest first):**
```
Index 0: backup_20251218_150530  ← Keep
Index 1: backup_20251218_140000  ← Keep
Index 2: backup_20251218_130000  ← Keep
Index 3: backup_20251218_120000  ← Keep
Index 4: backup_20251218_110000  ← Keep
Index 5: backup_20251218_100000  ← DELETE (oldest 3)
Index 6: backup_20251217_100000  ← DELETE
Index 7: backup_20251216_100000  ← DELETE
```

**Python Slice:**
```python
# backups[5:] = [items at index 5, 6, 7, ...]
# = everything AFTER the first 5
# = all items to delete
```

---

## 🛡️ Error Handling Flow

```
Try: List backup directory
  └─ If fails: print "[!] Backup rotation error: {e}"
     Return silently (don't stop system)

Try: For each backup to delete
     Delete with shutil.rmtree()
  └─ If fails: print "[!] Failed to delete {name}: {e}"
     Continue with next backup (don't stop)

Result: At least one deletion succeeds or all fail gracefully
```

---

## 📝 Logging Statements

### Log Activity Call
```python
self.log_activity("BACKUP_ROTATION", f"Removed old backup: {backup_name}")
```

**Output in Activity Log:**
```
[2025-12-18 14:30:23] BACKUP_ROTATION | Removed old backup: backup_20251217_100000
```

**Format:** `[TIMESTAMP] ACTIVITY_CODE | Details`

---

## 🎨 Console Output Examples

### Yellow Message (Info)
```python
print(f"{Colors.YELLOW}[INFO] Cleaned up old backups: removed {backup_name}{Colors.ENDC}")
```

**Output:**
```
[INFO] Cleaned up old backups: removed backup_20251217_100000
[INFO] Cleaned up old backups: removed backup_20251217_110000
```

### Green Message (Success)
```python
print(f"{Colors.GREEN}[+] Backup rotation complete: {removed_count} old backup(s) removed{Colors.ENDC}")
```

**Output:**
```
[+] Backup rotation complete: 2 old backup(s) removed
```

### Red Message (Error)
```python
print(f"{Colors.RED}[!] Failed to delete backup {backup_name}: {e}{Colors.ENDC}")
```

**Output:**
```
[!] Failed to delete backup backup_20251217_100000: Permission denied
```

---

## 🔧 Customization Points

### 1. Change Max Backups
```python
# Current (line 1881):
self._rotate_backups(max_backups=5)

# Change to (example):
self._rotate_backups(max_backups=10)  # Keep 10 instead of 5
```

### 2. Add Backup Size Check
```python
# Could add before deletion:
backup_size = sum(
    os.path.getsize(os.path.join(dirpath, filename))
    for dirpath, dirnames, filenames in os.walk(backup_path)
    for filename in filenames
)
print(f"[*] Backup size: {backup_size / 1024 / 1024:.2f} MB")
```

### 3. Add Compression
```python
# Instead of delete, compress:
shutil.make_archive(f"{backup_path}.tar.gz", "gztar", backup_path)
shutil.rmtree(backup_path)
```

### 4. Add Archival
```python
# Instead of delete, move to archive:
archive_path = "/path/to/archive"
shutil.move(backup_path, os.path.join(archive_path, backup_name))
```

---

## 📦 Dependencies Used

### Imports (All Existing)
```python
import os               # Directory operations
import shutil          # Tree operations (copy, remove)
from datetime import datetime  # Timestamps
# Colors class - defined in same file
```

### No New Imports Required
✅ Uses only existing imports  
✅ No external packages needed  
✅ Standard library only

### Used Methods
```python
os.path.exists(path)      # Check if exists
os.listdir(path)          # List directory contents
os.path.isdir(path)       # Check if directory
os.path.getmtime(path)    # Get modification time
os.path.join(...)         # Build paths
shutil.rmtree(path)       # Delete directory tree
self.log_activity(...)    # Existing logging
print(...)                # Console output
Colors.YELLOW/GREEN/RED   # Color codes (existing)
```

---

## ⚡ Performance Notes

| Operation | Time | Notes |
|-----------|------|-------|
| List 10 backups | <1ms | Very fast |
| Sort 10 items | <1ms | Very fast |
| Delete 1 backup | 50-500ms | Depends on size |
| **Total (1 deletion)** | ~100-600ms | Negligible |

**Impact:** Minimal - typically <1 second even for slow systems

---

## 🧪 Testing Code Snippets

### Test 1: Verify Method Exists
```python
import cis_k8s_unified
runner = cis_k8s_unified.CISUnifiedRunner(config_file)
assert hasattr(runner, '_rotate_backups'), "Method not found"
print("✓ Method exists")
```

### Test 2: Test Rotation Logic
```python
# Create 8 test backups
for i in range(8):
    os.makedirs(f"test_backups/backup_{i:08d}")

runner.backup_dir = "test_backups"
runner._rotate_backups(max_backups=5)

# Verify only 5 remain
remaining = len(os.listdir("test_backups"))
assert remaining == 5, f"Expected 5, got {remaining}"
print("✓ Rotation works correctly")
```

### Test 3: Test Error Handling
```python
# Test with read-only directory
os.chmod("test_backups", 0o444)
runner._rotate_backups(max_backups=5)  # Should not crash
print("✓ Error handling works")
```

---

## 📞 Quick Reference

| What | Where | How |
|------|-------|-----|
| New method | Lines 1801-1843 | `def _rotate_backups(...)` |
| Rotation call | Line 1881 | `self._rotate_backups(max_backups=5)` |
| Log rotation | Line 1838 | `self.log_activity("BACKUP_ROTATION", ...)` |
| Print message | Line 1839 | `print(f"[INFO] Cleaned up...")` |
| Delete backup | Line 1833 | `shutil.rmtree(backup_path)` |
| Sort backups | Line 1824 | `backup_folders.sort(key=...)` |
| Filter dirs | Line 1820 | `if item.startswith("backup_")` |

---

**Complete code reference for Backup Rotation feature.**

For implementation guide, see: [BACKUP_ROTATION_FEATURE.md](docs/BACKUP_ROTATION_FEATURE.md)  
For quick reference, see: [BACKUP_ROTATION_QUICK_REFERENCE.md](BACKUP_ROTATION_QUICK_REFERENCE.md)
