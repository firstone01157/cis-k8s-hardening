#!/usr/bin/env python3
"""
CIS Kubernetes Hardening: API Server Audit Policy Configuration Helper (v2 - Robust)
Purpose: Forcefully ensure audit logging configuration in kube-apiserver.yaml
Pattern: Uses YAML library (no sed) to preserve structure
Strategy: FORCEFUL - Removes incomplete configs, applies complete audit setup

Author: CIS Kubernetes Hardening Framework
License: MIT
"""

import sys
import os
import yaml
import shutil
from datetime import datetime

def log_info(msg):
    """Print info message"""
    print(f"[INFO] {msg}", file=sys.stdout)

def log_debug(msg):
    """Print debug message"""
    print(f"[DEBUG] {msg}", file=sys.stdout)

def log_error(msg):
    """Print error message"""
    print(f"[ERROR] {msg}", file=sys.stderr)

def log_pass(msg):
    """Print pass message"""
    print(f"[PASS] {msg}", file=sys.stdout)

def log_fail(msg):
    """Print fail message"""
    print(f"[FAIL] {msg}", file=sys.stderr)

def log_warn(msg):
    """Print warning message"""
    print(f"[WARN] {msg}", file=sys.stdout)

def create_audit_policy(policy_path):
    """
    Create a CIS-compliant audit policy file
    Path: /etc/kubernetes/audit-policy.yaml
    
    The policy includes:
    - Secrets logged at Metadata level (minimal exposure)
    - Pods/Deployments logged at RequestResponse (full visibility)
    - System namespaces excluded
    - Default fallback rule at Metadata level
    """
    
    audit_policy = {
        'apiVersion': 'audit.k8s.io/v1',
        'kind': 'Policy',
        'omitStages': ['RequestReceived'],
        'rules': [
            # Rule 1: Log secrets at Metadata level only (sensitive data)
            {
                'level': 'Metadata',
                'verbs': ['get', 'list', 'watch'],
                'resources': [
                    {
                        'group': '',
                        'resources': ['secrets']
                    }
                ],
                'omitStages': ['RequestReceived']
            },
            # Rule 2: Log pod exec and portforward at RequestResponse (security critical)
            {
                'level': 'RequestResponse',
                'verbs': ['create', 'update', 'patch', 'delete'],
                'resources': [
                    {
                        'group': '',
                        'resources': ['pods/exec', 'pods/portforward']
                    }
                ]
            },
            # Rule 3: Log pod and deployment modifications at RequestResponse
            {
                'level': 'RequestResponse',
                'verbs': ['create', 'update', 'patch', 'delete'],
                'resources': [
                    {
                        'group': '',
                        'resources': ['pods']
                    },
                    {
                        'group': 'apps',
                        'resources': ['deployments', 'statefulsets', 'daemonsets']
                    }
                ]
            },
            # Rule 4: Log RBAC changes (role, rolebinding, clusterrole, clusterrolebinding)
            {
                'level': 'RequestResponse',
                'verbs': ['create', 'update', 'patch', 'delete'],
                'resources': [
                    {
                        'group': 'rbac.authorization.k8s.io',
                        'resources': ['clusterroles', 'clusterrolebindings', 'roles', 'rolebindings']
                    }
                ]
            },
            # Rule 5: Log ConfigMap access at Metadata level
            {
                'level': 'Metadata',
                'verbs': ['get', 'list', 'watch'],
                'resources': [
                    {
                        'group': '',
                        'resources': ['configmaps']
                    }
                ]
            },
            # Rule 6: Log service modifications
            {
                'level': 'RequestResponse',
                'verbs': ['create', 'update', 'patch', 'delete'],
                'resources': [
                    {
                        'group': '',
                        'resources': ['services']
                    }
                ]
            },
            # Rule 7: Exclude system namespaces from detailed logging
            {
                'level': 'Metadata',
                'namespaces': ['kube-system', 'kube-public', 'kube-node-lease'],
                'omitStages': ['RequestReceived']
            },
            # Rule 8: Default rule - log at Metadata level
            {
                'level': 'Metadata',
                'omitStages': ['RequestReceived']
            }
        ]
    }
    
    try:
        # Create directory if it doesn't exist
        audit_dir = os.path.dirname(policy_path)
        if not os.path.exists(audit_dir):
            log_info(f"Creating directory: {audit_dir}")
            os.makedirs(audit_dir, mode=0o755)
        
        # Write the audit policy
        with open(policy_path, 'w') as f:
            yaml.dump(audit_policy, f, default_flow_style=False, sort_keys=False)
        
        log_pass(f"Audit policy created: {policy_path}")
        log_debug(f"Policy contains {len(audit_policy['rules'])} rules")
        return True
    except Exception as e:
        log_fail(f"Failed to create audit policy: {str(e)}")
        return False

