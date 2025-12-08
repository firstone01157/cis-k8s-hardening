"""
================================================================================
CIS Kubernetes Hardening - Configuration Integration Snippet
Modified run_script() Method with Check Configuration Loading & Injection
================================================================================

FEATURES:
1. Load check-specific configuration from JSON
2. Skip execution if "enabled": false
3. Inject variables from JSON into subprocess environment
4. Log warnings for disabled checks
================================================================================
"""

import json
import os
import subprocess
import sys
from datetime import datetime

# ============================================================================
# ENHANCED run_script() METHOD - WITH CONFIGURATION INTEGRATION
# ============================================================================

def run_script(self, script, mode):
    """
    Execute audit/remediation script with configuration management.
    
    NEW FEATURES:
    - Loads check-specific config from cis_config.json
    - Skips execution if check is disabled (enabled: false)
    - Injects configuration variables into subprocess environment
    - Logs disabled checks for compliance tracking
    
    PARAMETERS:
        script (dict): Script metadata with 'id', 'path', 'role', 'level'
        mode (str): 'audit' or 'remediate'
    
    RETURNS:
        dict: Result with status, reason, output, etc.
    """
    
    if self.stop_requested:
        return None
    
    start_time = time.time()
    script_id = script["id"]
    
    # ==========================================================================
    # STEP 1: LOAD CHECK CONFIGURATION FROM cis_config.json
    # ==========================================================================
    
    check_config = self._get_check_config(script_id)
    
    # ==========================================================================
    # STEP 2: CHECK IF THIS CHECK IS ENABLED IN CONFIGURATION
    # ==========================================================================
    
    if not check_config.get("enabled", True):  # Default: enabled if not specified
        reason = check_config.get("_comment", "Check disabled in configuration")
        
        # Log disabled check for compliance tracking
        self.log_activity(
            "CHECK_DISABLED",
            f"Check {script_id}: {reason}"
        )
        
        print(f"{Colors.YELLOW}[SKIP] {script_id}: {reason}{Colors.ENDC}")
        
        return self._create_result(
            script, 
            "SKIPPED",
            f"Disabled in config: {reason}",
            time.time() - start_time
        )
    
    # ==========================================================================
    # STEP 3: CONTINUE WITH EXISTING LOGIC (excluded rules, manual checks, etc.)
    # ==========================================================================
    
    if self.is_rule_excluded(script_id):
        return self._create_result(
            script, "IGNORED",
            f"Excluded: {self.excluded_rules.get(script_id, 'No reason')}",
            time.time() - start_time
        )
    
    try:
        # Check remediation config for skipping
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
        
        # Wait for healthy cluster (existing logic)
        if mode == "remediate":
            requires_health_check, _ = self._classify_remediation_type(script_id)
            skip_this_health_check = not requires_health_check
            
            if not self.wait_for_healthy_cluster(skip_health_check=skip_this_health_check):
                error_msg = (
                    f"\n{Colors.RED}{'='*70}\n"
                    f"[CRITICAL] EMERGENCY STOP: Cluster Unavailable\n"
                    f"{'='*70}\n"
                    f"Status: {self.health_status}\n"
                    f"Failed Check: {script_id}\n"
                    f"Time to Failure: {round(time.time() - start_time, 2)}s\n\n"
                    f"Remediation loop aborted to prevent cascading failures.\n"
                    f"{'='*70}{Colors.ENDC}\n"
                )
                print(error_msg)
                self.log_activity("REMEDIATION_EMERGENCY_STOP", f"Cluster unavailable at check {script_id}")
                sys.exit(1)
        
        # =======================================================================
        # STEP 4: PREPARE ENVIRONMENT VARIABLES - INJECT CONFIG FROM JSON
        # =======================================================================
        
        env = os.environ.copy()
        
        if mode == "remediate":
            # Add global remediation config
            env.update({
                "BACKUP_ENABLED": str(self.remediation_global_config.get("backup_enabled", True)).lower(),
                "BACKUP_DIR": self.remediation_global_config.get("backup_dir", "/var/backups/cis-remediation"),
                "DRY_RUN": str(self.remediation_global_config.get("dry_run", False)).lower(),
                "WAIT_FOR_API": str(self.wait_for_api_enabled).lower(),
                "API_CHECK_INTERVAL": str(self.api_check_interval),
                "API_MAX_RETRIES": str(self.api_max_retries)
            })
            
            # Add check-specific remediation config
            remediation_cfg = self.get_remediation_config_for_check(script_id)
            if remediation_cfg:
                for key, value in remediation_cfg.items():
                    if key in ['skip', 'enabled', '_reason', '_comment']:
                        # Skip metadata keys
                        continue
                    
                    env_key = f"CONFIG_{key.upper()}"
                    if isinstance(value, (dict, list)):
                        # Pass complex objects as JSON strings
                        env[env_key] = json.dumps(value)
                    else:
                        # Simple values as strings
                        env[env_key] = str(value)
            
            # =======================================================================
            # NEW: INJECT VARIABLES FROM check_config (checks_config section)
            # =======================================================================
            
            # Extract file permission and ownership from check_config
            if check_config:
                # Handle file permission checks (e.g., 1.1.1, 1.1.9, 1.1.11)
                if check_config.get("check_type") == "file_permission":
                    file_mode = check_config.get("file_mode")
                    file_owner = check_config.get("file_owner")
                    file_group = check_config.get("file_group")
                    file_path = check_config.get("file_path")
                    
                    # Export as environment variables for Bash scripts
                    if file_mode:
                        env["FILE_MODE"] = str(file_mode)
                    if file_owner:
                        env["FILE_OWNER"] = str(file_owner)
                    if file_group:
                        env["FILE_GROUP"] = str(file_group)
                    if file_path:
                        env["FILE_PATH"] = str(file_path)
                    
                    if self.verbose >= 2:
                        print(f"{Colors.BLUE}[DEBUG] Injected file check vars for {script_id}:{Colors.ENDC}")
                        print(f"{Colors.BLUE}      FILE_PATH={file_path}{Colors.ENDC}")
                        print(f"{Colors.BLUE}      FILE_MODE={file_mode}{Colors.ENDC}")
                        print(f"{Colors.BLUE}      FILE_OWNER={file_owner}:{file_group}{Colors.ENDC}")
                
                # Handle flag checks (e.g., 1.2.1, 1.2.2)
                if check_config.get("check_type") == "flag_check":
                    flag_name = check_config.get("flag_name")
                    expected_value = check_config.get("expected_value")
                    
                    # Export for flag validation scripts
                    if flag_name:
                        env["FLAG_NAME"] = str(flag_name)
                    if expected_value:
                        env["EXPECTED_VALUE"] = str(expected_value)
                    
                    if self.verbose >= 2:
                        print(f"{Colors.BLUE}[DEBUG] Injected flag check vars for {script_id}:{Colors.ENDC}")
                        print(f"{Colors.BLUE}      FLAG_NAME={flag_name}{Colors.ENDC}")
                        print(f"{Colors.BLUE}      EXPECTED_VALUE={expected_value}{Colors.ENDC}")
            
            # Add global environment overrides
            env.update(self.remediation_env_vars)
            
            if self.verbose >= 2:
                print(f"{Colors.BLUE}[DEBUG] Final environment variables for {script_id}:{Colors.ENDC}")
                for k, v in sorted(env.items()):
                    if k.startswith("CONFIG_") or k.startswith("FILE_") or k.startswith("FLAG_") or k.startswith("BACKUP_"):
                        display_val = v if len(v) < 80 else v[:77] + "..."
                        print(f"{Colors.BLUE}      {k}={display_val}{Colors.ENDC}")
        
        # =======================================================================
        # STEP 5: EXECUTE THE SCRIPT
        # =======================================================================
        
        result = subprocess.run(
            ["bash", script["path"]],
            capture_output=True,
            text=True,
            timeout=self.script_timeout,
            env=env
        )
        
        duration = round(time.time() - start_time, 2)
        
        # Parse output
        status, reason, fix_hint, cmds = self._parse_script_output(
            result, script_id, mode, is_manual
        )
        
        # Handle silent script output
        combined_output = result.stdout.strip() + result.stderr.strip()
        if not combined_output:
            if status == "PASS":
                reason = "[INFO] Check completed successfully with no output"
            elif status == "FIXED":
                reason = "[INFO] Remediation completed successfully with no output"
            elif status == "FAIL":
                reason = "[ERROR] Script failed silently without output"
            elif status == "MANUAL":
                reason = "[WARN] Manual check completed with no output"
        
        return {
            "id": script_id,
            "role": script["role"],
            "level": script["level"],
            "status": status,
            "duration": duration,
            "reason": reason,
            "fix_hint": fix_hint,
            "cmds": cmds,
            "output": result.stdout + result.stderr,
            "path": script["path"],
            "component": self.get_component_for_rule(script_id)
        }
    
    except subprocess.TimeoutExpired:
        return self._create_result(
            script, "ERROR",
            f"Script timeout after {self.script_timeout}s",
            time.time() - start_time
        )
    except FileNotFoundError:
        return self._create_result(
            script, "ERROR",
            f"Script not found: {script['path']}",
            time.time() - start_time
        )
    except PermissionError:
        return self._create_result(
            script, "ERROR",
            "Permission denied executing script",
            time.time() - start_time
        )
    except Exception as e:
        return self._create_result(
            script, "ERROR",
            f"Unexpected error: {str(e)}",
            time.time() - start_time
        )


