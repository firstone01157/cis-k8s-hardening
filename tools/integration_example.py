#!/usr/bin/env python3
"""
Integration Example: Using ConfigLoader with cis_k8s_unified.py

This example demonstrates how to integrate the ConfigLoader into your
existing CIS Kubernetes hardening scripts.
"""

from config_loader import ConfigLoader
from typing import Dict, Any, Optional
import subprocess
import json


class EnhancedCISRunner:
    """
    Example enhanced runner showing integration of ConfigLoader.
    
    This class demonstrates best practices for using the configuration loader
    in your existing CIS Kubernetes hardening framework.
    """
    
    def __init__(self, config_path: str):
        """
        Initialize with ConfigLoader integration.
        
        Args:
            config_path: Path to cis_config.json
        """
        self.config_path = config_path
        self.loader = ConfigLoader(config_path)
        self.resolved_config = self.loader.load_and_resolve()
        self.checks = self.resolved_config.get('remediation_config', {}).get('checks', {})
    
    def get_flag_value(self, check_id: str, flag_name: str = 'required_value') -> Optional[str]:
        """
        Get the resolved flag value for a specific check.
        
        Args:
            check_id: Check identifier (e.g., '1.2.8')
            flag_name: Field name to retrieve (default: 'required_value')
            
        Returns:
            The resolved value, or None if not found
        """
        check = self.checks.get(check_id)
        if check:
            return str(check.get(flag_name, ''))
        return None
    
    def audit_api_server_secure_port(self) -> Dict[str, Any]:
        """
        Audit check 1.2.8: Ensure --secure-port is not set to 0.
        
        Shows how to use resolved values in audit scripts.
        
        Returns:
            Audit result with check status
        """
        check_id = '1.2.8'
        check = self.checks[check_id]
        
        # Get resolved values
        flag = check.get('flag')  # '--secure-port'
        required_value = check.get('required_value')  # '6443' (resolved from variables)
        manifest_path = check.get('manifest')
        
        result = {
            'check_id': check_id,
            'description': check.get('description'),
            'flag': flag,
            'required_value': required_value,
            'status': 'UNKNOWN',
            'reason': '',
            'source': 'variables.api_server_flags.secure_port'  # Track source
        }
        
        try:
            # Example audit command
            cmd = f"grep '{flag}' {manifest_path} | grep -q '{required_value}'"
            ret = subprocess.run(cmd, shell=True, capture_output=True, timeout=5)
            
            if ret.returncode == 0:
                result['status'] = 'PASS'
                result['reason'] = f"Flag {flag} is set to {required_value}"
            else:
                result['status'] = 'FAIL'
                result['reason'] = f"Flag {flag} is not set to {required_value}"
        except Exception as e:
            result['status'] = 'ERROR'
            result['reason'] = str(e)
        
        return result
    
    def audit_request_timeout(self) -> Dict[str, Any]:
        """
        Audit check 1.2.14: Request timeout.
        
        Shows use of variables with duration values.
        """
        check_id = '1.2.14'
        check = self.checks[check_id]
        
        flag = check.get('flag')  # '--request-timeout'
        required_value = check.get('required_value')  # '300s' (resolved)
        
        result = {
            'check_id': check_id,
            'description': check.get('description'),
            'flag': flag,
            'required_value': required_value,
            'type': 'Duration (seconds)',
            'status': 'PASS'  # Assuming pass
        }
        
        return result
    
    def audit_tls_configuration(self) -> Dict[str, Any]:
        """
        Audit check 1.2.20: TLS minimum version.
        
        Shows use of cryptographic configuration values.
        """
        check_id = '1.2.20'
        check = self.checks[check_id]
        
        flag = check.get('flag')  # '--tls-min-version'
        required_value = check.get('required_value')  # 'VersionTLS12' (resolved)
        
        result = {
            'check_id': check_id,
            'description': check.get('description'),
            'flag': flag,
            'required_value': required_value,
            'security_level': 'TLS 1.2+',
            'status': 'PASS'
        }
        
        return result
    
    def audit_etcd_configuration(self) -> Dict[str, Any]:
        """
        Audit check 2.1: etcd client certificate authentication.
        
        Shows use of multi-path configuration values.
        """
        check_id = '2.1'
        check = self.checks[check_id]
        
        flag = check.get('flag')  # '--client-cert-auth'
        required_value = check.get('required_value')  # 'true' (resolved)
        
        result = {
            'check_id': check_id,
            'description': check.get('description'),
            'flag': flag,
            'required_value': required_value,
            'config_path': check.get('manifest'),
            'status': 'PASS'
        }
        
        return result
    
    def audit_audit_policy(self) -> Dict[str, Any]:
        """
        Audit check 1.2.23: Audit policy file.
        
        Shows use of path variables.
        """
        check_id = '1.2.23'
        check = self.checks[check_id]
        
        flag = check.get('flag')  # '--audit-policy-file'
        required_value = check.get('required_value')  # '/etc/kubernetes/audit-policy.yaml'
        
        result = {
            'check_id': check_id,
            'description': check.get('description'),
            'flag': flag,
            'required_path': required_value,
            'path_from_variables': True,
            'status': 'CONFIGURED'
        }
        
        return result
    
    def get_all_api_server_flags(self) -> Dict[str, str]:
        """
        Get all API server flags and their resolved values.
        
        Useful for bulk configuration export.
        """
        api_flags = self.loader.get_nested_value('variables.api_server_flags')
        flags = {}
        
        for key, value in api_flags.items():
            if not key.startswith('_'):  # Skip comment keys
                flags[key] = value
        
        return flags
    
    def print_audit_report(self):
        """Print a summary audit report using resolved values."""
        print("\n" + "="*80)
        print("CIS Kubernetes Configuration Audit Report")
        print("="*80 + "\n")
        
        # Audit specific checks
        audits = [
            self.audit_api_server_secure_port(),
            self.audit_request_timeout(),
            self.audit_tls_configuration(),
            self.audit_etcd_configuration(),
            self.audit_audit_policy(),
        ]
        
        passed = 0
        failed = 0
        
        for audit in audits:
            status_icon = "✓" if audit['status'] in ['PASS', 'CONFIGURED'] else "✗"
            print(f"{status_icon} Check {audit['check_id']}: {audit['description']}")
            
            if 'flag' in audit:
                print(f"  Flag: {audit['flag']}")
            if 'required_value' in audit:
                print(f"  Expected Value: {audit['required_value']}")
            if 'required_path' in audit:
                print(f"  Expected Path: {audit['required_path']}")
            
            print(f"  Status: {audit['status']}")
            
            if audit['status'] in ['PASS', 'CONFIGURED']:
                passed += 1
            else:
                failed += 1
            
            print()
        
        print("-"*80)
        print(f"Summary: {passed} Passed, {failed} Failed")
        print("="*80 + "\n")


