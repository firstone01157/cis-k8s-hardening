#!/usr/bin/env python3
"""
Safe YAML Manifest Modifier for Kubernetes CIS Remediation

This module provides Python-based file modifications to avoid sed delimiter conflicts
when dealing with file paths (e.g., /etc/kubernetes/pki/ca.crt) that contain slashes.

Author: DevSecOps Team
Date: 2025-12-08
"""

import os
import sys
import json
import logging
import shutil
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List


class YAMLSafeModifier:
    """
    Safe YAML modification utility that avoids sed delimiter conflicts.
    Uses Python file I/O instead of shell sed commands.
    """
    
    def __init__(self, verbose: bool = False):
        """Initialize the modifier with logging."""
        self.verbose = verbose
        self.backup_dir = "/var/backups/cis-remediation"
        self.log_file = "/var/log/cis-remediation.log"
        self._setup_logging()
    
    def _setup_logging(self):
        """Setup logging for operations."""
        log_format = '%(asctime)s - %(levelname)s - %(message)s'
        logging.basicConfig(
            format=log_format,
            level=logging.DEBUG if self.verbose else logging.INFO,
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def create_backup(self, file_path: str) -> Optional[str]:
        """
        Create a timestamped backup of the file.
        
        Args:
            file_path: Path to the file to backup
            
        Returns:
            Path to backup file on success, None on failure
        """
        if not os.path.exists(file_path):
            self.logger.error(f"File not found: {file_path}")
            return None
        
        try:
            os.makedirs(self.backup_dir, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = os.path.join(
                self.backup_dir,
                f"{os.path.basename(file_path)}.{timestamp}.bak"
            )
            shutil.copy2(file_path, backup_path)
            self.logger.info(f"Backup created: {backup_path}")
            return backup_path
        except Exception as e:
            self.logger.error(f"Backup failed: {e}")
            return None
    
    def restore_from_backup(self, file_path: str, backup_path: str) -> bool:
        """
        Restore file from backup.
        
        Args:
            file_path: Path to the file to restore
            backup_path: Path to the backup file
            
        Returns:
            True on success, False on failure
        """
        if not os.path.exists(backup_path):
            self.logger.error(f"Backup file not found: {backup_path}")
            return False
        
        try:
            shutil.copy2(backup_path, file_path)
            self.logger.info(f"Restored from backup: {backup_path} -> {file_path}")
            return True
        except Exception as e:
            self.logger.error(f"Restore failed: {e}")
            return False
    
    def add_flag_to_manifest(
        self,
        manifest_path: str,
        container_name: str,
        flag: str,
        value: Optional[str] = None
    ) -> bool:
        """
        Add a flag to a Kubernetes manifest (safe for paths with slashes).
        
        Example:
            add_flag_to_manifest(
                "/etc/kubernetes/manifests/kube-apiserver.yaml",
                "kube-apiserver",
                "--kubelet-certificate-authority",
                "/etc/kubernetes/pki/ca.crt"
            )
        
        Args:
            manifest_path: Path to the YAML manifest file
            container_name: Name of the container/component (e.g., "kube-apiserver")
            flag: The flag name (e.g., "--kubelet-certificate-authority")
            value: The value for the flag (e.g., "/etc/kubernetes/pki/ca.crt")
            
        Returns:
            True on success, False on failure
        """
        if not os.path.exists(manifest_path):
            self.logger.error(f"Manifest not found: {manifest_path}")
            return False
        
        # Create backup
        backup_path = self.create_backup(manifest_path)
        if not backup_path:
            return False
        
        try:
            # Read the manifest file
            with open(manifest_path, 'r') as f:
                lines = f.readlines()
            
            # Find the container section and add the flag
            modified_lines = []
            found_container = False
            inserted = False
            
            for i, line in enumerate(lines):
                modified_lines.append(line)
                
                # Look for the container name line (e.g., "- kube-apiserver")
                if container_name in line and line.strip().startswith("- " + container_name):
                    found_container = True
                
                # Look for the command section ("command:" or "- --flag" patterns)
                if found_container and not inserted:
                    # Check if line contains the container command start
                    if "command:" in line or (line.strip().startswith("- --") and "command" in "".join(lines[max(0, i-5):i])):
                        # Find where to insert (after "command:" or the last flag)
                        # We'll insert after the command: line or after existing flags
                        
                        # Look ahead to find the right place to insert
                        j = i + 1
                        while j < len(lines):
                            next_line = lines[j]
                            if next_line.strip().startswith("- --"):
                                # This is a flag line, keep going
                                j += 1
                            elif next_line.strip().startswith("-") and ":" not in next_line:
                                # This is another argument, keep going
                                j += 1
                            else:
                                # We've reached the end of flags, insert here
                                break
                        
                        # Get indentation from the last flag line
                        if j > i + 1:
                            last_flag_line = lines[j - 1]
                            indent = len(last_flag_line) - len(last_flag_line.lstrip())
                        else:
                            # Use default indent for Kubernetes YAML (8 spaces)
                            indent = 8
                        
                        # Create the flag line
                        if value:
                            flag_line = " " * indent + f"- {flag}={value}\n"
                        else:
                            flag_line = " " * indent + f"- {flag}\n"
                        
                        # Insert the flag
                        modified_lines.extend([flag_line])
                        inserted = True
                        
                        # Add remaining lines
                        modified_lines.extend(lines[i+1:j])
                        
                        # Fast forward
                        for remaining in lines[j:]:
                            modified_lines.append(remaining)
                        
                        break
            
            if not inserted:
                self.logger.error(f"Could not find insertion point for {container_name} in {manifest_path}")
                self.restore_from_backup(manifest_path, backup_path)
                return False
            
            # Write the modified manifest
            with open(manifest_path, 'w') as f:
                f.writelines(modified_lines)
            
            self.logger.info(f"Added flag to manifest: {flag}={value if value else ''}")
            return True
        
        except Exception as e:
            self.logger.error(f"Modification failed: {e}")
            self.restore_from_backup(manifest_path, backup_path)
            return False
    
    def update_flag_in_manifest(
        self,
        manifest_path: str,
        container_name: str,
        flag: str,
        new_value: str
    ) -> bool:
        """
        Update an existing flag in a Kubernetes manifest.
        
        Args:
            manifest_path: Path to the YAML manifest file
            container_name: Name of the container/component
            flag: The flag name to update
            new_value: The new value for the flag
            
        Returns:
            True on success, False on failure
        """
        if not os.path.exists(manifest_path):
            self.logger.error(f"Manifest not found: {manifest_path}")
            return False
        
        # Create backup
        backup_path = self.create_backup(manifest_path)
        if not backup_path:
            return False
        
        try:
            # Read the manifest file
            with open(manifest_path, 'r') as f:
                content = f.read()
            
            # Find and replace the flag value (using simple string replacement)
            # This is safe because we're looking for a specific flag pattern
            old_pattern = f"- {flag}="
            if old_pattern not in content:
                self.logger.warning(f"Flag not found: {old_pattern}")
                return False
            
            # Replace using regex-like approach but with explicit patterns
            lines = content.split('\n')
            modified_lines = []
            found = False
            
            for line in lines:
                if old_pattern in line:
                    # Extract indentation
                    indent = len(line) - len(line.lstrip())
                    modified_lines.append(" " * indent + f"- {flag}={new_value}")
                    found = True
                else:
                    modified_lines.append(line)
            
            if not found:
                self.logger.error(f"Could not update flag {flag}")
                self.restore_from_backup(manifest_path, backup_path)
                return False
            
            # Write modified content
            with open(manifest_path, 'w') as f:
                f.write('\n'.join(modified_lines))
            
            self.logger.info(f"Updated flag in manifest: {flag}={new_value}")
            return True
        
        except Exception as e:
            self.logger.error(f"Update failed: {e}")
            self.restore_from_backup(manifest_path, backup_path)
            return False
    
    def remove_flag_from_manifest(
        self,
        manifest_path: str,
        container_name: str,
        flag: str
    ) -> bool:
        """
        Remove a flag from a Kubernetes manifest.
        
        Args:
            manifest_path: Path to the YAML manifest file
            container_name: Name of the container/component
            flag: The flag name to remove
            
        Returns:
            True on success, False on failure
        """
        if not os.path.exists(manifest_path):
            self.logger.error(f"Manifest not found: {manifest_path}")
            return False
        
        # Create backup
        backup_path = self.create_backup(manifest_path)
        if not backup_path:
            return False
        
        try:
            # Read the manifest file
            with open(manifest_path, 'r') as f:
                lines = f.readlines()
            
            # Remove lines containing the flag
            modified_lines = [
                line for line in lines
                if not (line.strip().startswith(f"- {flag}") or 
                        line.strip().startswith(f"- {flag}="))
            ]
            
            # Write the modified manifest
            with open(manifest_path, 'w') as f:
                f.writelines(modified_lines)
            
            self.logger.info(f"Removed flag from manifest: {flag}")
            return True
        
        except Exception as e:
            self.logger.error(f"Removal failed: {e}")
            self.restore_from_backup(manifest_path, backup_path)
            return False
    
    def flag_exists_in_manifest(
        self,
        manifest_path: str,
        flag: str,
        value: Optional[str] = None
    ) -> bool:
        """
        Check if a flag exists in a manifest (optionally with a specific value).
        
        Args:
            manifest_path: Path to the YAML manifest file
            flag: The flag name to check
            value: Optional specific value to match
            
        Returns:
            True if flag exists, False otherwise
        """
        if not os.path.exists(manifest_path):
            return False
        
        try:
            with open(manifest_path, 'r') as f:
                content = f.read()
            
            # Check for flag existence
            flag_pattern = f"- {flag}"
            if flag_pattern not in content:
                return False
            
            # If value is specified, check for exact match
            if value:
                full_pattern = f"- {flag}={value}"
                return full_pattern in content
            
            return True
        
        except Exception as e:
            self.logger.error(f"Check failed: {e}")
            return False
    
    def get_flag_value(
        self,
        manifest_path: str,
        flag: str
    ) -> Optional[str]:
        """
        Extract the value of a flag from a manifest.
        
        Args:
            manifest_path: Path to the YAML manifest file
            flag: The flag name to get value for
            
        Returns:
            The flag value if found, None otherwise
        """
        if not os.path.exists(manifest_path):
            return None
        
        try:
            with open(manifest_path, 'r') as f:
                lines = f.readlines()
            
            for line in lines:
                if line.strip().startswith(f"- {flag}="):
                    # Extract the value
                    parts = line.strip().split(f"- {flag}=", 1)
                    if len(parts) > 1:
                        return parts[1].strip()
            
            return None
        
        except Exception as e:
            self.logger.error(f"Get value failed: {e}")
            return None


def main():
    """Simple test function / ฟังก์ชันทดสอบง่ายๆ"""
    modifier = YAMLSafeModifier(verbose=True)
    
    print("[TEST] YAMLSafeModifier initialized successfully")
    print("[TEST] Module ready for use in remediation scripts")


if __name__ == "__main__":
    main()
