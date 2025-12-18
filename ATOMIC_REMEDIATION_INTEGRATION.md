"""
Integration Guide: Using Atomic Remediation Manager in cis_k8s_unified.py

This file shows how to integrate the AtomicRemediationManager into the CIS K8s
unified runner to provide atomic writes, automatic backups, and auto-rollback.
"""

# ============================================================================
# STEP 1: Add imports to cis_k8s_unified.py
# ============================================================================

# Add these imports at the top of cis_k8s_unified.py:
"""
from atomic_remediation import AtomicRemediationManager, RemediationFlow
import subprocess
"""


# ============================================================================
# STEP 2: Initialize in __init__ method of CISUnifiedRunner
# ============================================================================

def __init__(self, verbose=0):
    """Initialize runner with configuration"""
    # ... existing code ...
    
    # Add after self.load_config():
    self.atomic_manager = AtomicRemediationManager(
        backup_dir=self.backup_dir
    )
    self.remediation_flow = RemediationFlow(self.atomic_manager)


# ============================================================================
# STEP 3: Create new method: update_manifest_safely
# ============================================================================

def update_manifest_safely(self, filepath: str, key: str, value: str) -> tuple:
    """
    Safely update a Kubernetes manifest file with atomic write and rollback.
    
    This is a wrapper around update_manifest_safely that also handles the
    remediation verification step.
    
    Args:
        filepath: Path to the manifest file (e.g., /etc/kubernetes/manifests/kube-apiserver.yaml)
        key: The flag key (e.g., --anonymous-auth)
        value: The flag value (e.g., false)
    
    Returns:
        Tuple of (success: bool, backup_path: str, message: str)
    
    Example:
        success, backup, msg = self.update_manifest_safely(
            "/etc/kubernetes/manifests/kube-apiserver.yaml",
            "--anonymous-auth",
            "false"
        )
    """
    try:
        self.log_activity(f"MANIFEST_UPDATE", f"Updating {filepath} with {key}={value}")
        
        # Prepare modifications in the format expected by AtomicRemediationManager
        modifications = {
            'flags': [f"{key}={value}"]
        }
        
        # Call atomic update
        success, message = self.atomic_manager.update_manifest_safely(
            filepath,
            modifications
        )
        
        if not success:
            self.log_activity(f"MANIFEST_UPDATE_FAILED", message)
            return False, "", message
        
        # Wait for cluster to stabilize
        logger.info(f"Waiting for cluster to stabilize after manifest update...")
        health_ok, health_msg = self.atomic_manager.wait_for_cluster_healthy()
        
        if not health_ok:
            logger.error(f"Cluster health check failed after manifest update!")
            logger.info(f"Health status: {health_msg}")
            return False, "", f"Cluster health check failed: {health_msg}"
        
        self.log_activity(f"MANIFEST_UPDATE_SUCCESS", f"Updated {key} to {value}")
        return True, "", message
    
    except Exception as e:
        logger.error(f"Error updating manifest safely: {e}")
        return False, "", str(e)


# ============================================================================
# STEP 4: Refactor run_script method to use atomic operations
# ============================================================================

