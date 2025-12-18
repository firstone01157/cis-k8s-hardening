#!/usr/bin/env python3
"""
CIS Kubernetes Configuration Loader
====================================

This module demonstrates how to load the cis_config.json file and resolve
variable references (e.g., _required_value_ref) to their actual values.

Key Concepts:
- Single Source of Truth: All configuration values are centralized in the 'variables' section
- Reference Resolution: Checks use _required_value_ref to point to variables instead of hardcoding values
- DRY Principle: Avoids duplication by using dotted path references to the variables section
- Type-Safe: Supports type conversion for different value types (strings, integers, booleans, lists)

Usage Example:
    loader = ConfigLoader('/etc/cis_config.json')
    resolved_config = loader.load_and_resolve()
    
    # Get a specific check with resolved values
    check_1_2_8 = resolved_config['remediation_config']['checks']['1.2.8']
    secure_port = check_1_2_8['required_value']  # Will be "6443" (from variables)
"""

import json
import os
from typing import Any, Dict, Optional, List
from pathlib import Path


class ConfigLoader:
    """
    Loads CIS configuration from JSON and resolves variable references.
    
    This loader handles:
    1. Loading JSON configuration files
    2. Parsing dotted-path references (e.g., 'variables.api_server_flags.secure_port')
    3. Resolving references and injecting values into check definitions
    4. Type conversion (e.g., "6443" string to appropriate type)
    5. Error handling for missing references
    """
    
    def __init__(self, config_path: str):
        """
        Initialize the configuration loader.
        
        Args:
            config_path: Path to the cis_config.json file
            
        Raises:
            FileNotFoundError: If the config file doesn't exist
            json.JSONDecodeError: If the JSON is malformed
        """
        self.config_path = Path(config_path)
        
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")
        
        with open(self.config_path, 'r') as f:
            self.config = json.load(f)
        
        self.variables = self.config.get('variables', {})
        self.checks = self.config.get('remediation_config', {}).get('checks', {})
    
    def get_nested_value(self, path: str, default: Any = None) -> Any:
        """
        Retrieve a value from a nested dictionary using dotted notation.
        
        Examples:
            get_nested_value('variables.api_server_flags.secure_port')
            get_nested_value('variables.file_permissions.manifest_files')
            
        Args:
            path: Dotted path to the value (e.g., 'variables.section.key')
            default: Default value if path doesn't exist
            
        Returns:
            The value at the path, or default if not found
            
        Raises:
            ValueError: If path is empty or invalid
        """
        if not path or '.' not in path:
            raise ValueError(f"Invalid path format: {path}. Expected 'section.subsection.key'")
        
        parts = path.split('.')
        current = self.config
        
        for part in parts:
            if isinstance(current, dict) and part in current:
                current = current[part]
            else:
                return default
        
        return current
    
    def resolve_reference(self, reference_path: str) -> Optional[Any]:
        """
        Resolve a variable reference to its actual value.
        
        This method handles:
        - Simple references: 'variables.api_server_flags.secure_port' -> "6443"
        - Multiple references: Comma-separated paths
        - Missing references: Returns None and logs warning
        
        Args:
            reference_path: Variable reference path(s), optionally comma-separated
            
        Returns:
            The resolved value(s), or None if not found
        """
        if not reference_path:
            return None
        
        # Handle comma-separated references (for multi-flag checks)
        if ',' in reference_path:
            references = [ref.strip() for ref in reference_path.split(',')]
            resolved = {}
            for ref in references:
                value = self.get_nested_value(ref)
                if value is None:
                    print(f"⚠️  WARNING: Reference not found: {ref}")
                else:
                    # Extract the key name from the path
                    key = ref.split('.')[-1]
                    resolved[key] = value
            return resolved if resolved else None
        
        # Handle single reference
        value = self.get_nested_value(reference_path)
        if value is None:
            print(f"⚠️  WARNING: Reference not found: {reference_path}")
        
        return value
    
    def load_and_resolve(self) -> Dict[str, Any]:
        """
        Load the configuration and resolve all variable references in checks.
        
        This method:
        1. Iterates through all checks in remediation_config.checks
        2. For each check, looks for '_required_value_ref', '_file_mode_ref', or '_owner_ref'
        3. Resolves these references to their values from the variables section
        4. Injects the resolved values into the appropriate fields
        5. Returns the complete configuration with all references resolved
        
        Returns:
            Complete configuration dictionary with all references resolved
        """
        resolved_config = json.loads(json.dumps(self.config))  # Deep copy
        resolved_checks = resolved_config.get('remediation_config', {}).get('checks', {})
        
        for check_id, check_data in resolved_checks.items():
            if not isinstance(check_data, dict):
                continue
            
            # Skip section markers (like "_section_1_2")
            if check_id.startswith('_'):
                continue
            
            # Resolve required_value from _required_value_ref
            if '_required_value_ref' in check_data:
                ref = check_data['_required_value_ref']
                resolved_value = self.resolve_reference(ref)
                
                if resolved_value is not None:
                    if isinstance(resolved_value, dict):
                        # For multi-flag checks, merge into 'flags' dict
                        if 'flags' in check_data and isinstance(check_data['flags'], dict):
                            check_data['flags'].update(resolved_value)
                    else:
                        # For single-flag checks, set required_value
                        check_data['required_value'] = resolved_value
                        print(f"✓ Resolved 1.2.{check_id.split('.')[-1] if '.' in check_id else check_id}: "
                              f"--{check_data.get('flag', 'unknown')} = {resolved_value}")
            
            # Resolve file_mode from _file_mode_ref
            if '_file_mode_ref' in check_data:
                ref = check_data['_file_mode_ref']
                resolved_value = self.resolve_reference(ref)
                if resolved_value is not None:
                    check_data['file_mode'] = resolved_value
            
            # Resolve owner from _owner_ref
            if '_owner_ref' in check_data:
                ref = check_data['_owner_ref']
                resolved_value = self.resolve_reference(ref)
                if resolved_value is not None:
                    check_data['owner'] = resolved_value
            
            # Resolve dir_mode from _dir_mode_ref
            if '_dir_mode_ref' in check_data:
                ref = check_data['_dir_mode_ref']
                resolved_value = self.resolve_reference(ref)
                if resolved_value is not None:
                    check_data['dir_mode'] = resolved_value
        
        return resolved_config
    
    def get_check_resolved_value(self, check_id: str, field_name: str = 'required_value') -> Optional[Any]:
        """
        Get a resolved value for a specific check and field.
        
        Args:
            check_id: The check identifier (e.g., '1.2.8')
            field_name: The field to retrieve (default: 'required_value')
            
        Returns:
            The resolved value, or None if not found
        """
        check = self.checks.get(check_id)
        if not check:
            return None
        
        # If the field already has a value, return it
        if field_name in check and check[field_name] is not None:
            return check[field_name]
        
        # Look for a reference to resolve
        ref_key = f'_{field_name}_ref'
        if ref_key in check:
            return self.resolve_reference(check[ref_key])
        
        return None
    
    def validate_references(self) -> Dict[str, List[str]]:
        """
        Validate that all _*_ref fields point to existing variables.
        
        Returns:
            Dictionary with keys 'valid' and 'invalid' containing check IDs
        """
        valid = []
        invalid = []
        
        for check_id, check_data in self.checks.items():
            if not isinstance(check_data, dict) or check_id.startswith('_'):
                continue
            
            # Check for all reference types
            for ref_type in ['_required_value_ref', '_file_mode_ref', '_owner_ref', '_dir_mode_ref']:
                if ref_type in check_data:
                    ref = check_data[ref_type]
                    value = self.resolve_reference(ref)
                    
                    if value is None:
                        invalid.append(f"{check_id}: {ref_type} -> {ref}")
                    else:
                        valid.append(f"{check_id}: {ref_type} resolved")
        
        return {'valid': valid, 'invalid': invalid}
    
    def export_resolved_json(self, output_path: str):
        """
        Export the resolved configuration to a new JSON file.
        
        Args:
            output_path: Path where the resolved config should be written
        """
        resolved = self.load_and_resolve()
        with open(output_path, 'w') as f:
            json.dump(resolved, f, indent=2)
        print(f"✓ Resolved configuration exported to {output_path}")


