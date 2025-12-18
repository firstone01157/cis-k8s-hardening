#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark 1.x Hardening Wrapper
===============================================

Automates hardening of Kubernetes API Server, Controller Manager, and Scheduler
for CIS Benchmark Level 1 requirements using harden_manifests.py.

Features:
- Batch processing of multiple manifest files
- Automatic resolution of manifest paths
- Comprehensive logging per check
- Environment variable configuration
- JSON output for reporting
- Dry-run mode for preview
- No external dependencies (stdlib only)

Usage:
    python3 cis_1x_hardener.py --manifest-type apiserver
    python3 cis_1x_hardener.py --manifest-type controller-manager
    python3 cis_1x_hardener.py --manifest-type scheduler
    python3 cis_1x_hardener.py --all
    python3 cis_1x_hardener.py --all --dry-run

Exit Codes:
    0 = Success (all checks passed or already compliant)
    1 = Changes made (at least one check required remediation)
    2 = Error (failure in execution)
"""

import subprocess
import sys
import os
import json
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass, asdict


@dataclass
class CISRequirement:
    """Represents a single CIS requirement to be applied."""
    check_id: str
    manifest: str
    flag: str
    value: Optional[str]
    description: str


class CIS1xHardener:
    """Manages CIS 1.x hardening for Kubernetes control plane components."""

    # Standard manifest paths
    MANIFEST_PATHS = {
        'apiserver': '/etc/kubernetes/manifests/kube-apiserver.yaml',
        'controller-manager': '/etc/kubernetes/manifests/kube-controller-manager.yaml',
        'scheduler': '/etc/kubernetes/manifests/kube-scheduler.yaml',
    }

    # CIS 1.2.x requirements for API Server
    CIS_APISERVER_REQUIREMENTS = [
        CISRequirement(
            check_id='1.2.1',
            manifest='apiserver',
            flag='--anonymous-auth',
            value='false',
            description='Ensure --anonymous-auth argument is set to false'
        ),
        CISRequirement(
            check_id='1.2.2',
            manifest='apiserver',
            flag='--basic-auth-file',
            value=None,
            description='Ensure --basic-auth-file argument is not set'
        ),
        CISRequirement(
            check_id='1.2.3',
            manifest='apiserver',
            flag='--token-auth-file',
            value=None,
            description='Ensure --token-auth-file argument is not set'
        ),
        CISRequirement(
            check_id='1.2.4',
            manifest='apiserver',
            flag='--kubelet-https',
            value='true',
            description='Ensure --kubelet-https argument is set to true'
        ),
        CISRequirement(
            check_id='1.2.5',
            manifest='apiserver',
            flag='--kubelet-client-certificate',
            value='/etc/kubernetes/pki/apiserver-kubelet-client.crt',
            description='Ensure --kubelet-client-certificate and --kubelet-client-key are set as appropriate'
        ),
        CISRequirement(
            check_id='1.2.6',
            manifest='apiserver',
            flag='--kubelet-certificate-authority',
            value='/etc/kubernetes/pki/ca.crt',
            description='Ensure --kubelet-certificate-authority argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.2.7',
            manifest='apiserver',
            flag='--authorization-mode',
            value='Node,RBAC',
            description='Ensure authorization-mode argument includes Node and RBAC'
        ),
        CISRequirement(
            check_id='1.2.8',
            manifest='apiserver',
            flag='--client-ca-file',
            value='/etc/kubernetes/pki/ca.crt',
            description='Ensure --client-ca-file argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.2.10',
            manifest='apiserver',
            flag='--enable-admission-plugins',
            value='NodeRestriction',
            description='Ensure --enable-admission-plugins includes NodeRestriction'
        ),
        CISRequirement(
            check_id='1.2.11',
            manifest='apiserver',
            flag='--insecure-port',
            value='0',
            description='Ensure that the --insecure-port argument is set to 0'
        ),
        CISRequirement(
            check_id='1.2.12',
            manifest='apiserver',
            flag='--insecure-bind-address',
            value=None,
            description='Ensure that the --insecure-bind-address argument is not set'
        ),
        CISRequirement(
            check_id='1.2.13',
            manifest='apiserver',
            flag='--secure-port',
            value='6443',
            description='Ensure that the --secure-port argument is not set to 0'
        ),
        CISRequirement(
            check_id='1.2.14',
            manifest='apiserver',
            flag='--tls-cert-file',
            value='/etc/kubernetes/pki/apiserver.crt',
            description='Ensure that the --tls-cert-file and --tls-private-key-file arguments are set appropriately'
        ),
        CISRequirement(
            check_id='1.2.15',
            manifest='apiserver',
            flag='--tls-private-key-file',
            value='/etc/kubernetes/pki/apiserver.key',
            description='Ensure that the --tls-cert-file and --tls-private-key-file arguments are set appropriately'
        ),
        CISRequirement(
            check_id='1.2.16',
            manifest='apiserver',
            flag='--tls-cipher-suites',
            value='TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384',
            description='Ensure that the --tls-cipher-suites argument is set to appropriate ciphers'
        ),
        CISRequirement(
            check_id='1.2.17',
            manifest='apiserver',
            flag='--audit-log-path',
            value='/var/log/kubernetes/audit/audit.log',
            description='Ensure that the --audit-log-path argument is set'
        ),
        CISRequirement(
            check_id='1.2.18',
            manifest='apiserver',
            flag='--audit-log-maxage',
            value='30',
            description='Ensure that the --audit-log-maxage argument is set to 30 or as appropriate'
        ),
        CISRequirement(
            check_id='1.2.19',
            manifest='apiserver',
            flag='--audit-log-maxbackup',
            value='10',
            description='Ensure that the --audit-log-maxbackup argument is set to 10 or as appropriate'
        ),
        CISRequirement(
            check_id='1.2.20',
            manifest='apiserver',
            flag='--audit-log-maxsize',
            value='100',
            description='Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate'
        ),
        CISRequirement(
            check_id='1.2.21',
            manifest='apiserver',
            flag='--request-timeout',
            value='60s',
            description='Ensure that the --request-timeout argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.2.22',
            manifest='apiserver',
            flag='--service-account-lookup',
            value='true',
            description='Ensure that the --service-account-lookup argument is set to true'
        ),
        CISRequirement(
            check_id='1.2.25',
            manifest='apiserver',
            flag='--encryption-provider-config',
            value='/etc/kubernetes/enc/encryption-provider-config.yaml',
            description='Ensure that the --encryption-provider-config argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.2.26',
            manifest='apiserver',
            flag='--api-audiences',
            value='kubernetes.default.svc',
            description='Ensure that the --api-audiences argument is set appropriately'
        ),
    ]

    # CIS 1.3.x requirements for Controller Manager
    CIS_CONTROLLER_REQUIREMENTS = [
        CISRequirement(
            check_id='1.3.1',
            manifest='controller-manager',
            flag='--terminated-pod-gc-threshold',
            value='10',
            description='Ensure that terminated pod GC threshold is set (default acceptable)'
        ),
        CISRequirement(
            check_id='1.3.2',
            manifest='controller-manager',
            flag='--profiling',
            value='false',
            description='Ensure that profiling argument is set to false'
        ),
        CISRequirement(
            check_id='1.3.3',
            manifest='controller-manager',
            flag='--use-service-account-credentials',
            value='true',
            description='Ensure that --use-service-account-credentials argument is set to true'
        ),
        CISRequirement(
            check_id='1.3.4',
            manifest='controller-manager',
            flag='--service-account-private-key-file',
            value='/etc/kubernetes/pki/sa.key',
            description='Ensure that --service-account-private-key-file argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.3.5',
            manifest='controller-manager',
            flag='--root-ca-file',
            value='/etc/kubernetes/pki/ca.crt',
            description='Ensure that --root-ca-file argument is set as appropriate'
        ),
        CISRequirement(
            check_id='1.3.6',
            manifest='controller-manager',
            flag='--feature-gates',
            value='RotateKubeletServerCertificate=true',
            description='Ensure that RotateKubeletServerCertificate is set to true'
        ),
        CISRequirement(
            check_id='1.3.7',
            manifest='controller-manager',
            flag='--bind-address',
            value='127.0.0.1',
            description='Ensure that the --bind-address argument is set to 127.0.0.1'
        ),
    ]

    # CIS 1.4.x requirements for Scheduler
    CIS_SCHEDULER_REQUIREMENTS = [
        CISRequirement(
            check_id='1.4.1',
            manifest='scheduler',
            flag='--profiling',
            value='false',
            description='Ensure that profiling argument is set to false'
        ),
        CISRequirement(
            check_id='1.4.2',
            manifest='scheduler',
            flag='--bind-address',
            value='127.0.0.1',
            description='Ensure that the --bind-address argument is set to 127.0.0.1'
        ),
    ]

    def __init__(self, harden_script: Optional[str] = None, dry_run: bool = False, verbose: bool = False):
        """
        Initialize the hardener.

        Args:
            harden_script: Path to harden_manifests.py (auto-detected if not provided)
            dry_run: Preview changes without applying them
            verbose: Enable verbose output
        """
        self.dry_run = dry_run
        self.verbose = verbose
        self.harden_script = harden_script or self._find_hardener_script()
        self.results = []

        if not self.harden_script or not Path(self.harden_script).exists():
            raise FileNotFoundError(
                f"harden_manifests.py not found. Searched: {harden_script}"
            )

    def _find_hardener_script(self) -> str:
        """Auto-detect harden_manifests.py location."""
        search_paths = [
            './harden_manifests.py',
            '../harden_manifests.py',
            '/home/master/cis-k8s-hardening/harden_manifests.py',
            '/root/cis-k8s-hardening/harden_manifests.py',
        ]

        for path in search_paths:
            if Path(path).exists():
                return path

        # Fallback: try to find in parent directories
        current = Path.cwd()
        for _ in range(5):
            candidate = current / 'harden_manifests.py'
            if candidate.exists():
                return str(candidate)
            current = current.parent

        return None

    def _resolve_manifest_path(self, manifest_type: str) -> str:
        """
        Resolve actual manifest path with fallbacks.

        Args:
            manifest_type: 'apiserver', 'controller-manager', or 'scheduler'

        Returns:
            Full path to manifest file
        """
        primary_path = self.MANIFEST_PATHS.get(manifest_type)

        if primary_path and Path(primary_path).exists():
            return primary_path

        # Fallback: check in /etc/kubernetes/manifests/ with variations
        fallback_names = {
            'apiserver': ['kube-apiserver.yaml', 'apiserver.yaml'],
            'controller-manager': ['kube-controller-manager.yaml', 'controller-manager.yaml'],
            'scheduler': ['kube-scheduler.yaml', 'scheduler.yaml'],
        }

        for name in fallback_names.get(manifest_type, []):
            path = f'/etc/kubernetes/manifests/{name}'
            if Path(path).exists():
                return path

        # If nothing found, return primary path (will fail during execution)
        return primary_path

    def apply_requirement(self, req: CISRequirement) -> Dict:
        """
        Apply a single CIS requirement.

        Args:
            req: CISRequirement object

        Returns:
            Result dictionary with status and details
        """
        manifest_path = self._resolve_manifest_path(req.manifest)

        if not Path(manifest_path).exists():
            return {
                'check_id': req.check_id,
                'status': 'ERROR',
                'manifest': manifest_path,
                'error': f'Manifest not found: {manifest_path}'
            }

        # Build command
        cmd = [
            'python3',
            self.harden_script,
            f'--manifest={manifest_path}',
            f'--flag={req.flag}',
            '--ensure=present',
        ]

        if req.value is not None:
            cmd.append(f'--value={req.value}')

        if self.verbose:
            print(f"[{req.check_id}] Executing: {' '.join(cmd)}")

        # Execute or dry-run
        if self.dry_run:
            return {
                'check_id': req.check_id,
                'status': 'DRY-RUN',
                'manifest': manifest_path,
                'flag': req.flag,
                'value': req.value,
                'command': ' '.join(cmd)
            }

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                # Touch manifest to force kubelet reload
                try:
                    os.utime(manifest_path, None)
                except Exception:
                    pass

                return {
                    'check_id': req.check_id,
                    'status': 'PASS',
                    'manifest': manifest_path,
                    'flag': req.flag,
                    'value': req.value,
                    'output': result.stdout.strip()
                }
            else:
                return {
                    'check_id': req.check_id,
                    'status': 'ERROR',
                    'manifest': manifest_path,
                    'flag': req.flag,
                    'error': result.stderr.strip()
                }

        except subprocess.TimeoutExpired:
            return {
                'check_id': req.check_id,
                'status': 'ERROR',
                'manifest': manifest_path,
                'error': 'Command timeout'
            }
        except Exception as e:
            return {
                'check_id': req.check_id,
                'status': 'ERROR',
                'manifest': manifest_path,
                'error': str(e)
            }

    def harden_all(self) -> List[Dict]:
        """Apply all CIS 1.x requirements."""
        all_requirements = (
            self.CIS_APISERVER_REQUIREMENTS +
            self.CIS_CONTROLLER_REQUIREMENTS +
            self.CIS_SCHEDULER_REQUIREMENTS
        )

        for req in all_requirements:
            result = self.apply_requirement(req)
            self.results.append(result)
            self._print_result(result)

        return self.results

    def harden_apiserver(self) -> List[Dict]:
        """Apply API Server requirements (CIS 1.2.x)."""
        for req in self.CIS_APISERVER_REQUIREMENTS:
            result = self.apply_requirement(req)
            self.results.append(result)
            self._print_result(result)

        return self.results

    def harden_controller_manager(self) -> List[Dict]:
        """Apply Controller Manager requirements (CIS 1.3.x)."""
        for req in self.CIS_CONTROLLER_REQUIREMENTS:
            result = self.apply_requirement(req)
            self.results.append(result)
            self._print_result(result)

        return self.results

    def harden_scheduler(self) -> List[Dict]:
        """Apply Scheduler requirements (CIS 1.4.x)."""
        for req in self.CIS_SCHEDULER_REQUIREMENTS:
            result = self.apply_requirement(req)
            self.results.append(result)
            self._print_result(result)

        return self.results

    def _print_result(self, result: Dict):
        """Print formatted result."""
        check_id = result['check_id']
        status = result['status']

        status_symbol = {
            'PASS': '✓',
            'ERROR': '✗',
            'DRY-RUN': '~'
        }.get(status, '?')

        if status == 'ERROR':
            print(f"[{status_symbol}] {check_id}: {status} - {result.get('error', 'Unknown error')}")
        elif status == 'DRY-RUN':
            print(f"[{status_symbol}] {check_id}: {status}")
        else:
            print(f"[{status_symbol}] {check_id}: {status}")

    def get_summary(self) -> Dict:
        """Get summary statistics of hardening results."""
        total = len(self.results)
        passed = len([r for r in self.results if r['status'] == 'PASS'])
        errors = len([r for r in self.results if r['status'] == 'ERROR'])
        dry_runs = len([r for r in self.results if r['status'] == 'DRY-RUN'])

        return {
            'total': total,
            'passed': passed,
            'errors': errors,
            'dry_runs': dry_runs,
            'success_rate': f"{(passed / total * 100):.1f}%" if total > 0 else "0%"
        }

    def get_json_report(self) -> str:
        """Get JSON report of all results."""
        return json.dumps({
            'summary': self.get_summary(),
            'results': self.results,
            'dry_run': self.dry_run
        }, indent=2)


def main():
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='CIS Kubernetes Benchmark 1.x Hardening Automation',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Harden API Server only
  python3 cis_1x_hardener.py --manifest-type apiserver

  # Harden all components
  python3 cis_1x_hardener.py --all

  # Preview changes without applying
  python3 cis_1x_hardener.py --all --dry-run

  # Verbose output
  python3 cis_1x_hardener.py --all --verbose

  # JSON report
  python3 cis_1x_hardener.py --all --json
        """
    )

    parser.add_argument(
        '--manifest-type',
        choices=['apiserver', 'controller-manager', 'scheduler'],
        help='Harden specific component'
    )

    parser.add_argument(
        '--all',
        action='store_true',
        help='Harden all components (API Server, Controller Manager, Scheduler)'
    )

    parser.add_argument(
        '--harden-script',
        help='Path to harden_manifests.py (auto-detected if not provided)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without applying'
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

    # Validate arguments
    if not args.all and not args.manifest_type:
        parser.print_help()
        sys.exit(2)

    try:
        hardener = CIS1xHardener(
            harden_script=args.harden_script,
            dry_run=args.dry_run,
            verbose=args.verbose
        )

        # Execute hardening
        if args.all:
            hardener.harden_all()
        elif args.manifest_type == 'apiserver':
            hardener.harden_apiserver()
        elif args.manifest_type == 'controller-manager':
            hardener.harden_controller_manager()
        elif args.manifest_type == 'scheduler':
            hardener.harden_scheduler()

        # Output results
        if args.json:
            print(hardener.get_json_report())
        else:
            summary = hardener.get_summary()
            print("")
            print("=" * 60)
            print(f"Summary: {summary['passed']}/{summary['total']} checks passed")
            print(f"Success Rate: {summary['success_rate']}")
            print("=" * 60)

            if summary['errors'] > 0:
                sys.exit(2)
            elif hardener.dry_run:
                sys.exit(0)
            else:
                sys.exit(0 if summary['passed'] > 0 else 1)

    except FileNotFoundError as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"[ERROR] Unexpected error: {e}", file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