def run_script(self, script, mode):
    """
    Execute audit/remediation script with ATOMIC writes and auto-rollback.
    Enhanced remediation flow:
    
    1. Create snapshot (backup) - BEFORE any changes
    2. Apply changes (using atomic write)
    3. Health check barrier - WAIT for cluster to stabilize
    4. Run audit script - VERIFY remediation worked
    5. Rollback if anything fails - AUTO-RECOVERY
    """
    
    if self.stop_requested:
        return None
    
    start_time = time.time()
    script_id = script["id"]
    
    # Check if rule is excluded
    if self.is_rule_excluded(script_id):
        return self._create_result(
            script, "IGNORED",
            f"Excluded: {self.excluded_rules.get(script_id, 'No reason')}",
            time.time() - start_time
        )
    
    try:
        # Check remediation config
        if mode == "remediate":
            remediation_cfg = self.get_remediation_config_for_check(script_id)
            if remediation_cfg.get("skip", False) or not remediation_cfg.get("enabled", True):
                return self._create_result(
                    script, "SKIPPED",
                    f"Skipped by remediation config",
                    time.time() - start_time
                )
        
        # Check if manual check
        is_manual = self._is_manual_check(script["path"])
        
        if is_manual and self.skip_manual and mode == "audit":
            return self._create_result(
                script, "SKIPPED",
                "Manual check skipped by user",
                time.time() - start_time
            )
        
        # ================================================================
        # ENHANCED REMEDIATION WITH ATOMIC WRITES
        # ================================================================
        if mode == "remediate":
            requires_health_check, _ = self._classify_remediation_type(script_id)
            
            # Use atomic remediation flow
            logger.info(f"\n{Colors.BOLD}[REMEDIATION FLOW] {script_id}{Colors.ENDC}")
            logger.info(f"{'='*70}")
            
            # Get remediation config
            remediation_cfg = self.get_remediation_config_for_check(script_id)
            manifest_file = remediation_cfg.get("manifest", remediation_cfg.get("config_file"))
            
            if manifest_file and requires_health_check:
                # ATOMIC REMEDIATION APPROACH
                logger.info(f"Phase 1: Creating backup...")
                backup_ok, backup_path = self.atomic_manager.create_backup(manifest_file)
                
                if not backup_ok:
                    return self._create_result(
                        script, "FAILED",
                        f"Could not create backup",
                        time.time() - start_time
                    )
                
                # Phase 2: Apply modifications
                logger.info(f"Phase 2: Applying manifest modifications...")
                flag_key = remediation_cfg.get("flag_name", remediation_cfg.get("flag"))
                expected_value = remediation_cfg.get("expected_value", remediation_cfg.get("required_value"))
                
                if flag_key and expected_value:
                    success, msg = self.atomic_manager.update_manifest_safely(
                        manifest_file,
                        {'flags': [f"{flag_key}={expected_value}"]}
                    )
                    
                    if not success:
                        logger.error(f"Failed to update manifest: {msg}")
                        return self._create_result(
                            script, "FAILED",
                            f"Failed to update manifest: {msg}",
                            time.time() - start_time
                        )
                
                # Phase 3: Wait for cluster to be healthy
                logger.info(f"Phase 3: Waiting for cluster health check (timeout: 60s)...")
                health_ok, health_msg = self.atomic_manager.wait_for_cluster_healthy(timeout=60)
                
                if not health_ok:
                    logger.critical(f"Cluster health check FAILED! Triggering automatic rollback...")
                    rollback_ok, rollback_msg = self.atomic_manager.rollback(manifest_file, backup_path)
                    
                    if rollback_ok:
                        logger.info(f"✅ Rollback successful: {rollback_msg}")
                    else:
                        logger.error(f"❌ Rollback FAILED: {rollback_msg}")
                    
                    return self._create_result(
                        script, "FAILED",
                        f"Cluster health check failed. Auto-rollback triggered. Details: {health_msg}",
                        time.time() - start_time
                    )
                
                logger.info(f"✅ Cluster health check PASSED")
                
                # Phase 4: Run audit to verify remediation
                logger.info(f"Phase 4: Running audit verification...")
                audit_script = script["path"].replace("_remediate.sh", "_audit.sh")
                
                if os.path.exists(audit_script):
                    audit_ok, audit_output = self.atomic_manager.verify_remediation(
                        script_id,
                        audit_script
                    )
                    
                    if not audit_ok:
                        logger.warning(f"Audit verification FAILED! Rolling back...")
                        rollback_ok, rollback_msg = self.atomic_manager.rollback(manifest_file, backup_path)
                        
                        return self._create_result(
                            script, "FAILED",
                            f"Audit verification failed. Rollback: {rollback_ok}",
                            time.time() - start_time
                        )
                
                logger.info(f"{'='*70}")
                logger.info(f"✅ REMEDIATION COMPLETE AND VERIFIED for {script_id}\n")
                
                return self._create_result(
                    script, "PASSED",
                    "Remediation applied and verified",
                    time.time() - start_time
                )
        
        # ================================================================
        # REGULAR EXECUTION (non-atomic for audit scripts)
        # ================================================================
        env = os.environ.copy()
        kubeconfig_paths = [
            os.environ.get('KUBECONFIG'),
            "/etc/kubernetes/admin.conf",
            os.path.expanduser("~/.kube/config"),
        ]
        env['KUBECONFIG'] = ":".join([p for p in kubeconfig_paths if p])
        
        # Execute script
        logger.info(f"Executing: {script['path']}")
        process = subprocess.Popen(
            ['bash', script['path']],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            env=env,
            text=True
        )
        
        try:
            stdout, _ = process.communicate(timeout=self.script_timeout)
            return_code = process.returncode
        except subprocess.TimeoutExpired:
            process.kill()
            return self._create_result(
                script, "TIMEOUT",
                f"Script execution exceeded {self.script_timeout}s",
                time.time() - start_time
            )
        
        # Parse results
        if return_code == 0:
            status = "PASSED"
        elif "[SKIP]" in stdout or "[MANUAL]" in stdout:
            status = "MANUAL"
            is_manual = True
        else:
            status = "FAILED"
        
        return self._create_result(
            script, status,
            stdout.strip(),
            time.time() - start_time
        )
    
    except Exception as e:
        logger.error(f"Error executing script {script_id}: {e}")
        return self._create_result(
            script, "ERROR",
            str(e),
            time.time() - start_time
        )


