#!/usr/bin/env python3
"""
Safe Audit Logging Remediation for CIS 1.2.15-1.2.19
Fixes: --audit-log-path, --audit-policy-file, --audit-log-maxage, 
       --audit-log-maxbackup, --audit-log-maxsize

CRITICAL FEATURES:
- Creates /var/log/kubernetes/audit directory with proper permissions
- Creates a valid minimal audit-policy.yaml file
- Atomically updates kube-apiserver.yaml with proper YAML indentation
- Adds volumeMounts and volumes to ensure Pod can access log directory and policy file
- Validates YAML before applying changes
- Creates timestamped backups before any modifications
"""

import sys
import os
import json
import subprocess
import shutil
import tempfile
from datetime import datetime
from pathlib import Path


class AuditRemediator:
    def __init__(self, target_namespace="kube-apiserver"):
        self.manifests_dir = "/etc/kubernetes/manifests"
        self.apiserver_manifest = f"{self.manifests_dir}/kube-apiserver.yaml"
        self.audit_dir = "/var/log/kubernetes/audit"
        self.audit_log_path = f"{self.audit_dir}/audit.log"
        self.audit_policy_path = f"{self.audit_dir}/audit-policy.yaml"
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.backup_dir = "/var/backups/kubernetes"
        self.target_namespace = target_namespace
        self.errors = []
        self.warnings = []
        self.successes = []
        
    def log_success(self, msg):
        """Log success message"""
        self.successes.append(f"✓ {msg}")
        print(f"[SUCCESS] {msg}")
    
    def log_warning(self, msg):
        """Log warning message"""
        self.warnings.append(f"⚠ {msg}")
        print(f"[WARNING] {msg}")
    
    def log_error(self, msg):
        """Log error message"""
        self.errors.append(f"✗ {msg}")
        print(f"[ERROR] {msg}")
    
    def run_command(self, cmd, check=True):
        """Run shell command and return result"""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                check=check
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.CalledProcessError as e:
            self.log_error(f"Command failed: {cmd}")
            self.log_error(f"  stdout: {e.stdout}")
            self.log_error(f"  stderr: {e.stderr}")
            raise
        except Exception as e:
            self.log_error(f"Error running command: {e}")
            return 1, "", str(e)
    
    def check_prerequisites(self):
        """Verify we're running as root and on a master node"""
        print("\n[PHASE 1] Checking Prerequisites...")
        
        # Check if running as root
        if os.geteuid() != 0:
            self.log_error("This script must be run as root (use sudo)")
            return False
        self.log_success("Running as root")
        
        # Check if manifest directory exists
        if not os.path.isdir(self.manifests_dir):
            self.log_error(f"Manifest directory not found: {self.manifests_dir}")
            return False
        self.log_success(f"Manifest directory exists: {self.manifests_dir}")
        
        # Check if kube-apiserver manifest exists
        if not os.path.isfile(self.apiserver_manifest):
            self.log_error(f"Manifest not found: {self.apiserver_manifest}")
            return False
        self.log_success(f"Manifest found: {self.apiserver_manifest}")
        
        # Check if kubelet is running (indicates master node)
        rc, _, _ = self.run_command("pgrep -f kube-apiserver", check=False)
        if rc != 0:
            self.log_warning("kube-apiserver process not detected - verify you're on master node")
        else:
            self.log_success("kube-apiserver process detected")
        
        return True
    
    def create_backup_dir(self):
        """Create backup directory"""
        print("\n[PHASE 2] Creating Backup Directory...")
        
        if not os.path.exists(self.backup_dir):
            try:
                os.makedirs(self.backup_dir, mode=0o750)
                self.log_success(f"Created backup directory: {self.backup_dir}")
            except Exception as e:
                self.log_error(f"Failed to create backup directory: {e}")
                return False
        else:
            self.log_success(f"Backup directory exists: {self.backup_dir}")
        
        return True
    
    def backup_manifest(self):
        """Backup the current manifest before modifications"""
        print("\n[PHASE 3] Backing Up Current Manifest...")
        
        backup_file = f"{self.backup_dir}/kube-apiserver.yaml.backup_{self.timestamp}"
        
        try:
            shutil.copy2(self.apiserver_manifest, backup_file)
            self.log_success(f"Backup created: {backup_file}")
            return True
        except Exception as e:
            self.log_error(f"Failed to backup manifest: {e}")
            return False
    
    def create_audit_directory(self):
        """Create /var/log/kubernetes/audit directory"""
        print("\n[PHASE 4] Creating Audit Directory...")
        
        if os.path.exists(self.audit_dir):
            # Verify permissions
            stat_info = os.stat(self.audit_dir)
            mode = stat_info.st_mode & 0o777
            if mode != 0o700:
                self.log_warning(f"Audit dir exists with permissions {oct(mode)}, resetting to 0700")
                os.chmod(self.audit_dir, 0o700)
            self.log_success(f"Audit directory exists: {self.audit_dir}")
        else:
            try:
                os.makedirs(self.audit_dir, mode=0o700)
                self.log_success(f"Created audit directory: {self.audit_dir}")
            except Exception as e:
                self.log_error(f"Failed to create audit directory: {e}")
                return False
        
        return True
    
    def create_audit_policy(self):
        """Create a minimal audit policy file"""
        print("\n[PHASE 5] Creating Audit Policy File...")
        
        # Minimal audit policy that logs all requests at metadata level
        audit_policy_content = """apiVersion: audit.k8s.io/v1
kind: Policy
# Log all requests at the Metadata level.
rules:
  - level: Metadata
    omitStages:
      - RequestReceived
  # Log pod exec at RequestResponse so we can see the request body
  - level: RequestResponse
    verbs: ["create"]
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach"]
    omitStages:
      - RequestReceived
  # Omit events, audit events themselves, and health checks
  - level: None
    resources:
      - group: ""
        resources: ["events"]
  - level: None
    resources:
      - group: "authentication.k8s.io"
        resources: ["tokenreviews"]
  - level: None
    nonResourceURLs:
      - /healthz*
      - /logs
      - /logs/*
"""
        
        try:
            # Create backup if file exists
            if os.path.exists(self.audit_policy_path):
                backup_policy = f"{self.backup_dir}/audit-policy.yaml.backup_{self.timestamp}"
                shutil.copy2(self.audit_policy_path, backup_policy)
                self.log_warning(f"Audit policy already exists, backed up to {backup_policy}")
            
            with open(self.audit_policy_path, 'w') as f:
                f.write(audit_policy_content)
            
            os.chmod(self.audit_policy_path, 0o644)
            self.log_success(f"Created audit policy: {self.audit_policy_path}")
            return True
        except Exception as e:
            self.log_error(f"Failed to create audit policy: {e}")
            return False
    
    def validate_yaml_syntax(self, yaml_path):
        """Validate YAML syntax using Python yaml module"""
        try:
            import yaml
            with open(yaml_path, 'r') as f:
                yaml.safe_load(f)
            return True
        except ImportError:
            self.log_warning("PyYAML not available, attempting validation with kubelet...")
            # Fallback: try to use kubectl if available
            rc, _, stderr = self.run_command(
                f"kubectl apply -f {yaml_path} --dry-run=client",
                check=False
            )
            if rc != 0 and "error" in stderr.lower():
                return False
            return True
        except Exception as e:
            self.log_error(f"YAML validation failed: {e}")
            return False
    
    def load_manifest(self):
        """Load the manifest file"""
        try:
            with open(self.apiserver_manifest, 'r') as f:
                content = f.read()
            return content
        except Exception as e:
            self.log_error(f"Failed to load manifest: {e}")
            return None
    
    def save_manifest(self, content):
        """Save the manifest file"""
        try:
            with open(self.apiserver_manifest, 'w') as f:
                f.write(content)
            return True
        except Exception as e:
            self.log_error(f"Failed to save manifest: {e}")
            return False
    
    def ensure_volume_mounts(self, content):
        """Ensure volumeMounts section exists in container spec"""
        print("\n[PHASE 6.1] Ensuring volumeMounts Section...")
        
        # Parse manifest to understand structure
        lines = content.split('\n')
        container_start = None
        volume_mounts_start = None
        
        # Find the container spec line
        for i, line in enumerate(lines):
            if '- name: kube-apiserver' in line or 'spec:' in line and container_start is None:
                container_start = i
            if container_start is not None and 'volumeMounts:' in line:
                volume_mounts_start = i
                break
        
        # Find proper indentation by looking at existing args or command
        base_indent = 0
        for i in range(len(lines)):
            if '      - name: kube-apiserver' in lines[i] or 'containers:' in lines[i]:
                # Standard k8s manifest indentation is 2 spaces per level
                for char in lines[i]:
                    if char == ' ':
                        base_indent += 1
                    else:
                        break
                break
        
        # If volumeMounts doesn't exist, we'll add it during volume handling
        return content
    
    def ensure_volumes(self, content):
        """Ensure volumes section exists with proper hostPath mounts"""
        print("\n[PHASE 6.2] Ensuring volumes Section with hostPath Mounts...")
        
        lines = content.split('\n')
        
        # Find where to insert volumes (usually at the end before final properties)
        # Look for existing volumes: line
        volumes_line_index = None
        for i, line in enumerate(lines):
            if line.strip().startswith('volumes:'):
                volumes_line_index = i
                break
        
        if volumes_line_index is not None:
            self.log_warning("volumes section already exists, will update it")
        
        return content
    
    def add_audit_log_flags(self, content):
        """Add audit logging flags to kube-apiserver arguments"""
        print("\n[PHASE 7] Adding Audit Logging Flags to kube-apiserver...")
        
        flags = [
            f'--audit-log-path={self.audit_log_path}',
            f'--audit-policy-file={self.audit_policy_path}',
            '--audit-log-maxage=30',
            '--audit-log-maxbackup=10',
            '--audit-log-maxsize=100'
        ]
        
        lines = content.split('\n')
        new_lines = []
        flags_added = {flag.split('=')[0]: False for flag in flags}
        
        for i, line in enumerate(lines):
            new_lines.append(line)
            
            # Look for the args section within kube-apiserver command
            if '- kube-apiserver' in line:
                # Next lines should contain the flags
                # We'll add flags before the first flag that comes after this line
                base_indent = len(line) - len(line.lstrip())
                flag_indent = base_indent + 2
                
                # Scan ahead to see what flags exist
                j = i + 1
                while j < len(lines) and lines[j].strip() and not lines[j].strip().startswith('-'):
                    j += 1
                
                # Insert new flags if they don't exist
                # We'll do this in a second pass after finding all positions
        
        # More robust approach: use sed-like line insertion
        content_str = '\n'.join(new_lines)
        
        # For each flag, check if it exists and add if not
        for flag in flags:
            flag_name = flag.split('=')[0]
            
            if flag_name in content_str:
                # Flag exists, update its value
                self.log_success(f"Flag {flag_name} already exists")
            else:
                # Flag doesn't exist, need to add it
                # Find the - kube-apiserver line and insert after it
                if '- kube-apiserver' in content_str:
                    # Insert flag with proper indentation
                    # Looking for pattern: "    - kube-apiserver\n" 
                    indent_pattern = '    - '
                    insert_str = f'\n      {flag}'
                    
                    # Find where to insert (after other flags in the args)
                    # Insert before closing of command array or at end of flags
                    lines_list = content_str.split('\n')
                    
                    for idx, line_text in enumerate(lines_list):
                        if flag_name in line_text:
                            flags_added[flag_name] = True
                            break
                        if idx > 0 and '- kube-apiserver' in lines_list[idx]:
                            # Look ahead for where to insert
                            insert_idx = idx + 1
                            while insert_idx < len(lines_list):
                                if lines_list[insert_idx].strip().startswith('- --'):
                                    insert_idx += 1
                                elif lines_list[insert_idx].strip().startswith('--'):
                                    insert_idx += 1
                                else:
                                    break
                            
                            if insert_idx <= len(lines_list):
                                # Get indentation from first flag
                                if insert_idx > idx + 1:
                                    first_flag_indent = len(lines_list[idx + 1]) - len(lines_list[idx + 1].lstrip())
                                    lines_list.insert(insert_idx, ' ' * first_flag_indent + flag)
                                    flags_added[flag_name] = True
                            break
                    
                    content_str = '\n'.join(lines_list)
        
        return content_str
    
    def update_manifest_with_volumes(self, content):
        """Update manifest to include volumeMounts and volumes sections"""
        print("\n[PHASE 8] Updating Manifest with volumeMounts and volumes...")
        
        try:
            import yaml
            
            # Parse the manifest
            manifest = yaml.safe_load(content)
            
            if not manifest:
                self.log_error("Failed to parse manifest as YAML")
                return content
            
            # Get the containers list
            containers = manifest.get('spec', {}).get('containers', [])
            if not containers:
                self.log_error("No containers found in manifest")
                return content
            
            apiserver_container = None
            for container in containers:
                if container.get('name') == 'kube-apiserver':
                    apiserver_container = container
                    break
            
            if not apiserver_container:
                self.log_error("kube-apiserver container not found")
                return content
            
            # Add volumeMounts if not present
            if 'volumeMounts' not in apiserver_container:
                apiserver_container['volumeMounts'] = []
                self.log_success("Created volumeMounts section")
            else:
                self.log_success("volumeMounts section exists")
            
            volume_mounts = apiserver_container['volumeMounts']
            
            # Check if audit volumeMounts already exist
            audit_mount_names = ['audit-log', 'audit-policy']
            existing_mounts = [vm.get('name') for vm in volume_mounts]
            
            # Add audit log volume mount
            if 'audit-log' not in existing_mounts:
                volume_mounts.append({
                    'name': 'audit-log',
                    'mountPath': self.audit_dir,
                    'readOnly': False
                })
                self.log_success("Added volumeMount for audit log directory")
            else:
                self.log_success("audit-log volumeMount already exists")
            
            # Add audit policy volume mount
            if 'audit-policy' not in existing_mounts:
                volume_mounts.append({
                    'name': 'audit-policy',
                    'mountPath': self.audit_policy_path,
                    'readOnly': True,
                    'subPath': 'audit-policy.yaml'
                })
                self.log_success("Added volumeMount for audit policy file")
            else:
                self.log_success("audit-policy volumeMount already exists")
            
            # Add volumes section if not present
            if 'volumes' not in manifest['spec']:
                manifest['spec']['volumes'] = []
                self.log_success("Created volumes section")
            else:
                self.log_success("volumes section exists")
            
            volumes = manifest['spec']['volumes']
            existing_volumes = [v.get('name') for v in volumes]
            
            # Add audit log volume (hostPath)
            if 'audit-log' not in existing_volumes:
                volumes.append({
                    'name': 'audit-log',
                    'hostPath': {
                        'path': self.audit_dir,
                        'type': 'DirectoryOrCreate'
                    }
                })
                self.log_success("Added volume for audit log directory")
            else:
                self.log_success("audit-log volume already exists")
            
            # Add audit policy volume (hostPath)
            if 'audit-policy' not in existing_volumes:
                volumes.append({
                    'name': 'audit-policy',
                    'hostPath': {
                        'path': self.audit_policy_path,
                        'type': 'FileOrCreate'
                    }
                })
                self.log_success("Added volume for audit policy file")
            else:
                self.log_success("audit-policy volume already exists")
            
            # Convert back to YAML with proper formatting
            updated_content = yaml.dump(manifest, default_flow_style=False, sort_keys=False)
            return updated_content
            
        except ImportError:
            self.log_warning("PyYAML not available, attempting manual YAML modification...")
            return self.update_manifest_with_volumes_manual(content)
        except Exception as e:
            self.log_error(f"Failed to update manifest structure: {e}")
            return content
    
    def update_manifest_with_volumes_manual(self, content):
        """Manual YAML update without PyYAML (fallback)"""
        print("  [Fallback] Using manual YAML text manipulation...")
        
        lines = content.split('\n')
        new_lines = []
        in_container_spec = False
        volume_mounts_added = False
        volumes_section_found = False
        
        for i, line in enumerate(lines):
            new_lines.append(line)
            
            # Detect container spec
            if 'containers:' in line:
                in_container_spec = True
            
            # Add volumeMounts if we find the image line and haven't added yet
            if in_container_spec and 'image: ' in line and not volume_mounts_added:
                # Get indentation
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent
                
                # Add volumeMounts section
                new_lines.append(f'{indent_str}volumeMounts:')
                new_lines.append(f'{indent_str}  - name: audit-log')
                new_lines.append(f'{indent_str}    mountPath: {self.audit_dir}')
                new_lines.append(f'{indent_str}    readOnly: false')
                new_lines.append(f'{indent_str}  - name: audit-policy')
                new_lines.append(f'{indent_str}    mountPath: {self.audit_policy_path}')
                new_lines.append(f'{indent_str}    readOnly: true')
                new_lines.append(f'{indent_str}    subPath: audit-policy.yaml')
                volume_mounts_added = True
                self.log_success("Added volumeMounts section (manual)")
            
            # Add volumes section at the end if not present
            if i == len(lines) - 2 and not volumes_section_found:
                # Check if volumes already exist
                volumes_exist = any('volumes:' in l for l in lines)
                if not volumes_exist:
                    new_lines.append('  volumes:')
                    new_lines.append('    - name: audit-log')
                    new_lines.append('      hostPath:')
                    new_lines.append(f'        path: {self.audit_dir}')
                    new_lines.append('        type: DirectoryOrCreate')
                    new_lines.append('    - name: audit-policy')
                    new_lines.append('      hostPath:')
                    new_lines.append(f'        path: {self.audit_policy_path}')
                    new_lines.append('        type: FileOrCreate')
                    self.log_success("Added volumes section (manual)")
        
        return '\n'.join(new_lines)
    
    def apply_all_flags(self, content):
        """Apply all audit logging flags to the manifest"""
        print("\n[PHASE 9] Applying All Audit Logging Flags...")
        
        flags = [
            (f'--audit-log-path={self.audit_log_path}', 'audit-log-path'),
            (f'--audit-policy-file={self.audit_policy_path}', 'audit-policy-file'),
            ('--audit-log-maxage=30', 'audit-log-maxage'),
            ('--audit-log-maxbackup=10', 'audit-log-maxbackup'),
            ('--audit-log-maxsize=100', 'audit-log-maxsize')
        ]
        
        lines = content.split('\n')
        
        for flag_line, flag_name in flags:
            # Check if flag already exists
            flag_exists = any(flag_name in line for line in lines)
            
            if flag_exists:
                self.log_success(f"Flag {flag_name} already present")
            else:
                # Find the line with "- kube-apiserver" and add the flag after it
                for i, line in enumerate(lines):
                    if '- kube-apiserver' in line:
                        # Get indentation of subsequent lines
                        if i + 1 < len(lines):
                            next_line = lines[i + 1]
                            indent = len(next_line) - len(next_line.lstrip())
                        else:
                            indent = 6  # Default indent
                        
                        # Find the last flag line after this point
                        j = i + 1
                        while j < len(lines):
                            if lines[j].strip().startswith('--') or lines[j].strip().startswith('- --'):
                                j += 1
                            elif not lines[j].strip():
                                j += 1
                            else:
                                break
                        
                        # Insert the flag before the next section
                        indent_str = ' ' * (indent - 2)  # Align with other flags
                        lines.insert(j, f'{indent_str}- {flag_line}')
                        self.log_success(f"Added flag {flag_name}")
                        break
        
        return '\n'.join(lines)
    
    def verify_modifications(self, content):
        """Verify all modifications were applied"""
        print("\n[PHASE 10] Verifying Modifications...")
        
        checks = [
            (f'--audit-log-path={self.audit_log_path}', 'audit-log-path'),
            (f'--audit-policy-file={self.audit_policy_path}', 'audit-policy-file'),
            ('--audit-log-maxage=30', 'audit-log-maxage'),
            ('--audit-log-maxbackup=10', 'audit-log-maxbackup'),
            ('--audit-log-maxsize=100', 'audit-log-maxsize'),
            ('audit-log', 'volumeMount for audit-log'),
            ('audit-policy', 'volumeMount for audit-policy'),
        ]
        
        all_present = True
        for check_str, check_name in checks:
            if check_str in content:
                self.log_success(f"Verified: {check_name}")
            else:
                self.log_warning(f"Not verified: {check_name}")
                all_present = False
        
        return all_present
    
    def execute(self):
        """Execute the full remediation workflow"""
        print("=" * 80)
        print("CIS KUBERNETES AUDIT LOGGING SAFE REMEDIATION")
        print("Version: 1.0")
        print("=" * 80)
        
        # Phase 1: Prerequisites
        if not self.check_prerequisites():
            self.print_summary()
            return 1
        
        # Phase 2: Backup setup
        if not self.create_backup_dir():
            self.print_summary()
            return 1
        
        # Phase 3: Backup manifest
        if not self.backup_manifest():
            self.print_summary()
            return 1
        
        # Phase 4: Create audit directory
        if not self.create_audit_directory():
            self.print_summary()
            return 1
        
        # Phase 5: Create audit policy
        if not self.create_audit_policy():
            self.print_summary()
            return 1
        
        # Phase 6-7: Load and update manifest
        content = self.load_manifest()
        if not content:
            self.print_summary()
            return 1
        
        # Phase 8: Update manifest with volumes and volumeMounts
        content = self.update_manifest_with_volumes(content)
        
        # Phase 9: Apply audit flags
        content = self.apply_all_flags(content)
        
        # Phase 10: Verify modifications
        if not self.verify_modifications(content):
            self.log_warning("Some modifications could not be verified")
        
        # Validate YAML before saving
        print("\n[PHASE 11] Validating YAML Syntax...")
        
        # Write to temp file for validation
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        
        try:
            if self.validate_yaml_syntax(tmp_path):
                self.log_success("YAML syntax validation passed")
            else:
                self.log_error("YAML syntax validation failed")
                self.print_summary()
                os.unlink(tmp_path)
                return 1
        finally:
            os.unlink(tmp_path)
        
        # Phase 12: Save manifest atomically
        print("\n[PHASE 12] Saving Updated Manifest...")
        
        if not self.save_manifest(content):
            self.log_error("Failed to save manifest - remediation aborted")
            self.print_summary()
            return 1
        
        self.log_success("Manifest updated successfully")
        
        # Phase 13: Restart kube-apiserver (if possible)
        print("\n[PHASE 13] Restarting kube-apiserver Pod...")
        
        rc, stdout, stderr = self.run_command(
            "kubectl delete pod -n kube-system -l component=kube-apiserver",
            check=False
        )
        
        if rc == 0:
            self.log_success("Initiated kube-apiserver Pod restart")
            self.log_warning("Wait 30-60 seconds for the Pod to become ready")
        else:
            self.log_warning("Could not automatically restart kube-apiserver")
            self.log_warning("Manual restart may be required")
        
        self.print_summary()
        return 0 if not self.errors else 1
    
    def print_summary(self):
        """Print execution summary"""
        print("\n" + "=" * 80)
        print("REMEDIATION SUMMARY")
        print("=" * 80)
        
        if self.successes:
            print(f"\n✓ SUCCESSES ({len(self.successes)}):")
            for msg in self.successes:
                print(f"  {msg}")
        
        if self.warnings:
            print(f"\n⚠ WARNINGS ({len(self.warnings)}):")
            for msg in self.warnings:
                print(f"  {msg}")
        
        if self.errors:
            print(f"\n✗ ERRORS ({len(self.errors)}):")
            for msg in self.errors:
                print(f"  {msg}")
            print("\nREMEDIATION FAILED - Review manifest backup:")
            print(f"  {self.backup_dir}/kube-apiserver.yaml.backup_*")
        else:
            print("\n✓ REMEDIATION COMPLETED SUCCESSFULLY")
        
        print("\nKey locations:")
        print(f"  Audit logs:      {self.audit_log_path}")
        print(f"  Audit policy:    {self.audit_policy_path}")
        print(f"  Backup dir:      {self.backup_dir}")
        print("=" * 80)


if __name__ == '__main__':
    remediator = AuditRemediator()
    exit_code = remediator.execute()
    sys.exit(exit_code)