# ============================================================================
# NEW HELPER METHOD: _get_check_config(check_id)
# ============================================================================

def _get_check_config(self, check_id):
    """
    Retrieve check-specific configuration from cis_config.json.
    
    LOGIC:
    1. Load the "checks_config" section from configuration
    2. Return the config for the specific check ID
    3. Return empty dict {} if check not found (defaults to enabled)
    
    PARAMETERS:
        check_id (str): Check ID (e.g., '5.3.2', '1.1.1')
    
    RETURNS:
        dict: Check configuration with keys like 'enabled', 'file_path', 'file_mode', etc.
    """
    
    # Access the checks_config section
    checks_config = getattr(self, 'checks_config', {})
    
    if check_id in checks_config:
        config = checks_config[check_id]
        
        if self.verbose >= 3:
            print(f"{Colors.BLUE}[DEBUG] Loaded config for {check_id}: {json.dumps(config, indent=2)}{Colors.ENDC}")
        
        return config
    
    # No config found - return empty dict (allows defaults)
    return {}


# ============================================================================
# UPDATED load_config() METHOD - LOAD checks_config SECTION
# ============================================================================

def load_config(self):
    """
    Load configuration from JSON file, including new checks_config section.
    
    NEW: Loads checks_config for individual check enable/disable and parameters.
    """
    
    self.excluded_rules = {}
    self.component_mapping = {}
    self.checks_config = {}  # NEW: Per-check configuration
    self.remediation_config = {}
    self.remediation_global_config = {}
    self.remediation_checks_config = {}
    self.remediation_env_vars = {}
    
    # Initialize API timeout settings with defaults
    self.api_check_interval = 5
    self.api_max_retries = 60
    self.api_settle_time = 15
    self.wait_for_api_enabled = True
    
    if not os.path.exists(self.config_file):
        print(f"{Colors.YELLOW}[!] Config not found. Using defaults.{Colors.ENDC}")
        return
    
    try:
        with open(self.config_file, 'r') as f:
            config = json.load(f)
            self.excluded_rules = config.get("excluded_rules", {})
            self.component_mapping = config.get("component_mapping", {})
            
            # NEW: Load checks_config section
            self.checks_config = config.get("checks_config", {})
            
            # Load remediation configuration
            self.remediation_config = config.get("remediation_config", {})
            self.remediation_global_config = self.remediation_config.get("global", {})
            self.remediation_checks_config = self.remediation_config.get("checks", {})
            self.remediation_env_vars = self.remediation_config.get("environment_overrides", {})
            
            # Load API timeout settings
            self.wait_for_api_enabled = self.remediation_global_config.get("wait_for_api", True)
            self.api_check_interval = self.remediation_global_config.get("api_check_interval", 5)
            self.api_max_retries = self.remediation_global_config.get("api_max_retries", 60)
            self.api_settle_time = self.remediation_global_config.get("api_settle_time", 15)
            
            if self.verbose >= 1:
                print(f"{Colors.BLUE}[DEBUG] Loaded checks_config for {len(self.checks_config)} checks{Colors.ENDC}")
                print(f"{Colors.BLUE}[DEBUG] Loaded remediation config for {len(self.remediation_checks_config)} checks{Colors.ENDC}")
                print(f"{Colors.BLUE}[DEBUG] API timeout: interval={self.api_check_interval}s, max_retries={self.api_max_retries}{Colors.ENDC}")
    
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}[!] Config parse error: {e}{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.RED}[!] Config load error: {e}{Colors.ENDC}")