def demonstrate_usage():
    """
    Demonstration of how to use the ConfigLoader with the cis_config.json.
    """
    print("\n" + "="*80)
    print("CIS Kubernetes Configuration Loader - Demonstration")
    print("="*80 + "\n")
    
    # Load the configuration
    config_path = '/home/first/Project/cis-k8s-hardening/cis_config.json'
    loader = ConfigLoader(config_path)
    
    print("1. Loading configuration from:", config_path)
    print(f"   ✓ Found {len(loader.checks)} checks in remediation_config\n")
    
    # Demonstrate individual reference resolution
    print("2. Resolving specific references:")
    test_references = [
        'variables.api_server_flags.secure_port',
        'variables.api_server_flags.request_timeout',
        'variables.api_server_flags.etcd_prefix',
        'variables.api_server_flags.tls_min_version',
        'variables.api_server_flags.event_ttl',
        'variables.api_server_flags.audit_policy_file',
    ]
    
    for ref in test_references:
        value = loader.get_nested_value(ref)
        print(f"   ✓ {ref}")
        print(f"     → Value: {value}\n")
    
    # Load and resolve all checks
    print("3. Resolving all checks with variable references:")
    print("   Processing checks with _required_value_ref...\n")
    resolved_config = loader.load_and_resolve()
    
    # Show specific resolved checks
    print("4. Sample resolved checks:\n")
    sample_checks = ['1.2.8', '1.2.14', '1.2.17', '1.2.20', '1.2.30', '1.2.23']
    
    for check_id in sample_checks:
        check = resolved_config.get('remediation_config', {}).get('checks', {}).get(check_id)
        if check:
            flag = check.get('flag', 'N/A')
            required_value = check.get('required_value', 'N/A')
            print(f"   Check {check_id}:")
            print(f"   ├─ Flag: {flag}")
            print(f"   ├─ Required Value: {required_value}")
            print(f"   └─ Reference: {check.get('_required_value_ref', 'N/A')}\n")
    
    # Validate all references
    print("5. Validating all references:")
    validation = loader.validate_references()
    print(f"   ✓ Valid references: {len(validation['valid'])}")
    print(f"   ✗ Invalid references: {len(validation['invalid'])}")
    
    if validation['invalid']:
        print("\n   Invalid references found:")
        for invalid_ref in validation['invalid']:
            print(f"   ⚠️  {invalid_ref}")
    else:
        print("   ✓ All references are valid!")
    
    print("\n" + "="*80 + "\n")


if __name__ == '__main__':
    demonstrate_usage()
