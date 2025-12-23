#!/usr/bin/env python3
"""
Kubelet Config Manager
Safely updates /var/lib/kubelet/config.yaml with proper YAML hierarchy handling.
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
import shutil

try:
    import yaml
except ImportError:
    print("[ERROR] PyYAML not installed. Install with: pip3 install pyyaml", file=sys.stderr)
    sys.exit(1)


class KubeletConfigManager:
    def __init__(self, config_file, backup_dir="/var/backups/cis-kubelet"):
        self.config_file = Path(config_file)
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        if not self.config_file.exists():
            raise FileNotFoundError(f"Config file not found: {config_file}")
    
    def create_backup(self):
        """Create timestamped backup of config file."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"config.yaml.{timestamp}.bak"
        shutil.copy2(self.config_file, backup_file)
        return backup_file
    
    def restore_backup(self, backup_file):
        """Restore config from backup."""
        shutil.copy2(backup_file, self.config_file)
    
    def load_config(self):
        """Load YAML config file."""
        try:
            with open(self.config_file, 'r') as f:
                config = yaml.safe_load(f)
                return config if config else {}
        except Exception as e:
            raise RuntimeError(f"Failed to load YAML: {e}")
    
    def save_config(self, config):
        """Save YAML config file with proper formatting."""
        try:
            with open(self.config_file, 'w') as f:
                yaml.dump(
                    config,
                    f,
                    default_flow_style=False,
                    sort_keys=False,
                    allow_unicode=True,
                    width=1000
                )
        except Exception as e:
            raise RuntimeError(f"Failed to save YAML: {e}")
    
    def set_nested_key(self, config, key_path, value):
        """
        Set a nested key in config (e.g., 'authentication.anonymous.enabled').
        Handles missing parent blocks gracefully.
        """
        keys = key_path.split('.')
        current = config
        
        # Navigate/create path to parent
        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            elif not isinstance(current[key], dict):
                raise ValueError(f"Cannot navigate through non-dict value at key '{key}'")
            current = current[key]
        
        # Set final value, converting string values to appropriate types
        final_key = keys[-1]
        current[final_key] = self._parse_value(value)
        
        return config
    
    def _parse_value(self, value):
        """Convert string values to appropriate Python types."""
        if isinstance(value, bool):
            return value
        
        # Handle string input
        if value.lower() in ('true', 'yes', '1'):
            return True
        if value.lower() in ('false', 'no', '0'):
            return False
        
        # Try to parse as integer
        try:
            return int(value)
        except ValueError:
            pass
        
        # Try to parse as JSON array
        if value.startswith('[') and value.endswith(']'):
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                pass
        
        # Return as string
        return value
    
    def update(self, key_path, value):
        """Update a key in the config and save."""
        backup_file = self.create_backup()
        
        try:
            # Load current config
            config = self.load_config()
            
            # Update the nested key
            config = self.set_nested_key(config, key_path, value)
            
            # Save updated config
            self.save_config(config)
            
            # Verify YAML is valid
            self.load_config()
            
            return True, backup_file
        
        except Exception as e:
            # Restore on error
            self.restore_backup(backup_file)
            raise RuntimeError(f"Update failed, backup restored: {e}")


def main():
    parser = argparse.ArgumentParser(
        description='Update kubelet config YAML files safely'
    )
    parser.add_argument(
        '--config',
        type=str,
        default='/var/lib/kubelet/config.yaml',
        help='Path to kubelet config file'
    )
    parser.add_argument(
        '--key',
        type=str,
        required=True,
        help='Nested key path (e.g., authentication.anonymous.enabled)'
    )
    parser.add_argument(
        '--value',
        type=str,
        required=True,
        help='Value to set (converted to appropriate type)'
    )
    parser.add_argument(
        '--backup-dir',
        type=str,
        default='/var/backups/cis-kubelet',
        help='Directory for backups'
    )
    
    args = parser.parse_args()
    
    try:
        manager = KubeletConfigManager(args.config, args.backup_dir)
        success, backup_file = manager.update(args.key, args.value)
        
        if success:
            print(f"[PASS] Updated {args.key} = {args.value}")
            print(f"[INFO] Backup: {backup_file}")
            sys.exit(0)
        else:
            print(f"[FAIL] Failed to update {args.key}", file=sys.stderr)
            sys.exit(1)
    
    except Exception as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