def clean_audit_flags_from_command(command):
    """
    Remove ALL audit-related flags from command list
    This ensures we start fresh without partial/broken configurations
    
    Returns: Cleaned command list
    """
    audit_prefixes = [
        '--audit-policy-file',
        '--audit-log-path',
        '--audit-log-maxage',
        '--audit-log-maxbackup',
        '--audit-log-maxsize'
    ]
    
    cleaned = [arg for arg in command if not any(arg.startswith(prefix) for prefix in audit_prefixes)]
    removed = len(command) - len(cleaned)
    if removed > 0:
        log_debug(f"Removed {removed} old audit flags from command")
    return cleaned

def clean_audit_mounts_from_volumes(volume_mounts, volumes):
    """
    Remove ALL audit-related volume mounts and volumes
    Ensures clean slate before applying new configuration
    
    Returns: Tuple of (cleaned_mounts, cleaned_volumes)
    """
    audit_names = ['audit-policy', 'audit-log']
    
    cleaned_mounts = [m for m in volume_mounts if m.get('name') not in audit_names]
    cleaned_volumes = [v for v in volumes if v.get('name') not in audit_names]
    
    removed_mounts = len(volume_mounts) - len(cleaned_mounts)
    removed_vols = len(volumes) - len(cleaned_volumes)
    
    if removed_mounts > 0:
        log_debug(f"Removed {removed_mounts} old audit volume mounts")
    if removed_vols > 0:
        log_debug(f"Removed {removed_vols} old audit volumes")
    
    return cleaned_mounts, cleaned_volumes

