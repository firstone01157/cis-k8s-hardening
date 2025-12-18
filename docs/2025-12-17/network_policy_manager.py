#!/usr/bin/env python3
"""
CIS Benchmark 5.3.2 - NetworkPolicy Automation Script
Ensures all Kubernetes namespaces have a NetworkPolicy defined
Compatible with cis_k8s_unified.py runner

Features:
- Lists all namespaces using kubectl
- Skips system namespaces (kube-system, kube-public, etc.)
- Checks if NetworkPolicy already exists in namespace
- Applies CisDefaultAllow policy (allow all traffic) if missing
- Comprehensive logging and reporting
- Exit codes: 0 (PASS), 1 (FAIL/remediated), 2 (ERROR)
"""

import subprocess
import json
import sys
import os
import argparse
from datetime import datetime
from pathlib import Path


class NetworkPolicyManager:
    """Manages NetworkPolicy creation for CIS Benchmark 5.3.2 compliance"""
    
    # System namespaces that typically have special handling
    SYSTEM_NAMESPACES = {
        'kube-system',
        'kube-public',
        'kube-node-lease',
        'kube-apiserver',
        'default',  # Often used by system services
        'openshift-*',  # OpenShift specific
        'calico-*',  # Calico network plugin
        'weave*',  # Weave network plugin
        'flannel*',  # Flannel network plugin
        'cilium-*',  # Cilium network plugin
    }
    
    # Default allow-all NetworkPolicy YAML
    DEFAULT_POLICY_TEMPLATE = """apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cis-default-allow
  namespace: {namespace}
  labels:
    cis-benchmark: "5.3.2"
    app: network-policy-manager
spec:
  podSelector: {{}}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {{}}
    - podSelector: {{}}
  egress:
  - to:
    - namespaceSelector: {{}}
    - podSelector: {{}}
"""
    
    def __init__(self, skip_system_ns=True, dry_run=False, verbose=False):
        """
        Initialize NetworkPolicyManager
        
        Args:
            skip_system_ns: Skip system namespaces (default: True)
            dry_run: Show what would be done without making changes
            verbose: Enable verbose output
        """
        self.skip_system_ns = skip_system_ns
        self.dry_run = dry_run
        self.verbose = verbose
        self.stats = {
            'total_namespaces': 0,
            'skipped_namespaces': 0,
            'already_has_policy': 0,
            'policy_applied': 0,
            'policy_apply_failed': 0,
            'errors': []
        }
        self.updated_namespaces = []
        self.skipped_namespaces = []
        self.already_compliant_namespaces = []
        self.failed_namespaces = []
    
    def is_system_namespace(self, namespace):
        """Check if namespace matches system namespace patterns"""
        if not self.skip_system_ns:
            return False
        
        # Direct matches
        if namespace in self.SYSTEM_NAMESPACES:
            return True
        
        # Pattern matches (wildcards)
        for pattern in self.SYSTEM_NAMESPACES:
            if '*' in pattern:
                pattern_prefix = pattern.rstrip('*')
                if namespace.startswith(pattern_prefix):
                    return True
        
        return False
    
    def get_all_namespaces(self):
        """
        Get all namespaces using kubectl
        
        Returns:
            list: Namespace names, or empty list if error
        """
        try:
            result = subprocess.run(
                ['kubectl', 'get', 'namespaces', '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode != 0:
                self.stats['errors'].append(f"kubectl get namespaces failed: {result.stderr}")
                return []
            
            data = json.loads(result.stdout)
            namespaces = [item['metadata']['name'] for item in data.get('items', [])]
            
            if self.verbose:
                print(f"[INFO] Found {len(namespaces)} total namespaces")
            
            return sorted(namespaces)
        
        except subprocess.TimeoutExpired:
            self.stats['errors'].append("kubectl get namespaces timed out")
            return []
        except json.JSONDecodeError as e:
            self.stats['errors'].append(f"Failed to parse kubectl output: {e}")
            return []
        except Exception as e:
            self.stats['errors'].append(f"Unexpected error getting namespaces: {e}")
            return []
    
    def has_network_policy(self, namespace):
        """
        Check if namespace has a NetworkPolicy already defined
        
        Args:
            namespace: Kubernetes namespace name
            
        Returns:
            tuple: (has_policy: bool, policy_count: int, error: str or None)
        """
        try:
            result = subprocess.run(
                ['kubectl', 'get', 'networkpolicy', '-n', namespace, '-o', 'json'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                # 404 means namespace doesn't have policies - this is normal
                if 'NotFound' in result.stderr or 'No resources found' in result.stderr:
                    return False, 0, None
                # Other errors should be reported
                return False, 0, result.stderr.strip()
            
            data = json.loads(result.stdout)
            policies = data.get('items', [])
            policy_count = len(policies)
            
            if self.verbose and policy_count > 0:
                policy_names = [p['metadata']['name'] for p in policies]
                print(f"[DEBUG] Namespace '{namespace}' has {policy_count} policy(ies): {policy_names}")
            
            return policy_count > 0, policy_count, None
        
        except subprocess.TimeoutExpired:
            error = f"kubectl check timed out for namespace {namespace}"
            self.stats['errors'].append(error)
            return False, 0, error
        except json.JSONDecodeError as e:
            error = f"Failed to parse policy output for {namespace}: {e}"
            self.stats['errors'].append(error)
            return False, 0, error
        except Exception as e:
            error = f"Unexpected error checking policies in {namespace}: {e}"
            self.stats['errors'].append(error)
            return False, 0, error
    
    def apply_default_policy(self, namespace):
        """
        Apply default allow-all NetworkPolicy to namespace
        
        Args:
            namespace: Kubernetes namespace name
            
        Returns:
            tuple: (success: bool, message: str)
        """
        try:
            policy_yaml = self.DEFAULT_POLICY_TEMPLATE.format(namespace=namespace)
            
            if self.dry_run:
                if self.verbose:
                    print(f"[DRY-RUN] Would apply policy to namespace '{namespace}':")
                    print(policy_yaml)
                return True, f"[DRY-RUN] Policy would be applied"
            
            # Use kubectl apply -f - to pipe YAML
            result = subprocess.run(
                ['kubectl', 'apply', '-f', '-'],
                input=policy_yaml,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                error_msg = result.stderr.strip()
                return False, f"Failed to apply policy: {error_msg}"
            
            if self.verbose:
                print(f"[SUCCESS] Applied policy to namespace '{namespace}'")
            
            return True, "Policy applied successfully"
        
        except subprocess.TimeoutExpired:
            error = f"kubectl apply timed out for namespace {namespace}"
            return False, error
        except Exception as e:
            error = f"Unexpected error applying policy to {namespace}: {e}"
            return False, error
    
    def remediate_namespace(self, namespace):
        """
        Process single namespace - check and remediate if needed
        
        Args:
            namespace: Kubernetes namespace name
            
        Returns:
            dict: Result dict with status, action, details
        """
        result = {
            'namespace': namespace,
            'action': None,
            'status': 'UNKNOWN',
            'details': ''
        }
        
        # Check if system namespace
        if self.is_system_namespace(namespace):
            result['action'] = 'SKIPPED'
            result['status'] = 'SKIPPED'
            result['details'] = f"System namespace (skip_system_ns={self.skip_system_ns})"
            self.skipped_namespaces.append(namespace)
            self.stats['skipped_namespaces'] += 1
            return result
        
        # Check if namespace already has policy
        has_policy, policy_count, check_error = self.has_network_policy(namespace)
        
        if check_error:
            result['action'] = 'ERROR'
            result['status'] = 'ERROR'
            result['details'] = check_error
            self.failed_namespaces.append(namespace)
            self.stats['policy_apply_failed'] += 1
            return result
        
        if has_policy:
            result['action'] = 'PASS'
            result['status'] = 'PASS'
            result['details'] = f"Already has {policy_count} NetworkPolicy(ies)"
            self.already_compliant_namespaces.append(namespace)
            self.stats['already_has_policy'] += 1
            return result
        
        # Apply default policy
        success, apply_msg = self.apply_default_policy(namespace)
        
        if success:
            result['action'] = 'REMEDIATED'
            result['status'] = 'FIXED'
            result['details'] = apply_msg
            self.updated_namespaces.append(namespace)
            self.stats['policy_applied'] += 1
            return result
        else:
            result['action'] = 'FAILED'
            result['status'] = 'ERROR'
            result['details'] = apply_msg
            self.failed_namespaces.append(namespace)
            self.stats['policy_apply_failed'] += 1
            return result
    
    def process_all_namespaces(self):
        """
        Process all namespaces and apply policies as needed
        
        Returns:
            dict: Aggregated results and statistics
        """
        namespaces = self.get_all_namespaces()
        
        if not namespaces:
            print(f"[ERROR] Could not retrieve namespaces")
            return {
                'success': False,
                'processed': 0,
                'stats': self.stats,
                'results': []
            }
        
        self.stats['total_namespaces'] = len(namespaces)
        results = []
        
        for namespace in namespaces:
            result = self.remediate_namespace(namespace)
            results.append(result)
            
            # Print per-namespace status
            status_symbol = {
                'PASS': '✓',
                'FIXED': '+',
                'SKIPPED': '~',
                'ERROR': '✗',
                'UNKNOWN': '?'
            }.get(result['status'], '?')
            
            print(f"[{status_symbol}] {namespace:40s} {result['status']:10s} {result['details']}")
        
        return {
            'success': len(self.failed_namespaces) == 0,
            'processed': len(namespaces),
            'stats': self.stats,
            'results': results
        }
    
    def generate_report(self):
        """Generate human-readable report of operations"""
        report = []
        report.append("=" * 80)
        report.append("CIS Benchmark 5.3.2 - NetworkPolicy Remediation Report")
        report.append("=" * 80)
        report.append(f"Timestamp: {datetime.now().isoformat()}")
        report.append(f"Skip System Namespaces: {self.skip_system_ns}")
        report.append(f"Dry Run: {self.dry_run}")
        report.append("")
        
        report.append("SUMMARY STATISTICS:")
        report.append("-" * 80)
        report.append(f"  Total Namespaces Processed:  {self.stats['total_namespaces']}")
        report.append(f"  Already Had Policy:          {self.stats['already_has_policy']}")
        report.append(f"  Policies Applied:            {self.stats['policy_applied']}")
        report.append(f"  System Namespaces Skipped:   {self.stats['skipped_namespaces']}")
        report.append(f"  Policy Application Failures: {self.stats['policy_apply_failed']}")
        report.append("")
        
        if self.already_compliant_namespaces:
            report.append("ALREADY COMPLIANT NAMESPACES:")
            report.append("-" * 80)
            for ns in sorted(self.already_compliant_namespaces):
                report.append(f"  ✓ {ns}")
            report.append("")
        
        if self.updated_namespaces:
            report.append("NEWLY REMEDIATED NAMESPACES:")
            report.append("-" * 80)
            for ns in sorted(self.updated_namespaces):
                report.append(f"  + {ns}")
            report.append("")
        
        if self.skipped_namespaces:
            report.append("SKIPPED NAMESPACES:")
            report.append("-" * 80)
            for ns in sorted(self.skipped_namespaces):
                report.append(f"  ~ {ns}")
            report.append("")
        
        if self.failed_namespaces:
            report.append("FAILED NAMESPACES:")
            report.append("-" * 80)
            for ns in sorted(self.failed_namespaces):
                report.append(f"  ✗ {ns}")
            report.append("")
        
        if self.stats['errors']:
            report.append("ERRORS ENCOUNTERED:")
            report.append("-" * 80)
            for error in self.stats['errors']:
                report.append(f"  {error}")
            report.append("")
        
        report.append("=" * 80)
        
        return "\n".join(report)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='CIS Benchmark 5.3.2 - NetworkPolicy Remediation',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check and remediate all non-system namespaces
  python3 network_policy_manager.py --remediate
  
  # Dry run (show what would be done)
  python3 network_policy_manager.py --remediate --dry-run
  
  # Include system namespaces
  python3 network_policy_manager.py --remediate --include-system
  
  # Verbose output
  python3 network_policy_manager.py --remediate --verbose
        """
    )
    
    parser.add_argument(
        '--remediate',
        action='store_true',
        help='Apply remediation (create missing NetworkPolicies)'
    )
    
    parser.add_argument(
        '--audit',
        action='store_true',
        help='Audit mode - only check compliance without changes'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    
    parser.add_argument(
        '--include-system',
        action='store_true',
        dest='include_system',
        help='Include system namespaces in processing'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results in JSON format'
    )
    
    args = parser.parse_args()
    
    # Validate mode selection
    if args.remediate and args.audit:
        print("[ERROR] Cannot use both --remediate and --audit", file=sys.stderr)
        sys.exit(2)
    
    if not args.remediate and not args.audit:
        print("[WARNING] No mode specified. Use --audit for checking or --remediate for fixing", file=sys.stderr)
        args.audit = True
    
    # Create manager
    manager = NetworkPolicyManager(
        skip_system_ns=not args.include_system,
        dry_run=args.dry_run,
        verbose=args.verbose
    )
    
    # Process namespaces
    print("[*] Scanning Kubernetes namespaces...")
    result = manager.process_all_namespaces()
    
    # Output report
    if args.json:
        print(json.dumps({
            'success': result['success'],
            'processed': result['processed'],
            'stats': result['stats'],
            'results': result['results']
        }, indent=2))
    else:
        print(manager.generate_report())
    
    # Exit code
    # 0 = PASS (all namespaces already compliant)
    # 1 = FIXED/Changes made (remediation applied)
    # 2 = ERROR (failures occurred)
    
    if manager.stats['policy_apply_failed'] > 0:
        sys.exit(2)
    elif manager.stats['policy_applied'] > 0:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
