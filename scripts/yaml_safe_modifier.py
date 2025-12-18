#!/usr/bin/env python3
"""
YAML Safe Modifier for Kubernetes Manifests
-------------------------------------------
Intelligently modifies Kubernetes Static Pod manifests (API Server, Controller Manager, etc.)
to ensure security flags are set correctly without corrupting existing configurations.

This script handles both simple string overwrites and smart CSV appends (e.g., for 
authorization-mode or admission-plugins) to prevent cluster crashes.

Usage:
    python3 yaml_safe_modifier.py --file <path> --key <flag> --value <val> --type <string|csv>
"""

import os
import sys
import shutil
import argparse
import re
from datetime import datetime
from pathlib import Path

# Try to import ruamel.yaml for high-fidelity YAML manipulation
# Fallback to robust regex-based modification if not available
HAS_RUAMEL = False
try:
    from ruamel.yaml import YAML
    HAS_RUAMEL = True
except ImportError:
    HAS_RUAMEL = False

class YAMLSafeModifier:
    def __init__(self, verbose=True):
        self.verbose = verbose

    def log(self, message):
        if self.verbose:
            print(message)

    def create_backup(self, file_path):
        """Creates a timestamped backup of the file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{file_path}.bak_{timestamp}"
        try:
            shutil.copy2(file_path, backup_path)
            self.log(f"[INFO] Backup created: {backup_path}")
            return backup_path
        except Exception as e:
            self.log(f"[ERROR] Failed to create backup: {e}")
            return None

    def modify_csv_value(self, current_val, new_val):
        """Handles smart append for CSV strings."""
        if not current_val:
            return new_val
        
        # Split by comma and strip whitespace
        parts = [p.strip() for p in current_val.split(',') if p.strip()]
        
        if new_val not in parts:
            parts.append(new_val)
            self.log(f"[INFO] Appending '{new_val}' to CSV list.")
            return ",".join(parts)
        
        self.log(f"[INFO] Value '{new_val}' already exists in CSV list. No change needed.")
        return current_val

    def update_with_ruamel(self, file_path, key, value, mod_type):
        """Updates manifest using ruamel.yaml (preserves comments/formatting)."""
        yaml = YAML()
        yaml.preserve_quotes = True
        yaml.indent(mapping=2, sequence=4, offset=2)
        
        with open(file_path, 'r') as f:
            data = yaml.load(f)

        if not data:
            return False

        try:
            container = data['spec']['containers'][0]
            if 'command' not in container:
                container['command'] = []
            command = container['command']
        except (KeyError, TypeError, IndexError):
            self.log("[ERROR] Invalid manifest structure for Static Pod.")
            return False

        found = False
        flag_prefix = f"{key}="
        
        for i, item in enumerate(command):
            if isinstance(item, str) and (item == key or item.startswith(flag_prefix)):
                found = True
                if mod_type == 'csv':
                    current_val = item.split('=', 1)[1] if '=' in item else ""
                    new_val = self.modify_csv_value(current_val, value)
                    command[i] = f"{key}={new_val}"
                else:
                    self.log(f"[INFO] Overwriting '{key}' with '{value}'.")
                    command[i] = f"{key}={value}"
                break

        if not found:
            new_flag = f"{key}={value}"
            command.append(new_flag)
            self.log(f"[INFO] Flag '{key}' not found. Appending: {new_flag}")

        with open(file_path, 'w') as f:
            yaml.dump(data, f)
        return True

    def update_with_regex(self, file_path, key, value, mod_type):
        """Fallback: Updates manifest using robust line-by-line regex."""
        with open(file_path, 'r') as f:
            lines = f.readlines()

        modified_lines = []
        in_command = False
        found = False
        command_indent = 0
        
        for line in lines:
            stripped = line.strip()
            
            # Detect command section
            if stripped.startswith('command:') or stripped.startswith('args:'):
                in_command = True
                command_indent = len(line) - len(line.lstrip())
                modified_lines.append(line)
                continue

            if in_command:
                current_indent = len(line) - len(line.lstrip()) if stripped else 0
                if stripped and current_indent <= command_indent and not stripped.startswith('-'):
                    in_command = False
                
                if in_command and key in line:
                    found = True
                    indent = len(line) - len(line.lstrip())
                    
                    if mod_type == 'csv':
                        # Extract current value
                        match = re.search(rf"{re.escape(key)}=([^\s\"']+)", line)
                        current_val = match.group(1) if match else ""
                        new_val = self.modify_csv_value(current_val, value)
                        
                        # Replace in line
                        if '=' in line:
                            new_line = re.sub(rf"({re.escape(key)}=)[^\s\"']+", rf"\1{new_val}", line)
                        else:
                            new_line = line.replace(key, f"{key}={new_val}")
                        modified_lines.append(new_line)
                    else:
                        # String overwrite
                        if '=' in line:
                            new_line = re.sub(rf"({re.escape(key)}=)[^\s\"']+", rf"\1{value}", line)
                        else:
                            new_line = line.replace(key, f"{key}={value}")
                        modified_lines.append(new_line)
                    continue

            modified_lines.append(line)

        if not found:
            # If not found, we'd need to find the end of the command list to append
            # This is complex with regex, so we'll just append to the end of the file 
            # if we can't find a safe spot, but usually the flag exists.
            self.log(f"[WARN] Flag '{key}' not found in command section. Manual check required.")
            return False

        with open(file_path, 'w') as f:
            f.writelines(modified_lines)
        return True

    # --- Backward Compatibility Methods for Remediation Scripts ---
    
    def add_flag_to_manifest(self, manifest, container, flag, value):
        return self.update_with_ruamel(manifest, flag, value, 'string') if HAS_RUAMEL else self.update_with_regex(manifest, flag, value, 'string')

    def update_flag_in_manifest(self, manifest, container, flag, value):
        return self.update_with_ruamel(manifest, flag, value, 'string') if HAS_RUAMEL else self.update_with_regex(manifest, flag, value, 'string')

    def remove_flag_from_manifest(self, manifest, container, flag):
        # Simple implementation for removal
        if HAS_RUAMEL:
            yaml = YAML()
            with open(manifest, 'r') as f: data = yaml.load(f)
            try:
                cmd = data['spec']['containers'][0]['command']
                data['spec']['containers'][0]['command'] = [i for i in cmd if not i.startswith(flag)]
                with open(manifest, 'w') as f: yaml.dump(data, f)
                return True
            except: return False
        return False

    def flag_exists_in_manifest(self, manifest, flag, value=None):
        with open(manifest, 'r') as f: content = f.read()
        if value: return f"{flag}={value}" in content or f"{flag} {value}" in content
        return flag in content

    def get_flag_value(self, manifest, flag):
        with open(manifest, 'r') as f: content = f.read()
        match = re.search(rf"{re.escape(flag)}=([^\s\"']+)", content)
        return match.group(1) if match else None


def main():
    parser = argparse.ArgumentParser(description="Safely modify Kubernetes manifest flags.")
    parser.add_argument("--file", required=True, help="Path to the YAML manifest file")
    parser.add_argument("--key", required=True, help="The flag key to modify (e.g., --authorization-mode)")
    parser.add_argument("--value", required=True, help="The value to set or ensure exists")
    parser.add_argument("--type", choices=['string', 'csv'], default='string', help="Modification type: string or csv")
    
    args = parser.parse_args()
    
    modifier = YAMLSafeModifier()
    
    if not os.path.exists(args.file):
        print(f"[ERROR] File not found: {args.file}")
        sys.exit(1)

    # 1. Backup
    modifier.create_backup(args.file)
    
    # 2. Modify
    success = False
    if HAS_RUAMEL:
        modifier.log("[INFO] Using ruamel.yaml for modification.")
        success = modifier.update_with_ruamel(args.file, args.key, args.value, args.type)
    else:
        modifier.log("[INFO] ruamel.yaml not found. Using regex fallback.")
        success = modifier.update_with_regex(args.file, args.key, args.value, args.type)

    if success:
        print(f"[SUCCESS] Manifest updated: {args.file}")
        sys.exit(0)
    else:
        print(f"[ERROR] Failed to update manifest.")
        sys.exit(1)

if __name__ == "__main__":
    main()


