# Atomic Operations - Code Examples & Integration Patterns

## Table of Contents
1. [Quick Start](#quick-start)
2. [Integration Examples](#integration-examples)
3. [Advanced Patterns](#advanced-patterns)
4. [Error Handling](#error-handling)
5. [Real-World Use Cases](#real-world-use-cases)

---

## Quick Start

### Example 1: Basic Atomic Modification

```python
from cis_k8s_unified import CISUnifiedRunner

# Initialize runner
runner = CISUnifiedRunner(verbose=1)

# Modify a manifest file atomically
result = runner.update_manifest_safely(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-policy-file=",
    value="/etc/kubernetes/audit-policy.yaml"
)

# Check result
if result['success']:
    print(f"✓ Success: {result['message']}")
    print(f"  Backup: {result['backup_path']}")
    print(f"  Changes: {result['changes_made']}")
else:
    print(f"✗ Failed: {result['message']}")
```

### Example 2: Health-Gated Remediation (Complete Flow)

```python
from cis_k8s_unified import CISUnifiedRunner

runner = CISUnifiedRunner(verbose=1)

# Apply remediation with automatic health checks and rollback
result = runner.apply_remediation_with_health_gate(
    filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
    key="--audit-log-maxage=",
    value="30",
    check_id="1.2.26",
    script_dict={"path": "/path/to/Level_1_Master_Node/1.2.26_remediate.sh"},
    timeout=60
)

# Handle result
if result['success']:
    print(f"✓ Remediation successful and verified")
    if result['audit_verified']:
        print("  Audit check passed")
else:
    print(f"✗ Remediation failed: {result['reason']}")
    if result['backup_path']:
        print(f"  Manual recovery: sudo cp {result['backup_path']} {result['original_path']}")
```

---

## Integration Examples

### Example 3: Integrating with Existing Remediation Script

```python
"""
Replace direct manifest modification with atomic operations
in your remediation logic.
"""

class APIServerRemediationHelper:
    def __init__(self, runner):
        self.runner = runner
        self.manifest_path = "/etc/kubernetes/manifests/kube-apiserver.yaml"
    
    def remediate_1_2_5_audit_policy(self):
        """
        CIS 1.2.5: Ensure that the --audit-policy-file argument is set
        """
        result = self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest_path,
            key="--audit-policy-file=",
            value="/etc/kubernetes/audit-policy.yaml",
            check_id="1.2.5",
            script_dict={"path": "./Level_1_Master_Node/1.2.5_remediate.sh"},
            timeout=60
        )
        
        return {
            'status': 'FIXED' if result['success'] else 'REMEDIATION_FAILED',
            'reason': result['reason'],
            'backup': result['backup_path']
        }
    
    def remediate_1_2_26_audit_log_maxage(self):
        """
        CIS 1.2.26: Ensure that the --audit-log-maxage argument is set to 30 or as appropriate
        """
        result = self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest_path,
            key="--audit-log-maxage=",
            value="30",
            check_id="1.2.26",
            script_dict={"path": "./Level_1_Master_Node/1.2.26_remediate.sh"},
            timeout=60
        )
        
        return {
            'status': 'FIXED' if result['success'] else 'REMEDIATION_FAILED',
            'reason': result['reason'],
            'backup': result['backup_path']
        }
    
    def remediate_1_2_27_audit_log_maxbackup(self):
        """
        CIS 1.2.27: Ensure that the --audit-log-maxbackup argument is set to 10 or as appropriate
        """
        result = self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest_path,
            key="--audit-log-maxbackup=",
            value="10",
            check_id="1.2.27",
            script_dict={"path": "./Level_1_Master_Node/1.2.27_remediate.sh"},
            timeout=60
        )
        
        return {
            'status': 'FIXED' if result['success'] else 'REMEDIATION_FAILED',
            'reason': result['reason'],
            'backup': result['backup_path']
        }

# Usage
runner = CISUnifiedRunner(verbose=1)
helper = APIServerRemediationHelper(runner)

# Apply remediations
for remediation_func in [
    helper.remediate_1_2_5_audit_policy,
    helper.remediate_1_2_26_audit_log_maxage,
    helper.remediate_1_2_27_audit_log_maxbackup
]:
    result = remediation_func()
    print(f"{remediation_func.__name__}: {result['status']}")
```

### Example 4: Batch Modification with Rollback on Failure

```python
def apply_api_server_remediations_batch(runner, remediations):
    """
    Apply multiple API server remediations sequentially.
    If any fails, all are rolled back.
    
    Args:
        runner: CISUnifiedRunner instance
        remediations: List of tuples (key, value, check_id)
    """
    manifest_path = "/etc/kubernetes/manifests/kube-apiserver.yaml"
    backup_path = None
    applied_changes = []
    
    # Create initial backup
    import shutil
    from datetime import datetime
    
    backup_path = f"{manifest_path}.batch_bak_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    try:
        shutil.copy2(manifest_path, backup_path)
        print(f"[*] Batch backup created: {backup_path}")
    except Exception as e:
        print(f"[ERROR] Failed to create batch backup: {e}")
        return {'success': False, 'reason': 'Backup creation failed'}
    
    # Apply changes sequentially
    for key, value, check_id in remediations:
        print(f"\n[*] Applying change: {check_id} - {key}={value}")
        
        result = runner.apply_remediation_with_health_gate(
            filepath=manifest_path,
            key=key,
            value=value,
            check_id=check_id,
            script_dict={"path": f"./Level_1_Master_Node/{check_id}_remediate.sh"},
            timeout=60
        )
        
        if result['success']:
            print(f"[✓] Applied: {check_id}")
            applied_changes.append((check_id, key, value, result['reason']))
        else:
            print(f"[✗] Failed: {check_id}")
            print(f"    Reason: {result['reason']}")
            print(f"[!] Rolling back all changes...")
            
            # Rollback entire batch
            try:
                import shutil
                shutil.copy2(backup_path, manifest_path)
                time.sleep(5)
                runner.wait_for_healthy_cluster(skip_health_check=False)
                print(f"[✓] Batch rollback completed")
            except Exception as e:
                print(f"[ERROR] Batch rollback failed: {e}")
            
            return {
                'success': False,
                'reason': f'Failed at {check_id}: {result["reason"]}',
                'applied_changes': applied_changes,
                'backup_path': backup_path
            }
    
    # All changes applied successfully
    print(f"\n[✓] All {len(applied_changes)} changes applied successfully")
    
    return {
        'success': True,
        'reason': f'Applied {len(applied_changes)} changes',
        'applied_changes': applied_changes,
        'backup_path': backup_path
    }

# Usage
runner = CISUnifiedRunner(verbose=1)

remediations = [
    ("--audit-policy-file=", "/etc/kubernetes/audit-policy.yaml", "1.2.5"),
    ("--audit-log-maxage=", "30", "1.2.26"),
    ("--audit-log-maxbackup=", "10", "1.2.27"),
]

result = apply_api_server_remediations_batch(runner, remediations)
print(f"\nBatch result: {result['success']}")
for change in result.get('applied_changes', []):
    print(f"  ✓ {change[0]}: {change[1]}={change[2]}")
```

---

## Advanced Patterns

### Example 5: Custom Key-Value Parser

```python
def apply_remediation_with_custom_format(runner, manifest_path, modifications):
    """
    Apply multiple modifications to manifest with custom parsing.
    
    Supports formats:
    - --key=value
    - --key value
    - key: value
    """
    for key, value, check_id in modifications:
        result = runner.update_manifest_safely(
            filepath=manifest_path,
            key=key,
            value=value
        )
        
        if result['success']:
            print(f"✓ {check_id}: {key}={value}")
        else:
            print(f"✗ {check_id}: {result['message']}")

# Usage
modifications = [
    ("--audit-policy-file=", "/etc/kubernetes/audit-policy.yaml", "1.2.5"),
    ("--encryption-provider-config=", "/etc/kubernetes/encryption.yaml", "1.2.30"),
]

apply_remediation_with_custom_format(
    runner,
    "/etc/kubernetes/manifests/kube-apiserver.yaml",
    modifications
)
```

### Example 6: Parallel Remediation with Coordination

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
import time

def apply_parallel_remediations(runner, manifest_groups):
    """
    Apply remediations in parallel, but coordinate API health checks.
    
    Note: This is an advanced pattern. Use with caution on production clusters!
    
    Args:
        runner: CISUnifiedRunner instance
        manifest_groups: Dict of manifest_path -> [(key, value, check_id), ...]
    """
    results = {}
    
    def apply_single_remediation(manifest_path, modifications):
        """Apply modifications to a single manifest"""
        backup_path = None
        applied = []
        
        try:
            # Backup manifest
            import shutil
            from datetime import datetime
            
            backup_path = f"{manifest_path}.par_bak_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            shutil.copy2(manifest_path, backup_path)
            
            # Apply each modification
            for key, value, check_id in modifications:
                result = runner.update_manifest_safely(manifest_path, key, value)
                
                if result['success']:
                    applied.append((check_id, True, result['message']))
                else:
                    applied.append((check_id, False, result['message']))
                    # Rollback on first failure
                    break
            
            return {
                'manifest': manifest_path,
                'backup': backup_path,
                'applied': applied,
                'success': all(a[1] for a in applied)
            }
        
        except Exception as e:
            return {
                'manifest': manifest_path,
                'backup': backup_path,
                'applied': applied,
                'success': False,
                'error': str(e)
            }
    
    # Apply remediations in parallel (different manifests only!)
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {
            executor.submit(apply_single_remediation, manifest, mods): manifest
            for manifest, mods in manifest_groups.items()
        }
        
        for future in as_completed(futures):
            manifest = futures[future]
            try:
                result = future.result()
                results[manifest] = result
            except Exception as e:
                results[manifest] = {'success': False, 'error': str(e)}
    
    # Coordinate health check (only once, after all modifications)
    print("[*] Running coordinated health check...")
    if runner.wait_for_healthy_cluster(skip_health_check=False):
        print("[✓] All manifests healthy")
        return {'success': True, 'results': results}
    else:
        print("[✗] Health check failed - rolling back all changes")
        
        # Rollback all
        for manifest, result in results.items():
            if result.get('backup'):
                try:
                    import shutil
                    shutil.copy2(result['backup'], manifest)
                except:
                    pass
        
        return {'success': False, 'results': results}

# Usage - safe for different manifest files
manifest_groups = {
    "/etc/kubernetes/manifests/kube-apiserver.yaml": [
        ("--audit-policy-file=", "/etc/kubernetes/audit-policy.yaml", "1.2.5"),
    ],
    "/var/lib/kubelet/config.yaml": [
        ("--protect-kernel-defaults", "true", "4.2.6"),
    ]
}

result = apply_parallel_remediations(runner, manifest_groups)
```

---

## Error Handling

### Example 7: Comprehensive Error Handling

```python
def safe_remediate_with_error_handling(runner, check_id, key, value, manifest_path):
    """
    Apply remediation with comprehensive error handling and recovery.
    """
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"Starting remediation: {check_id}")
        
        # Step 1: Validation
        if not os.path.exists(manifest_path):
            logger.error(f"Manifest not found: {manifest_path}")
            return {'success': False, 'error': 'MANIFEST_NOT_FOUND'}
        
        if not os.access(manifest_path, os.W_OK):
            logger.error(f"No write access: {manifest_path}")
            return {'success': False, 'error': 'PERMISSION_DENIED'}
        
        # Step 2: Apply remediation
        result = runner.apply_remediation_with_health_gate(
            filepath=manifest_path,
            key=key,
            value=value,
            check_id=check_id,
            script_dict={"path": f"./Level_1_Master_Node/{check_id}_remediate.sh"},
            timeout=60
        )
        
        # Step 3: Handle result
        if result['success']:
            logger.info(f"✓ Remediation successful: {check_id}")
            return {
                'success': True,
                'status': result['status'],
                'backup': result['backup_path'],
                'verified': result['audit_verified']
            }
        
        else:
            logger.error(f"✗ Remediation failed: {result['reason']}")
            
            # Provide recovery instructions
            if result['backup_path']:
                recovery_cmd = f"sudo cp {result['backup_path']} {manifest_path}"
                logger.info(f"Manual recovery: {recovery_cmd}")
            
            return {
                'success': False,
                'status': result['status'],
                'reason': result['reason'],
                'backup': result['backup_path']
            }
    
    except KeyboardInterrupt:
        logger.warning("Remediation interrupted by user")
        return {'success': False, 'error': 'USER_INTERRUPT'}
    
    except Exception as e:
        logger.exception(f"Unexpected error during remediation: {e}")
        return {'success': False, 'error': f'UNEXPECTED_ERROR: {str(e)}'}

# Usage
result = safe_remediate_with_error_handling(
    runner,
    "1.2.5",
    "--audit-policy-file=",
    "/etc/kubernetes/audit-policy.yaml",
    "/etc/kubernetes/manifests/kube-apiserver.yaml"
)

if not result['success']:
    print(f"Recovery needed: {result.get('backup')}")
```

### Example 8: Retry Logic with Exponential Backoff

```python
import time
import random

def remediate_with_retry(runner, check_id, key, value, manifest_path, max_retries=3):
    """
    Apply remediation with retry logic and exponential backoff.
    """
    for attempt in range(1, max_retries + 1):
        print(f"\n[*] Attempt {attempt}/{max_retries}: {check_id}")
        
        try:
            result = runner.apply_remediation_with_health_gate(
                filepath=manifest_path,
                key=key,
                value=value,
                check_id=check_id,
                script_dict={"path": f"./Level_1_Master_Node/{check_id}_remediate.sh"},
                timeout=60
            )
            
            if result['success']:
                print(f"[✓] Success on attempt {attempt}")
                return result
            
            # Check if retryable error
            if result['status'] in ['REMEDIATION_FAILED_ROLLED_BACK', 'REMEDIATION_FAILED']:
                if attempt < max_retries:
                    # Calculate backoff: 2^attempt + random jitter
                    backoff = (2 ** attempt) + random.randint(0, 5)
                    print(f"[!] Retryable error, waiting {backoff}s before retry...")
                    time.sleep(backoff)
                    continue
            
            # Non-retryable error
            print(f"[✗] Non-retryable error: {result['reason']}")
            return result
        
        except Exception as e:
            print(f"[!] Exception on attempt {attempt}: {e}")
            if attempt < max_retries:
                time.sleep(2 ** attempt)
                continue
            return {'success': False, 'reason': f'Failed after {max_retries} attempts: {str(e)}'}
    
    return {'success': False, 'reason': f'Failed after {max_retries} attempts'}

# Usage
result = remediate_with_retry(
    runner, "1.2.5", "--audit-policy-file=",
    "/etc/kubernetes/audit-policy.yaml",
    "/etc/kubernetes/manifests/kube-apiserver.yaml",
    max_retries=3
)
```

---

## Real-World Use Cases

### Example 9: CIS 1.2.x - API Server Audit Remediations

```python
class APIServerAuditRemediations:
    """
    Complete remediation suite for CIS 1.2.x audit policy checks
    """
    
    def __init__(self, runner):
        self.runner = runner
        self.manifest = "/etc/kubernetes/manifests/kube-apiserver.yaml"
        self.audit_policy = "/etc/kubernetes/audit-policy.yaml"
        self.results = {}
    
    def remediate_1_2_5_audit_policy_file(self):
        """CIS 1.2.5: Ensure that the --audit-policy-file argument is set"""
        return self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest,
            key="--audit-policy-file=",
            value=self.audit_policy,
            check_id="1.2.5",
            script_dict={"path": "./Level_1_Master_Node/1.2.5_remediate.sh"}
        )
    
    def remediate_1_2_26_audit_log_maxage(self):
        """CIS 1.2.26: Ensure --audit-log-maxage is set to 30 or as appropriate"""
        return self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest,
            key="--audit-log-maxage=",
            value="30",
            check_id="1.2.26",
            script_dict={"path": "./Level_1_Master_Node/1.2.26_remediate.sh"}
        )
    
    def remediate_1_2_27_audit_log_maxbackup(self):
        """CIS 1.2.27: Ensure --audit-log-maxbackup is set to 10 or as appropriate"""
        return self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest,
            key="--audit-log-maxbackup=",
            value="10",
            check_id="1.2.27",
            script_dict={"path": "./Level_1_Master_Node/1.2.27_remediate.sh"}
        )
    
    def remediate_1_2_28_audit_log_maxsize(self):
        """CIS 1.2.28: Ensure --audit-log-maxsize is set to 100 or as appropriate"""
        return self.runner.apply_remediation_with_health_gate(
            filepath=self.manifest,
            key="--audit-log-maxsize=",
            value="100",
            check_id="1.2.28",
            script_dict={"path": "./Level_1_Master_Node/1.2.28_remediate.sh"}
        )
    
    def apply_all(self):
        """Apply all audit-related remediations"""
        remediations = [
            ("1.2.5", self.remediate_1_2_5_audit_policy_file),
            ("1.2.26", self.remediate_1_2_26_audit_log_maxage),
            ("1.2.27", self.remediate_1_2_27_audit_log_maxbackup),
            ("1.2.28", self.remediate_1_2_28_audit_log_maxsize),
        ]
        
        print(f"\n{Colors.BOLD}[*] Applying API Server Audit Remediations{Colors.ENDC}")
        
        success_count = 0
        for check_id, remediate_func in remediations:
            try:
                result = remediate_func()
                
                if result['success']:
                    self.results[check_id] = 'FIXED'
                    success_count += 1
                    print(f"{Colors.GREEN}[✓] {check_id}: {result['reason']}{Colors.ENDC}")
                else:
                    self.results[check_id] = 'REMEDIATION_FAILED'
                    print(f"{Colors.RED}[✗] {check_id}: {result['reason']}{Colors.ENDC}")
            
            except Exception as e:
                self.results[check_id] = 'ERROR'
                print(f"{Colors.RED}[✗] {check_id}: Exception - {str(e)}{Colors.ENDC}")
        
        print(f"\nSummary: {success_count}/{len(remediations)} successful")
        return self.results

# Usage
runner = CISUnifiedRunner(verbose=1)
remediator = APIServerAuditRemediations(runner)
results = remediator.apply_all()
```

### Example 10: Full Production Remediation Workflow

```python
def production_remediation_workflow(runner, target_level="1"):
    """
    Complete production-safe remediation workflow with safeguards.
    """
    
    import sys
    import json
    from datetime import datetime
    
    # ========== Pre-Remediation Checks ==========
    print(f"\n{Colors.BOLD}[PRE-FLIGHT CHECKS]{Colors.ENDC}")
    
    # Check cluster health
    if not runner.wait_for_healthy_cluster(skip_health_check=False):
        print(f"{Colors.RED}[ABORT] Cluster is not healthy. Cannot proceed with remediation.{Colors.ENDC}")
        return {'success': False, 'reason': 'CLUSTER_UNHEALTHY'}
    
    print(f"{Colors.GREEN}[✓] Cluster is healthy{Colors.ENDC}")
    
    # Create full cluster backup
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = f"/var/backups/cis-full-{timestamp}"
    
    print(f"[*] Creating full cluster backup...")
    try:
        os.makedirs(backup_dir, exist_ok=True)
        
        # Backup all manifests
        manifest_dir = "/etc/kubernetes/manifests"
        for manifest_file in os.listdir(manifest_dir):
            if manifest_file.endswith('.yaml'):
                src = os.path.join(manifest_dir, manifest_file)
                dst = os.path.join(backup_dir, manifest_file)
                shutil.copy2(src, dst)
        
        print(f"{Colors.GREEN}[✓] Backup created: {backup_dir}{Colors.ENDC}")
    
    except Exception as e:
        print(f"{Colors.RED}[ABORT] Backup failed: {e}{Colors.ENDC}")
        return {'success': False, 'reason': 'BACKUP_FAILED', 'backup_dir': backup_dir}
    
    # ========== Apply Remediations ==========
    print(f"\n{Colors.BOLD}[APPLYING REMEDIATIONS]{Colors.ENDC}")
    
    remediations = [
        ("1.2.5", "--audit-policy-file=", "/etc/kubernetes/audit-policy.yaml"),
        ("1.2.26", "--audit-log-maxage=", "30"),
        ("1.2.27", "--audit-log-maxbackup=", "10"),
        ("1.2.28", "--audit-log-maxsize=", "100"),
    ]
    
    results = {}
    failed_checks = []
    
    for check_id, key, value in remediations:
        result = runner.apply_remediation_with_health_gate(
            filepath="/etc/kubernetes/manifests/kube-apiserver.yaml",
            key=key,
            value=value,
            check_id=check_id,
            script_dict={"path": f"./Level_1_Master_Node/{check_id}_remediate.sh"}
        )
        
        results[check_id] = result
        
        if result['success']:
            print(f"{Colors.GREEN}[✓] {check_id}{Colors.ENDC}")
        else:
            print(f"{Colors.RED}[✗] {check_id}{Colors.ENDC}")
            failed_checks.append(check_id)
    
    # ========== Post-Remediation Verification ==========
    print(f"\n{Colors.BOLD}[POST-REMEDIATION VERIFICATION]{Colors.ENDC}")
    
    if failed_checks:
        print(f"{Colors.RED}[!] Failed checks: {', '.join(failed_checks)}{Colors.ENDC}")
        print(f"{Colors.YELLOW}[*] Manual recovery available:{Colors.ENDC}")
        print(f"    sudo cp -r {backup_dir}/* /etc/kubernetes/manifests/")
        print(f"    sudo systemctl restart kubelet")
        
        return {
            'success': False,
            'reason': f'{len(failed_checks)} checks failed',
            'failed_checks': failed_checks,
            'backup_dir': backup_dir,
            'results': results
        }
    
    # All successful - verify cluster
    if not runner.wait_for_healthy_cluster(skip_health_check=False):
        print(f"{Colors.RED}[!] Cluster became unhealthy after remediations{Colors.ENDC}")
        print(f"{Colors.YELLOW}[*] Rolling back from: {backup_dir}{Colors.ENDC}")
        
        try:
            for manifest_file in os.listdir(backup_dir):
                src = os.path.join(backup_dir, manifest_file)
                dst = os.path.join("/etc/kubernetes/manifests", manifest_file)
                shutil.copy2(src, dst)
            
            time.sleep(5)
            runner.wait_for_healthy_cluster(skip_health_check=False)
            print(f"{Colors.GREEN}[✓] Rollback completed{Colors.ENDC}")
        
        except Exception as e:
            print(f"{Colors.RED}[CRITICAL] Rollback failed: {e}{Colors.ENDC}")
        
        return {
            'success': False,
            'reason': 'CLUSTER_UNHEALTHY_AFTER_REMEDIATION',
            'backup_dir': backup_dir
        }
    
    print(f"{Colors.GREEN}[✓] Cluster healthy after remediations{Colors.ENDC}")
    
    # ========== Success ==========
    print(f"\n{Colors.BOLD}{Colors.GREEN}[SUCCESS] All remediations applied successfully{Colors.ENDC}")
    print(f"{Colors.YELLOW}[*] Backup retained at: {backup_dir}{Colors.ENDC}")
    
    return {
        'success': True,
        'results': results,
        'backup_dir': backup_dir
    }

# Usage
runner = CISUnifiedRunner(verbose=1)
final_result = production_remediation_workflow(runner)

if final_result['success']:
    print(f"\n✓ Production remediation completed successfully")
else:
    print(f"\n✗ Production remediation had failures")
    print(f"  Backup: {final_result.get('backup_dir')}")
```

---

## Summary

These examples demonstrate:

1. ✅ **Basic operations** - single file modifications
2. ✅ **Health-gated flow** - full automated remediation with rollback
3. ✅ **Integration** - using atomic ops in existing code
4. ✅ **Batch operations** - multiple changes with coordinated rollback
5. ✅ **Error handling** - comprehensive exception handling
6. ✅ **Retry logic** - resilient remediations
7. ✅ **Production workflows** - safe enterprise-grade remediations

Choose the pattern that best fits your use case!