# ============================================================================
# EXAMPLE: How Bash scripts use injected environment variables
# ============================================================================

"""
BASH SCRIPT EXAMPLE (e.g., 1.1.1_remediate.sh):

#!/bin/bash

# Python injected these environment variables:
# FILE_PATH=/etc/kubernetes/manifests/kube-apiserver.yaml
# FILE_MODE=600
# FILE_OWNER=root
# FILE_GROUP=root

echo "[INFO] Fixing file permissions for ${FILE_PATH}"

# Use the injected variables in the script
chmod "${FILE_MODE}" "${FILE_PATH}" || exit 1
chown "${FILE_OWNER}:${FILE_GROUP}" "${FILE_PATH}" || exit 1

if [ "$(stat -c %a %o "${FILE_PATH}")" = "${FILE_MODE}" ]; then
    echo "[PASS] File permissions fixed"
    exit 0
else
    echo "[FAIL] Failed to fix file permissions"
    exit 1
fi
"""

# ============================================================================
# EXAMPLE: How checks_config is structured in cis_config.json
# ============================================================================

"""
{
  "checks_config": {
    "5.3.2": {
      "enabled": false,
      "_comment": "Disabled for Safety First strategy - see reason field"
    },
    "1.1.1": {
      "enabled": true,
      "check_type": "file_permission",
      "file_path": "/etc/kubernetes/manifests/kube-apiserver.yaml",
      "file_mode": "600",
      "file_owner": "root",
      "file_group": "root"
    },
    "1.2.1": {
      "enabled": true,
      "check_type": "flag_check",
      "flag_name": "--anonymous-auth",
      "expected_value": "false"
    }
  }
}
"""