def modify_apiserver_manifest(manifest_path, audit_policy_path, audit_log_path, audit_log_maxage=30):
    """
    FORCEFULLY and SAFELY modify kube-apiserver.yaml to ensure audit flags are present
    
    Strategy:
    1. Verify audit policy file exists first (CRITICAL)
    2. Load YAML correctly with safe_load
    3. Clean ALL old audit configurations first
    4. Add fresh, complete audit configuration:
       - Command flags → kube-apiserver container command
       - volumeMounts → kube-apiserver container volumeMounts
       - volumes → Pod spec.volumes (NOT inside container)
    5. Verify changes took effect
    6. Print YAML diff for debugging
    7. Save with backup
    
    Returns: True if successful, False otherwise
    """
    
    try:
        # STEP 0: Verify files exist before proceeding
        log_info("Step 0: Verifying prerequisites...")
        
        if not os.path.exists(manifest_path):
            log_fail(f"Manifest not found: {manifest_path}")
            return False
        
        if not os.path.exists(audit_policy_path):
            log_fail(f"Audit policy file not found: {audit_policy_path}")
            log_info("  Create the audit policy first with: create_audit_policy()")
            return False
        
        if not os.path.isfile(audit_policy_path):
            log_fail(f"Audit policy is not a file: {audit_policy_path}")
            return False
        
        log_pass(f"Audit policy verified: {audit_policy_path}")
        
        # Verify audit log directory
        audit_log_dir = os.path.dirname(audit_log_path)
        if not os.path.exists(audit_log_dir):
            log_fail(f"Audit log directory not found: {audit_log_dir}")
            log_info("  Create the audit log directory first with: create_audit_log_directory()")
            return False
        
        if not os.path.isdir(audit_log_dir):
            log_fail(f"Audit log path is not a directory: {audit_log_dir}")
            return False
        
        log_pass(f"Audit log directory verified: {audit_log_dir}")
        
        # Create backup BEFORE loading
        backup_path = f"{manifest_path}.bak_{int(datetime.now().timestamp())}"
        shutil.copy2(manifest_path, backup_path)
        log_info(f"Backup created: {backup_path}")
        
        # Load YAML safely
        with open(manifest_path, 'r') as f:
            manifest = yaml.safe_load(f)
        
        if manifest is None:
            log_fail("Manifest is empty or invalid YAML")
            return False
        
        log_debug("Manifest loaded and parsed successfully")
        
        # Get spec (Pod level)
        spec = manifest.get('spec', {})
        if not spec:
            log_fail("Manifest spec not found")
            return False
        
        # Find kube-apiserver container by name
        containers = spec.get('containers', [])
        if not containers:
            log_fail("No containers found in manifest spec")
            return False
        
        apiserver_container = None
        apiserver_index = None
        
        for i, container in enumerate(containers):
            if isinstance(container, dict) and container.get('name') == 'kube-apiserver':
                apiserver_container = container
                apiserver_index = i
                break
        
        if not apiserver_container:
            log_fail("kube-apiserver container not found in manifest")
            return False
        
        log_info("Found kube-apiserver container")
        log_debug(f"Container index: {apiserver_index}")
        
        # STEP 1: Clean old audit configurations
        log_info("Step 1: Cleaning old audit configurations...")
        
        command = apiserver_container.get('command', [])
        if not command:
            log_fail("kube-apiserver command not found")
            return False
        
        if not isinstance(command, list):
            log_fail(f"Command is not a list: {type(command)}")
            return False
        
        # Remove old audit flags from CONTAINER command
        command = clean_audit_flags_from_command(command)
        apiserver_container['command'] = command
        log_pass("Cleaned old audit flags from container command")
        
        # Clean old volume mounts from CONTAINER volumeMounts
        volume_mounts = apiserver_container.get('volumeMounts', [])
        if not isinstance(volume_mounts, list):
            volume_mounts = []
        
        original_mount_count = len(volume_mounts)
        volume_mounts, _ = clean_audit_mounts_from_volumes(volume_mounts, [])
        apiserver_container['volumeMounts'] = volume_mounts
        log_pass(f"Cleaned old audit mounts from container ({original_mount_count} -> {len(volume_mounts)})")
        
        # Clean old volumes from POD SPEC
        volumes = spec.get('volumes', [])
        if not isinstance(volumes, list):
            volumes = []
        
        original_vol_count = len(volumes)
        _, volumes = clean_audit_mounts_from_volumes([], volumes)
        spec['volumes'] = volumes
        log_pass(f"Cleaned old audit volumes from spec ({original_vol_count} -> {len(volumes)})")
        
        # STEP 2: Add new, complete audit configuration
        log_info("Step 2: Adding complete audit configuration...")
        
        # 2a. Add audit flags to CONTAINER command
        new_flags = [
            f'--audit-policy-file={audit_policy_path}',
            f'--audit-log-path={audit_log_path}',
            f'--audit-log-maxage={audit_log_maxage}',
            '--audit-log-maxbackup=10',
            '--audit-log-maxsize=100'
        ]
        
        apiserver_container['command'].extend(new_flags)
        log_debug(f"Added {len(new_flags)} audit flags to container command")
        for flag in new_flags:
            log_debug(f"  + {flag}")
        
        # 2b. Add volume mounts to CONTAINER volumeMounts
        new_mounts = [
            {
                'name': 'audit-policy',
                'mountPath': audit_policy_path,
                'readOnly': True
            },
            {
                'name': 'audit-log',
                'mountPath': os.path.dirname(audit_log_path),
                'readOnly': False
            }
        ]
        
        apiserver_container['volumeMounts'].extend(new_mounts)
        log_debug(f"Added {len(new_mounts)} volume mounts to container")
        for mount in new_mounts:
            log_debug(f"  + {mount['name']} -> {mount['mountPath']}")
        
        # 2c. Add volumes to POD SPEC (NOT container)
        new_volumes = [
            {
                'name': 'audit-policy',
                'hostPath': {
                    'path': audit_policy_path,
                    'type': 'File'
                }
            },
            {
                'name': 'audit-log',
                'hostPath': {
                    'path': os.path.dirname(audit_log_path),
                    'type': 'DirectoryOrCreate'
                }
            }
        ]
        
        spec['volumes'].extend(new_volumes)
        log_debug(f"Added {len(new_volumes)} volumes to pod spec")
        for volume in new_volumes:
            log_debug(f"  + {volume['name']}")
        
        # STEP 3: Verify changes before saving
        log_info("Step 3: Verifying changes...")
        
        # Verify audit flags in command
        final_command = apiserver_container.get('command', [])
        audit_flags = [f for f in final_command if f.startswith('--audit')]
        log_debug(f"Final audit flags in command: {len(audit_flags)}")
        
        if len(audit_flags) < 5:
            log_fail(f"Expected at least 5 audit flags, found {len(audit_flags)}")
            shutil.copy2(backup_path, manifest_path)
            return False
        
        for flag in audit_flags:
            log_debug(f"  ✓ {flag}")
        
        log_pass("All 5 required audit flags present")
        
        # Verify volume mounts in container
        final_mounts = apiserver_container.get('volumeMounts', [])
        audit_mounts = [m for m in final_mounts if m.get('name') in ['audit-policy', 'audit-log']]
        log_debug(f"Final audit volume mounts in container: {len(audit_mounts)}")
        
        if len(audit_mounts) < 2:
            log_fail(f"Expected at least 2 audit volume mounts in container, found {len(audit_mounts)}")
            shutil.copy2(backup_path, manifest_path)
            return False
        
        for mount in audit_mounts:
            log_debug(f"  ✓ {mount['name']} -> {mount['mountPath']}")
        
        log_pass("All required volume mounts present in container")
        
        # Verify volumes in pod spec
        final_volumes = spec.get('volumes', [])
        audit_volumes = [v for v in final_volumes if v.get('name') in ['audit-policy', 'audit-log']]
        log_debug(f"Final audit volumes in pod spec: {len(audit_volumes)}")
        
        if len(audit_volumes) < 2:
            log_fail(f"Expected at least 2 audit volumes in pod spec, found {len(audit_volumes)}")
            shutil.copy2(backup_path, manifest_path)
            return False
        
        for volume in audit_volumes:
            log_debug(f"  ✓ {volume['name']}")
        
        log_pass("All required volumes present in pod spec")
        
        # STEP 4: Print YAML diff for debugging
        log_info("Step 4: Generating YAML diff...")
        
        # Load original backup for comparison
        with open(backup_path, 'r') as f:
            original_manifest = yaml.safe_load(f)
        
        # Show brief container command comparison
        original_cmd = original_manifest.get('spec', {}).get('containers', [{}])[0].get('command', [])
        new_cmd = apiserver_container.get('command', [])
        
        log_debug("Container command changes:")
        log_debug(f"  Original lines: {len(original_cmd)}")
        log_debug(f"  New lines: {len(new_cmd)}")
        log_debug(f"  Added flags: {len(new_cmd) - len(original_cmd)}")
        
        # Show container volumeMounts
        original_mounts = original_manifest.get('spec', {}).get('containers', [{}])[0].get('volumeMounts', [])
        new_mounts_container = apiserver_container.get('volumeMounts', [])
        
        log_debug("Container volumeMounts changes:")
        log_debug(f"  Original: {len(original_mounts)} mounts")
        log_debug(f"  New: {len(new_mounts_container)} mounts")
        log_debug(f"  Added: {len(new_mounts_container) - len(original_mounts)} mounts")
        
        # Show pod spec volumes
        original_vols = original_manifest.get('spec', {}).get('volumes', [])
        new_vols_spec = spec.get('volumes', [])
        
        log_debug("Pod spec volumes changes:")
        log_debug(f"  Original: {len(original_vols)} volumes")
        log_debug(f"  New: {len(new_vols_spec)} volumes")
        log_debug(f"  Added: {len(new_vols_spec) - len(original_vols)} volumes")
        
        log_pass("YAML diff verification complete")
        
        # STEP 5: Write modified manifest
        log_info("Step 5: Writing modified manifest...")
        
        with open(manifest_path, 'w') as f:
            # Use default_flow_style=False for readable output
            # sort_keys=False to preserve order
            yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)
        
        log_pass("Manifest saved successfully")
        log_info(f"Modified manifest: {manifest_path}")
        log_info(f"Backup location: {backup_path}")
        
        return True
    
    except yaml.YAMLError as e:
        log_fail(f"YAML parsing error: {str(e)}")
        if 'backup_path' in locals():
            shutil.copy2(backup_path, manifest_path)
            log_info("Restored from backup due to YAML error")
        return False
    except Exception as e:
        log_fail(f"Unexpected error: {str(e)}")
        if 'backup_path' in locals():
            shutil.copy2(backup_path, manifest_path)
            log_info("Restored from backup due to error")
        return False