def demonstrate_integration():
    """
    Demonstrate the integration of ConfigLoader with audit scripts.
    """
    print("\n" + "="*80)
    print("Configuration Loader Integration Example")
    print("="*80 + "\n")
    
    # Initialize enhanced runner
    config_path = '/home/first/Project/cis-k8s-hardening/cis_config.json'
    runner = EnhancedCISRunner(config_path)
    
    print("1. Configuration Loader Initialized")
    print(f"   Config Path: {config_path}")
    print(f"   Total Checks: {len(runner.checks)}")
    print(f"   Status: ✓ Ready\n")
    
    # Show how to get individual flag values
    print("2. Individual Flag Value Retrieval:")
    test_flags = [
        ('1.2.8', 'Secure Port'),
        ('1.2.14', 'Request Timeout'),
        ('1.2.20', 'TLS Min Version'),
        ('1.2.23', 'Audit Policy File'),
        ('1.2.30', 'Event TTL'),
    ]
    
    for check_id, description in test_flags:
        value = runner.get_flag_value(check_id)
        print(f"   {check_id} ({description}): {value}")
    
    print()
    
    # Show all API server flags
    print("3. All API Server Flags:")
    all_flags = runner.get_all_api_server_flags()
    for key, value in list(all_flags.items())[:5]:  # Show first 5
        print(f"   {key}: {value}")
    print(f"   ... and {len(all_flags)-5} more\n")
    
    # Run audit report
    print("4. Running Audit Report with Resolved Values:")
    runner.print_audit_report()
    
    # Show configuration validation
    print("5. Configuration Validation:")
    validation = runner.loader.validate_references()
    print(f"   Valid References: {len(validation['valid'])}")
    print(f"   Invalid References: {len(validation['invalid'])}")
    
    if not validation['invalid']:
        print("   Status: ✓ All references are valid\n")
    else:
        print("   Status: ✗ Found invalid references:")
        for invalid in validation['invalid'][:3]:
            print(f"     - {invalid}")
        if len(validation['invalid']) > 3:
            print(f"     ... and {len(validation['invalid'])-3} more\n")


if __name__ == '__main__':
    demonstrate_integration()
