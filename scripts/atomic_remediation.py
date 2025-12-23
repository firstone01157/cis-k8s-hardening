#!/usr/bin/env python3
"""
Atomic Remediation Manager for CIS Kubernetes Hardening
Provides atomic write operations and auto-rollback functionality to prevent
remediation loops and cluster crashes.

Features:
- Atomic file writes with temporary files
- Automatic backup and rollback on failure
- Health check barrier before continuing
- Comprehensive logging and diagnostics
"""

import os
import sys
import shutil
import tempfile
import time
import logging
import json
import requests
from pathlib import Path
from typing import Optional, Tuple, Dict, Any
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/var/log/cis-remediation-atomic.log')
    ]
)
logger = logging.getLogger(__name__)


class Colors:
    """ANSI color codes for terminal output."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'


class AtomicRemediationManager:
    """
    Manages atomic file writes and automatic rollback for remediation operations.
    
    This class ensures that manifest modifications are applied atomically and can
    be rolled back if the cluster health check fails.
    """
    
    def __init__(self, backup_dir: str = "/var/backups/cis-remediation"):
        """
        Initialize the Atomic Remediation Manager.
        
        Args:
            backup_dir: Directory to store backup files for rollback
        """
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.health_check_url = "https://127.0.0.1:6443/healthz"
        self.health_check_timeout = 60  # seconds
        self.health_check_interval = 2  # seconds
        self.api_settle_time = 15  # Additional time to wait for API to fully settle
        
        logger.info(f"AtomicRemediationManager initialized with backup dir: {self.backup_dir}")
    
    def create_backup(self, filepath: str) -> Tuple[bool, str]:
        """
        Create a backup of the original file before modification.
        
        Args:
            filepath: Path to the file to backup
            
        Returns:
            Tuple of (success, backup_path)
        """
        try:
            filepath = Path(filepath)
            if not filepath.exists():
                logger.error(f"File does not exist: {filepath}")
                return False, ""
            
            # Create backup with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = self.backup_dir / f"{filepath.name}.bak_{timestamp}"
            
            # Copy file to backup location
            shutil.copy2(filepath, backup_path)
            
            logger.info(f"Backup created: {backup_path}")
            return True, str(backup_path)
        
        except Exception as e:
            logger.error(f"Failed to create backup of {filepath}: {e}")
            return False, ""
    
    def update_manifest_safely(self, filepath: str, modifications: Dict[str, Any]) -> Tuple[bool, str]:
        """
        Safely update a manifest file with atomic write.
        
        This method:
        1. Reads the original file
        2. Modifies content in memory using yaml library
        3. Writes to temporary file
        4. Flushes and syncs to ensure data is written
        5. Uses os.replace() for atomic swap
        
        Args:
            filepath: Path to the manifest file to update
            modifications: Dictionary of modifications to apply
                          Format: {
                              'key': 'value',
                              'flags': ['--flag1=value1', '--flag2=value2']
                          }
        
        Returns:
            Tuple of (success, message)
        """
        filepath = Path(filepath)
        
        try:
            # Step 1: Read original file
            logger.info(f"Reading file: {filepath}")
            with open(filepath, 'r') as f:
                original_content = f.read()
            
            # Step 2: Create backup
            backup_success, backup_path = self.create_backup(str(filepath))
            if not backup_success:
                return False, f"Failed to create backup"
            
            # Step 3: Modify content in memory
            modified_content = self._apply_modifications(original_content, modifications)
            
            if modified_content == original_content:
                logger.info(f"No changes needed for {filepath}")
                return True, "No changes needed"
            
            # Step 4: Write to temporary file in same directory (for atomic rename)
            # Using same directory ensures we're on the same filesystem
            temp_fd, temp_path = tempfile.mkstemp(
                dir=filepath.parent,
                prefix=filepath.stem + '_',
                suffix='.tmp'
            )
            
            try:
                # Write modified content to temp file
                with os.fdopen(temp_fd, 'w') as f:
                    f.write(modified_content)
                    f.flush()
                    # Sync to ensure data is written to disk
                    os.fsync(f.fileno())
                
                # Step 5: Atomic replace (os.replace is atomic on all platforms)
                logger.info(f"Atomically replacing original file with modified version")
                os.replace(temp_path, filepath)
                
                logger.info(f"Successfully updated manifest: {filepath}")
                return True, f"Updated successfully. Backup: {backup_path}"
            
            except Exception as e:
                # Clean up temp file if something went wrong
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                raise e
        
        except Exception as e:
            logger.error(f"Failed to safely update manifest: {e}")
            return False, str(e)
    
    def _apply_modifications(self, content: str, modifications: Dict[str, Any]) -> str:
        """
        Apply modifications to YAML content in memory.
        
        Args:
            content: Original file content
            modifications: Dictionary of modifications
            
        Returns:
            Modified content as string
        """
        try:
            import yaml
        except ImportError:
            logger.warning("PyYAML not available, using text-based modifications")
            return self._apply_text_modifications(content, modifications)
        
        try:
            # Parse YAML
            data = yaml.safe_load(content)
            
            # Apply modifications
            if 'flags' in modifications:
                data = self._update_command_flags(data, modifications['flags'])
            
            # Dump back to YAML
            modified = yaml.dump(
                data,
                default_flow_style=False,
                sort_keys=False,
                allow_unicode=True
            )
            
            return modified
        
        except Exception as e:
            logger.error(f"Failed to parse/modify YAML: {e}")
            raise
    
    def _update_command_flags(self, data: Dict, flags: list) -> Dict:
        """Update command flags in the manifest data structure."""
        try:
            spec = data.get('spec', {})
            containers = spec.get('containers', [])
            
            if containers:
                command = containers[0].get('command', [])
                
                for flag_entry in flags:
                    if '=' in flag_entry:
                        # Format: --flag=value
                        flag_key, flag_value = flag_entry.split('=', 1)
                        self._update_flag_in_list(command, flag_key, flag_value)
                    else:
                        # Single flag
                        self._update_flag_in_list(command, flag_entry, None)
        
        except Exception as e:
            logger.error(f"Failed to update command flags: {e}")
            raise
        
        return data
    
    def _update_flag_in_list(self, command_list: list, flag: str, value: Optional[str]) -> None:
        """Update or add a flag in the command list."""
        # Find if flag exists
        flag_index = -1
        for i, item in enumerate(command_list):
            if item.startswith(flag + '=') or item == flag:
                flag_index = i
                break
        
        if flag_index >= 0:
            # Update existing flag
            if value:
                command_list[flag_index] = f"{flag}={value}"
            # else: remove flag if no value (not implemented for safety)
        else:
            # Add new flag
            if value:
                command_list.append(f"{flag}={value}")
            else:
                command_list.append(flag)
    
    def _apply_text_modifications(self, content: str, modifications: Dict) -> str:
        """
        Fallback text-based modification using regex.
        Less reliable than YAML parsing but works without dependencies.
        """
        import re
        
        modified = content
        
        if 'flags' in modifications:
            for flag_entry in modifications['flags']:
                if '=' in flag_entry:
                    flag_key, flag_value = flag_entry.split('=', 1)
                    # Try to update existing flag
                    pattern = f"({flag_key}=)[^\n\r]+"
                    replacement = f"{flag_key}={flag_value}"
                    modified = re.sub(pattern, replacement, modified)
                    
                    # If not found, append to command section (risky, not recommended)
                    if not re.search(pattern, modified):
                        logger.warning(f"Flag {flag_key} not found in manifest, skipping")
        
        return modified
    
    def wait_for_cluster_healthy(self, timeout: int = None, max_retries: int = 30) -> Tuple[bool, str]:
        """
        Check if Kubernetes API server is healthy.
        
        Implements a barrier that waits for the API to respond after remediation.
        This ensures the cluster has stabilized before running audit checks.
        
        Args:
            timeout: Maximum time to wait in seconds (uses self.health_check_timeout if None)
            max_retries: Maximum number of retries before giving up
            
        Returns:
            Tuple of (is_healthy, status_message)
        """
        if timeout is None:
            timeout = self.health_check_timeout
        
        start_time = time.time()
        retry_count = 0
        last_error = None
        
        logger.info(f"Checking cluster health at {self.health_check_url}")
        
        while retry_count < max_retries:
            elapsed = time.time() - start_time
            
            if elapsed > timeout:
                msg = f"Health check timeout after {timeout}s. Last error: {last_error}"
                logger.error(msg)
                return False, msg
            
            try:
                # Disable SSL verification for localhost
                response = requests.get(
                    self.health_check_url,
                    verify=False,
                    timeout=5
                )
                
                if response.status_code == 200:
                    # API is responding, but wait additional time for full startup
                    logger.info(f"API responsive (status {response.status_code}). Waiting {self.api_settle_time}s for full startup...")
                    time.sleep(self.api_settle_time)
                    
                    msg = f"Cluster healthy after {elapsed:.1f}s"
                    logger.info(msg)
                    return True, msg
                else:
                    last_error = f"HTTP {response.status_code}"
                    logger.debug(f"API returned status {response.status_code}")
            
            except requests.exceptions.ConnectionError as e:
                last_error = "Connection refused"
                logger.debug(f"Connection attempt {retry_count + 1}: Connection refused")
            
            except requests.exceptions.Timeout as e:
                last_error = "Request timeout"
                logger.debug(f"Connection attempt {retry_count + 1}: Request timeout")
            
            except Exception as e:
                last_error = str(e)
                logger.debug(f"Connection attempt {retry_count + 1}: {e}")
            
            # Wait before next retry
            time.sleep(self.health_check_interval)
            retry_count += 1
        
        msg = f"Cluster failed health check after {max_retries} retries ({timeout}s elapsed)"
        logger.error(msg)
        return False, msg
    
    def rollback(self, filepath: str, backup_path: str) -> Tuple[bool, str]:
        """
        Rollback a file to its backed-up version.
        
        Args:
            filepath: Path to the file to restore
            backup_path: Path to the backup file
            
        Returns:
            Tuple of (success, message)
        """
        try:
            filepath = Path(filepath)
            backup_path = Path(backup_path)
            
            if not backup_path.exists():
                msg = f"Backup file does not exist: {backup_path}"
                logger.error(msg)
                return False, msg
            
            # Copy backup back to original location
            shutil.copy2(backup_path, filepath)
            
            msg = f"Successfully rolled back {filepath}"
            logger.info(msg)
            return True, msg
        
        except Exception as e:
            msg = f"Failed to rollback {filepath}: {e}"
            logger.error(msg)
            return False, msg
    
    def verify_remediation(self, check_id: str, audit_script_path: str) -> Tuple[bool, str]:
        """
        Run the audit script to verify that remediation was successful.
        
        Args:
            check_id: The CIS check ID (e.g., '1.2.1')
            audit_script_path: Path to the audit script
            
        Returns:
            Tuple of (success, audit_output)
        """
        import subprocess
        
        try:
            logger.info(f"Verifying remediation for {check_id} using {audit_script_path}")
            
            result = subprocess.run(
                ['bash', audit_script_path],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            output = result.stdout + result.stderr
            success = result.returncode == 0
            
            if success:
                logger.info(f"Verification passed for {check_id}")
            else:
                logger.warning(f"Verification failed for {check_id}")
            
            return success, output
        
        except subprocess.TimeoutExpired:
            msg = f"Audit script timeout for {check_id}"
            logger.error(msg)
            return False, msg
        
        except Exception as e:
            msg = f"Failed to run audit script: {e}"
            logger.error(msg)
            return False, msg


class RemediationFlow:
    """Orchestrates the complete remediation workflow with atomic writes and rollback."""
    
    def __init__(self, manager: AtomicRemediationManager):
        """Initialize with an AtomicRemediationManager instance."""
        self.manager = manager
    
    def remediate_with_verification(
        self,
        check_id: str,
        manifest_path: str,
        modifications: Dict[str, Any],
        audit_script_path: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Complete remediation flow:
        1. Create snapshot (backup)
        2. Apply changes (atomic write)
        3. Verify cluster health
        4. Run audit to verify remediation
        5. Rollback if anything fails
        
        Args:
            check_id: CIS check ID
            manifest_path: Path to manifest to remediate
            modifications: Modifications to apply
            audit_script_path: Optional path to audit script for verification
            
        Returns:
            Dictionary with remediation results
        """
        result = {
            'check_id': check_id,
            'status': 'FAILED',
            'message': '',
            'backup_path': '',
            'rolled_back': False,
            'verification_passed': False
        }
        
        try:
            # Step 1: Create backup
            logger.info(f"[{check_id}] Creating backup...")
            backup_success, backup_path = self.manager.create_backup(manifest_path)
            
            if not backup_success:
                result['message'] = backup_path
                return result
            
            result['backup_path'] = backup_path
            
            # Step 2: Apply changes (atomic write)
            logger.info(f"[{check_id}] Applying changes...")
            update_success, update_message = self.manager.update_manifest_safely(
                manifest_path,
                modifications
            )
            
            if not update_success:
                result['message'] = update_message
                self.manager.rollback(manifest_path, backup_path)
                result['rolled_back'] = True
                return result
            
            # Step 3: Wait for cluster to be healthy
            logger.info(f"[{check_id}] Waiting for cluster health check...")
            health_ok, health_msg = self.manager.wait_for_cluster_healthy()
            
            if not health_ok:
                logger.critical(f"[{check_id}] Cluster health check failed! Rolling back...")
                result['message'] = f"Health check failed: {health_msg}"
                self.manager.rollback(manifest_path, backup_path)
                result['rolled_back'] = True
                return result
            
            # Step 4: Verify remediation with audit script
            if audit_script_path:
                logger.info(f"[{check_id}] Running audit verification...")
                audit_ok, audit_output = self.manager.verify_remediation(
                    check_id,
                    audit_script_path
                )
                
                if not audit_ok:
                    logger.warning(f"[{check_id}] Audit verification failed! Rolling back...")
                    result['message'] = f"Audit verification failed"
                    self.manager.rollback(manifest_path, backup_path)
                    result['rolled_back'] = True
                    return result
                
                result['verification_passed'] = True
            
            # Success!
            result['status'] = 'SUCCESS'
            result['message'] = f"Remediation completed and verified"
            logger.info(f"[{check_id}] ✅ Remediation successful!")
            
            return result
        
        except Exception as e:
            result['message'] = f"Unexpected error: {str(e)}"
            logger.error(f"[{check_id}] Unexpected error: {e}")
            
            # Attempt rollback
            if result['backup_path']:
                logger.info(f"[{check_id}] Attempting emergency rollback...")
                self.manager.rollback(manifest_path, result['backup_path'])
                result['rolled_back'] = True
            
            return result


# Example usage
if __name__ == "__main__":
    """
    Example: How to use AtomicRemediationManager
    """
    
    # Initialize manager
    manager = AtomicRemediationManager()
    
    # Create remediation flow
    flow = RemediationFlow(manager)
    
    # Example: Remediate API server
    result = flow.remediate_with_verification(
        check_id="1.2.1",
        manifest_path="/etc/kubernetes/manifests/kube-apiserver.yaml",
        modifications={
            'flags': [
                '--anonymous-auth=false',
                '--authorization-mode=Node,RBAC'
            ]
        },
        audit_script_path="/path/to/1.2.1_audit.sh"
    )
    
    print(json.dumps(result, indent=2))