# ============================================================================
# STEP 5: Add to requirements.txt
# ============================================================================

# Add these Python packages:
"""
PyYAML>=5.4
requests>=2.25.0
urllib3>=1.26.0
"""

# Install with:
# pip install -r requirements.txt


# ============================================================================
# STEP 6: Environment Setup
# ============================================================================

# Ensure the backup directory exists with proper permissions:
"""
sudo mkdir -p /var/backups/cis-remediation
sudo chmod 700 /var/backups/cis-remediation
sudo chown root:root /var/backups/cis-remediation
"""

# Enable logging:
"""
sudo mkdir -p /var/log/cis-remediation
sudo touch /var/log/cis-remediation-atomic.log
sudo chmod 666 /var/log/cis-remediation-atomic.log
"""


# ============================================================================
# EXECUTION FLOW DIAGRAM
# ============================================================================

"""
Remediation Flow with Atomic Writes and Auto-Rollback:

┌─────────────────────────────────────────────────────────────┐
│ User initiates remediation for check 1.2.1                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │ Phase 1: Create Backup│
        │ (Snapshot)            │
        └───────────┬───────────┘
                    │
        ✓ Success   │   ✗ Fail
                    ▼
        ┌───────────────────────┐
        │ Phase 2: Atomic Write │
        │ (Temp + Replace)      │
        └───────────┬───────────┘
                    │
        ✓ Success   │   ✗ Fail
                    ▼
        ┌───────────────────────┐
        │ Phase 3: Health Check │
        │ (Wait for API)        │
        └───────────┬───────────┘
                    │
                    ├─ ✓ Healthy ──────────────────┐
                    │                              │
                    └─ ✗ Unhealthy                 │
                       (Timeout)                   │
                       │                           │
                       ▼                           ▼
                  ┌──────────┐           ┌──────────────────┐
                  │ ROLLBACK │           │ Phase 4: Verify  │
                  │ (Restore)│           │ (Run Audit)      │
                  └──────────┘           └────────┬─────────┘
                       │                          │
                       │                  ✓ Pass  │  ✗ Fail
                       │                          ▼
                       │                     ┌──────────┐
                       │                     │ ROLLBACK │
                       │                     │ (Restore)│
                       │                     └──────────┘
                       │                          │
                       ▼                          ▼
                 ┌──────────────────────────────────────┐
                 │ FAILURE: Manual Review Required      │
                 │ Backup preserved at: /var/backups/   │
                 └──────────────────────────────────────┘
                 
                             OR
                 
                 ┌──────────────────────────────────────┐
                 │ SUCCESS: Remediation Complete        │
                 │ Backup: /var/backups/manifest.bak_*  │
                 └──────────────────────────────────────┘
"""

# ============================================================================
# LOGGING OUTPUT EXAMPLE
# ============================================================================

"""
[2025-12-18 10:45:23] [INFO] Remediation FLOW for 1.2.1
======================================================================
[2025-12-18 10:45:23] [INFO] Phase 1: Creating backup...
[2025-12-18 10:45:23] [INFO] Backup created: /var/backups/kube-apiserver.yaml.bak_20251218_104523
[2025-12-18 10:45:23] [INFO] Phase 2: Applying manifest modifications...
[2025-12-18 10:45:23] [INFO] Reading file: /etc/kubernetes/manifests/kube-apiserver.yaml
[2025-12-18 10:45:23] [INFO] Atomically replacing original file with modified version
[2025-12-18 10:45:23] [INFO] Successfully updated manifest: /etc/kubernetes/manifests/kube-apiserver.yaml
[2025-12-18 10:45:23] [INFO] Phase 3: Waiting for cluster health check (timeout: 60s)...
[2025-12-18 10:45:23] [INFO] Checking cluster health at https://127.0.0.1:6443/healthz
[2025-12-18 10:45:24] [DEBUG] Connection attempt 1: Connection refused
[2025-12-18 10:45:26] [DEBUG] Connection attempt 2: Connection refused
[2025-12-18 10:45:28] [INFO] API responsive (status 200). Waiting 15s for full startup...
[2025-12-18 10:45:43] [INFO] Cluster healthy after 20.1s
[2025-12-18 10:45:43] [INFO] ✅ Cluster health check PASSED
[2025-12-18 10:45:43] [INFO] Phase 4: Running audit verification...
[2025-12-18 10:45:43] [INFO] Verifying remediation for 1.2.1 using /path/to/1.2.1_audit.sh
[2025-12-18 10:45:53] [INFO] Verification passed for 1.2.1
======================================================================
[2025-12-18 10:45:53] [INFO] ✅ REMEDIATION COMPLETE AND VERIFIED for 1.2.1
"""