def create_audit_log_directory(audit_log_path):
    """
    Create the audit log directory with proper permissions
    """
    try:
        audit_dir = os.path.dirname(audit_log_path)
        if not os.path.exists(audit_dir):
            os.makedirs(audit_dir, mode=0o700)
            log_pass(f"Audit log directory created: {audit_dir}")
        else:
            log_debug(f"Audit log directory exists: {audit_dir}")
        
        # Verify write permissions
        if not os.access(audit_dir, os.W_OK):
            log_fail(f"No write permission for audit directory: {audit_dir}")
            return False
        
        log_debug(f"Verified write permissions for: {audit_dir}")
        return True
    except Exception as e:
        log_fail(f"Failed to create audit log directory: {str(e)}")
        return False

def main():
    """Main entry point"""
    
    # Configuration
    AUDIT_POLICY_FILE = '/etc/kubernetes/audit-policy.yaml'
    APISERVER_MANIFEST = '/etc/kubernetes/manifests/kube-apiserver.yaml'
    AUDIT_LOG_PATH = '/var/log/kubernetes/audit/audit.log'
    AUDIT_LOG_MAXAGE = 30
    
    log_info("=" * 60)
    log_info("CIS 3.2.2 Automation: Audit Policy Configuration (v2 - Robust)")
    log_info("=" * 60)
    log_debug(f"Audit policy file: {AUDIT_POLICY_FILE}")
    log_debug(f"API Server manifest: {APISERVER_MANIFEST}")
    log_debug(f"Audit log path: {AUDIT_LOG_PATH}")
    log_debug(f"Audit log max age: {AUDIT_LOG_MAXAGE} days")
    
    # Check if running as root
    if os.getuid() != 0:
        log_fail("This script must be run as root (uid=0)")
        return 1
    
    log_debug("Running as root")
    
    # Step 1: Create audit policy
    log_info("=" * 60)
    log_info("Step 1: Creating CIS-compliant audit policy...")
    log_info("=" * 60)
    if not create_audit_policy(AUDIT_POLICY_FILE):
        log_fail("Failed to create audit policy")
        return 1
    
    # Step 2: Create audit log directory
    log_info("=" * 60)
    log_info("Step 2: Creating audit log directory...")
    log_info("=" * 60)
    if not create_audit_log_directory(AUDIT_LOG_PATH):
        log_fail("Failed to create audit log directory")
        return 1
    
    # Step 3: Modify kube-apiserver manifest (FORCEFUL)
    log_info("=" * 60)
    log_info("Step 3: Forcefully configuring kube-apiserver manifest...")
    log_info("=" * 60)
    if not modify_apiserver_manifest(APISERVER_MANIFEST, AUDIT_POLICY_FILE, AUDIT_LOG_PATH, AUDIT_LOG_MAXAGE):
        log_fail("Failed to modify kube-apiserver manifest")
        return 1
    
    # Success!
    log_info("=" * 60)
    log_pass("CIS 3.2.2 automation completed successfully!")
    log_info("=" * 60)
    log_info("")
    log_info("Summary of changes:")
    log_info(f"  ✓ Audit policy: {AUDIT_POLICY_FILE}")
    log_info(f"  ✓ Audit log directory: {os.path.dirname(AUDIT_LOG_PATH)}/")
    log_info(f"  ✓ Kube-apiserver manifest: {APISERVER_MANIFEST}")
    log_info("")
    log_info("Next steps:")
    log_info("  1. Monitor kube-apiserver restart")
    log_info("  2. Verify audit logs being written")
    log_info("  3. Run audit script to verify: ./3.2.2_audit.sh")
    log_info("")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
