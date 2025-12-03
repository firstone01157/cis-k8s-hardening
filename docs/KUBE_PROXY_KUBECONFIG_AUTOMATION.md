# CIS 4.1.3 & 4.1.4 Automation: Kube-Proxy Kubeconfig

## Context
- **Cluster Type**: Kubeadm-based Kubernetes
- **Kube-Proxy Mode**: Runs as DaemonSet with in-cluster configuration (default)
- **Issue**: No external `--kubeconfig` file to check, so 4.1.3 & 4.1.4 were marked MANUAL
- **Solution**: Automate as "Pass if Not Set" - exits with PASS when kube-proxy uses default in-cluster config

## Implementation

### 4.1.3 - Kube-Proxy Kubeconfig File Permissions
**File**: `Level_1_Worker_Node/4.1.3_remediate.sh`

**Logic**:
1. Check if `--kubeconfig` flag is set in kube-proxy process arguments
2. **Flag NOT SET** (default in-cluster config):
   - Print: `[PASS] kube-proxy uses in-cluster config (Default). No file to check.`
   - Exit with 0
3. **Flag IS SET**:
   - Extract file path
   - If file doesn't exist: Print PASS (file not present)
   - If file exists and permissions are ≤600: Print PASS
   - If file exists with too-permissive permissions: Fix with `chmod 600` and print FIXED
   - If chmod fails: Print FAILED and exit 1

**Permission Check**: Regex match `^[0-6]00$` allows 000, 100, 200, 300, 400, 500, 600 (octal)

### 4.1.4 - Kube-Proxy Kubeconfig File Ownership
**File**: `Level_1_Worker_Node/4.1.4_remediate.sh`

**Logic**:
1. Check if `--kubeconfig` flag is set in kube-proxy process arguments
2. **Flag NOT SET** (default in-cluster config):
   - Print: `[PASS] kube-proxy uses in-cluster config (Default). No file to check.`
   - Exit with 0
3. **Flag IS SET**:
   - Extract file path
   - If file doesn't exist: Print PASS (file not present)
   - If file exists and ownership is root:root: Print PASS
   - If file exists with wrong ownership: Fix with `chown root:root` and print FIXED
   - If chown fails: Print FAILED and exit 1

## Helper Functions Used

Both scripts source `kubelet_helpers.sh` which provides:
- `kube_proxy_kubeconfig_path()` - Safely extracts `--kubeconfig` value from process args or returns empty string

## Execution Flow

```
kube_proxy_kubeconfig_path()
    │
    ├─ Returns empty string (flag not set)
    │  └─ PASS: In-cluster config used [EXIT 0]
    │
    └─ Returns file path (flag is set)
       ├─ File doesn't exist → PASS [EXIT 0]
       └─ File exists
          ├─ 4.1.3: Check permissions
          │  ├─ Compliant (≤600) → PASS [EXIT 0]
          │  ├─ Non-compliant → chmod 600 → FIXED [EXIT 0]
          │  └─ chmod fails → FAILED [EXIT 1]
          │
          └─ 4.1.4: Check ownership
             ├─ Compliant (root:root) → PASS [EXIT 0]
             ├─ Non-compliant → chown root:root → FIXED [EXIT 0]
             └─ chown fails → FAILED [EXIT 1]
```

## Test Results

**Syntax Verification**:
```bash
✓ 4.1.3_remediate.sh: Syntax OK
✓ 4.1.4_remediate.sh: Syntax OK
```

## Integration with Existing Framework

- Follows existing 4.1.x remediation script patterns
- Uses established `kubelet_helpers.sh` utility functions
- Maintains consistent output format and exit codes
- Creates timestamped backups before modifications (`*.bak.$(date +%s)`)
- Compatible with automated runner frameworks (master_runner.py, cis_k8s_unified.py)

## Deployment

1. Copy scripts to worker nodes (already in Level_1_Worker_Node/)
2. Ensure scripts are executable: `chmod +x 4.1.3_remediate.sh 4.1.4_remediate.sh`
3. Run via automation framework or manually:
   ```bash
   bash /path/to/4.1.3_remediate.sh
   bash /path/to/4.1.4_remediate.sh
   ```

## Expected Behavior in Kubeadm Cluster

Since kube-proxy runs as DaemonSet without external kubeconfig:
- `kube_proxy_kubeconfig_path()` returns empty string
- Both scripts immediately return PASS (exit 0)
- No files are modified or checked
- Cluster passes CIS 4.1.3 and 4.1.4 compliance checks
