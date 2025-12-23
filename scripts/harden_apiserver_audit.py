#!/usr/bin/env python3
"""
CIS Kubernetes Hardening: API Server Audit Policy Configuration Helper (v3 - Idempotent)
Purpose: Ensure audit logging configuration in kube-apiserver.yaml (idempotent, dry-run capable)
Pattern: Uses YAML library (no sed) to preserve structure
Strategy: IDEMPOTENT - Updates existing configs, never duplicates, supports dry-run testing

Author: CIS Kubernetes Hardening Framework
License: MIT
"""

import sys
import os
import yaml
import shutil
import argparse
import difflib
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

def modify_apiserver_manifest(manifest_path, audit_policy_path, audit_log_path, audit_log_maxage=30, dry_run=False):
    """
    IDEMPOTENT modification of kube-apiserver.yaml to ensure audit flags are present
    
    Strategy:
    1. Verify audit policy file and log directory exist (CRITICAL)
    2. Load YAML correctly with safe_load
    3. IDEMPOTENTLY update/add audit configuration:
       - Command flags → Update existing or append if missing (NO duplicates)
       - volumeMounts → Add only if not already present (by name)
       - volumes → Add only if not already present (by name)
    4. Verify changes
    5. If dry_run: Write to .new file and print diff
       If apply: Save with backup and return True
    
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
        
        # Load original manifest
        with open(manifest_path, 'r') as f:
            manifest = yaml.safe_load(f)
        
        if manifest is None:
            log_fail("Manifest is empty or invalid YAML")
            return False
        
        log_debug("Manifest loaded and parsed successfully")
        
        # Store original for diff comparison
        original_manifest = yaml.dump(manifest, default_flow_style=False, sort_keys=False)
        
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
        
        # STEP 1: IDEMPOTENTLY update container command flags
        log_info("Step 1: IDEMPOTENTLY updating command flags...")
        
        command = apiserver_container.get('command', [])
        if not command:
            log_fail("kube-apiserver command not found")
            return False
        
        if not isinstance(command, list):
            log_fail(f"Command is not a list: {type(command)}")
            return False
        
        # Define target flags (key -> value pairs)
        target_flags = {
            '--audit-policy-file': audit_policy_path,
            '--audit-log-path': audit_log_path,
            '--audit-log-maxage': str(audit_log_maxage),
            '--audit-log-maxbackup': '10',
            '--audit-log-maxsize': '100'
        }
        
        flags_added = []
        flags_updated = []
        
        for flag_key, flag_value in target_flags.items():
            flag_with_value = f"{flag_key}={flag_value}"
            
            # Check if flag already exists
            flag_exists = False
            flag_index = -1
            
            for i, arg in enumerate(command):
                if arg.startswith(flag_key):
                    flag_exists = True
                    flag_index = i
                    break
            
            if flag_exists:
                # Update existing flag
                if command[flag_index] != flag_with_value:
                    log_debug(f"Updating: {command[flag_index]} -> {flag_with_value}")
                    command[flag_index] = flag_with_value
                    flags_updated.append(flag_key)
                else:
                    log_debug(f"Already correct: {flag_key}")
            else:
                # Append new flag
                log_debug(f"Adding: {flag_with_value}")
                command.append(flag_with_value)
                flags_added.append(flag_key)
        
        apiserver_container['command'] = command
        
        if flags_added:
            log_pass(f"Added {len(flags_added)} new flags: {', '.join(flags_added)}")
        if flags_updated:
            log_pass(f"Updated {len(flags_updated)} existing flags: {', '.join(flags_updated)}")
        if not flags_added and not flags_updated:
            log_debug("All audit flags already correctly configured")
        
        # STEP 2: IDEMPOTENTLY update volume mounts
        log_info("Step 2: IDEMPOTENTLY updating volume mounts...")
        
        volume_mounts = apiserver_container.get('volumeMounts', [])
        if not isinstance(volume_mounts, list):
            volume_mounts = []
        
        # Get existing volume mount names
        existing_mount_names = {m.get('name') for m in volume_mounts if isinstance(m, dict)}
        
        mounts_added = []
        
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
        
        for mount in new_mounts:
            if mount['name'] not in existing_mount_names:
                log_debug(f"Adding mount: {mount['name']} -> {mount['mountPath']}")
                volume_mounts.append(mount)
                mounts_added.append(mount['name'])
            else:
                log_debug(f"Mount already exists: {mount['name']}")
        
        apiserver_container['volumeMounts'] = volume_mounts
        
        if mounts_added:
            log_pass(f"Added {len(mounts_added)} new volume mounts: {', '.join(mounts_added)}")
        else:
            log_debug("All volume mounts already present")
        
        # STEP 3: IDEMPOTENTLY update volumes in pod spec
        log_info("Step 3: IDEMPOTENTLY updating pod spec volumes...")
        
        volumes = spec.get('volumes', [])
        if not isinstance(volumes, list):
            volumes = []
        
        # Get existing volume names
        existing_volume_names = {v.get('name') for v in volumes if isinstance(v, dict)}
        
        volumes_added = []
        
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
        
        for volume in new_volumes:
            if volume['name'] not in existing_volume_names:
                log_debug(f"Adding volume: {volume['name']}")
                volumes.append(volume)
                volumes_added.append(volume['name'])
            else:
                log_debug(f"Volume already exists: {volume['name']}")
        
        spec['volumes'] = volumes
        
        if volumes_added:
            log_pass(f"Added {len(volumes_added)} new volumes: {', '.join(volumes_added)}")
        else:
            log_debug("All volumes already present")
        
        # STEP 4: Verify changes
        log_info("Step 4: Verifying configuration...")
        
        # Verify audit flags in command
        final_command = apiserver_container.get('command', [])
        audit_flags = [f for f in final_command if f.startswith('--audit')]
        log_debug(f"Final audit flags in command: {len(audit_flags)}")
        
        if len(audit_flags) < 5:
            log_fail(f"Expected at least 5 audit flags, found {len(audit_flags)}")
            return False
        
        for flag in audit_flags:
            log_debug(f"  ✓ {flag}")
        
        log_pass("All 5 required audit flags present")
        
        # Verify volume mounts in container
        final_mounts = apiserver_container.get('volumeMounts', [])
        audit_mounts = [m for m in final_mounts if m.get('name') in ['audit-policy', 'audit-log']]
        
        if len(audit_mounts) < 2:
            log_fail(f"Expected at least 2 audit volume mounts in container, found {len(audit_mounts)}")
            return False
        
        log_pass("All required volume mounts present in container")
        
        # Verify volumes in pod spec
        final_volumes = spec.get('volumes', [])
        audit_volumes = [v for v in final_volumes if v.get('name') in ['audit-policy', 'audit-log']]
        
        if len(audit_volumes) < 2:
            log_fail(f"Expected at least 2 audit volumes in pod spec, found {len(audit_volumes)}")
            return False
        
        log_pass("All required volumes present in pod spec")
        
        # STEP 5: Handle dry-run or apply
        new_manifest = yaml.dump(manifest, default_flow_style=False, sort_keys=False)
        
        if dry_run:
            log_info("Step 5: DRY-RUN MODE - Writing to .new file and showing diff...")
            
            new_file_path = f"{manifest_path}.new"
            with open(new_file_path, 'w') as f:
                f.write(new_manifest)
            
            log_pass(f"Dry-run manifest written to: {new_file_path}")
            
            # Print diff
            log_info("YAML Diff (original -> modified):")
            original_lines = original_manifest.splitlines(keepends=True)
            new_lines = new_manifest.splitlines(keepends=True)
            diff = difflib.unified_diff(original_lines, new_lines, fromfile='original', tofile='modified', lineterm='')
            
            diff_lines = list(diff)
            if diff_lines:
                for line in diff_lines[:50]:  # Limit to first 50 lines
                    print(line.rstrip())
                if len(diff_lines) > 50:
                    log_info(f"... ({len(diff_lines) - 50} more lines)")
            else:
                log_info("No differences detected (already idempotent)")
            
            log_info("")
            log_info("To apply changes: Remove --dry-run flag or use --apply")
            return True
        
        else:
            log_info("Step 5: APPLY MODE - Saving manifest with backup...")
            
            # Create backup BEFORE writing
            backup_path = f"{manifest_path}.bak_{int(datetime.now().timestamp())}"
            shutil.copy2(manifest_path, backup_path)
            log_info(f"Backup created: {backup_path}")
            
            # Write modified manifest
            with open(manifest_path, 'w') as f:
                f.write(new_manifest)
            
            log_pass("Manifest saved successfully")
            log_info(f"Modified manifest: {manifest_path}")
            log_info(f"Backup location: {backup_path}")
            
            return True
    
    except yaml.YAMLError as e:
        log_fail(f"YAML parsing error: {str(e)}")
        return False
    except Exception as e:
        log_fail(f"Unexpected error: {str(e)}")
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
    """Main entry point with argparse support"""
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='CIS 3.2.2 Automation: Configure kube-apiserver audit logging (idempotent, dry-run capable)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Dry-run (test without applying changes)
  python3 harden_apiserver_audit.py --dry-run

  # Apply changes to the manifest
  python3 harden_apiserver_audit.py --apply

  # Apply without explicit flag (default)
  python3 harden_apiserver_audit.py
        """
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Test mode: write to .new file and show diff without modifying original'
    )
    
    parser.add_argument(
        '--apply',
        action='store_true',
        help='Apply mode: modify the original manifest (default if neither flag specified)'
    )
    
    parser.add_argument(
        '--audit-policy',
        default='/etc/kubernetes/audit-policy.yaml',
        help='Path to audit policy file (default: /etc/kubernetes/audit-policy.yaml)'
    )
    
    parser.add_argument(
        '--audit-log-path',
        default='/var/log/kubernetes/audit/audit.log',
        help='Path to audit log file (default: /var/log/kubernetes/audit/audit.log)'
    )
    
    parser.add_argument(
        '--manifest',
        default='/etc/kubernetes/manifests/kube-apiserver.yaml',
        help='Path to kube-apiserver manifest (default: /etc/kubernetes/manifests/kube-apiserver.yaml)'
    )
    
    parser.add_argument(
        '--audit-log-maxage',
        type=int,
        default=30,
        help='Audit log max age in days (default: 30)'
    )
    
    args = parser.parse_args()
    
    # Determine mode (dry-run or apply)
    dry_run_mode = args.dry_run
    
    # Configuration
    AUDIT_POLICY_FILE = args.audit_policy
    APISERVER_MANIFEST = args.manifest
    AUDIT_LOG_PATH = args.audit_log_path
    AUDIT_LOG_MAXAGE = args.audit_log_maxage
    
    log_info("=" * 70)
    log_info("CIS 3.2.2 Automation: Audit Policy Configuration (v3 - Idempotent)")
    log_info("=" * 70)
    log_debug(f"Mode: {'DRY-RUN' if dry_run_mode else 'APPLY'}")
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
    log_info("=" * 70)
    log_info("Step 1: Creating CIS-compliant audit policy...")
    log_info("=" * 70)
    if not create_audit_policy(AUDIT_POLICY_FILE):
        log_fail("Failed to create audit policy")
        return 1
    
    # Step 2: Create audit log directory
    log_info("=" * 70)
    log_info("Step 2: Creating audit log directory...")
    log_info("=" * 70)
    if not create_audit_log_directory(AUDIT_LOG_PATH):
        log_fail("Failed to create audit log directory")
        return 1
    
    # Step 3: IDEMPOTENTLY modify kube-apiserver manifest
    log_info("=" * 70)
    log_info(f"Step 3: IDEMPOTENTLY configuring kube-apiserver manifest ({['APPLY', 'DRY-RUN'][dry_run_mode]})...")
    log_info("=" * 70)
    if not modify_apiserver_manifest(
        APISERVER_MANIFEST,
        AUDIT_POLICY_FILE,
        AUDIT_LOG_PATH,
        AUDIT_LOG_MAXAGE,
        dry_run=dry_run_mode
    ):
        log_fail("Failed to modify kube-apiserver manifest")
        return 1
    
    # Success!
    log_info("=" * 70)
    log_pass("CIS 3.2.2 automation completed successfully!")
    log_info("=" * 70)
    log_info("")
    log_info("Summary of changes:")
    log_info(f"  ✓ Audit policy: {AUDIT_POLICY_FILE}")
    log_info(f"  ✓ Audit log directory: {os.path.dirname(AUDIT_LOG_PATH)}/")
    log_info(f"  ✓ Kube-apiserver manifest: {APISERVER_MANIFEST}")
    log_info("")
    
    if dry_run_mode:
        log_info("DRY-RUN SUMMARY:")
        log_info("  - Changes have been written to: {}.new".format(APISERVER_MANIFEST))
        log_info("  - Original manifest is unchanged")
        log_info("  - To apply changes, remove --dry-run flag or use --apply")
    else:
        log_info("APPLY SUMMARY:")
        log_info("  - Original manifest has been backed up")
        log_info("  - Changes applied to: {}".format(APISERVER_MANIFEST))
        log_info("  - Monitor kube-apiserver restart")
        log_info("  - Verify audit logs being written")
        log_info("  - Run audit script to verify: ./3.2.2_audit.sh")
    
    log_info("")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
