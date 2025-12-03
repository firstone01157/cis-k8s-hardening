#!/usr/bin/env python3
"""
Worker Node Kubelet Recovery Script
Restores a corrupted /var/lib/kubelet/config.yaml with CIS-compliant defaults.
No external dependencies - uses only stdlib (json, re, shutil, subprocess, sys).
"""

import json
import re
import shutil
import subprocess
import sys
import os
from datetime import datetime
from pathlib import Path


class KubeletRecovery:
    """Recover kubelet config from corrupted/broken state."""
    
    def __init__(self, config_path="/var/lib/kubelet/config.yaml"):
        self.config_path = Path(config_path)
        self.backup_dir = Path("/var/backups/cis-kubelet")
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        
        # CIS-compliant defaults
        self.cis_config = {
            "apiVersion": "kubelet.config.k8s.io/v1beta1",
            "kind": "KubeletConfiguration",
            "authentication": {
                "anonymous": {
                    "enabled": False
                },
                "webhook": {
                    "enabled": True
                },
                "x509": {
                    "clientCAFile": "/etc/kubernetes/pki/ca.crt"
                }
            },
            "authorization": {
                "mode": "Webhook"
            },
            "readOnlyPort": 0,
            "streamingConnectionIdleTimeout": "4h0m0s",
            "makeIPTablesUtilChains": True,
            "rotateCertificates": True,
            "serverTLSBootstrap": True,
            "rotateServerCertificates": True,
            "tlsCipherSuites": [
                "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
                "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
                "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
                "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
                "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
            ],
            "podPidsLimit": -1,
            "seccompDefault": True,
            "cgroupDriver": "systemd",
            "clusterDNS": ["10.96.0.10"],
            "clusterDomain": "cluster.local"
        }
    
    def extract_from_broken_config(self):
        """Try to extract critical values from corrupted config file."""
        if not self.config_path.exists():
            print(f"[INFO] Config file not found at {self.config_path}, using defaults")
            return
        
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            # Try to extract clusterDNS (handles various formats)
            dns_match = re.search(
                r'clusterDNS\s*:\s*\[([^\]]+)\]|clusterDNS\s*:\s*\n\s*-\s*(.+)',
                content,
                re.IGNORECASE
            )
            if dns_match:
                dns_value = dns_match.group(1) or dns_match.group(2)
                # Clean up quotes and whitespace
                dns_value = dns_value.strip().strip('"\'')
                self.cis_config["clusterDNS"] = [dns_value]
                print(f"[INFO] Preserved clusterDNS: {dns_value}")
            
            # Try to extract clusterDomain
            domain_match = re.search(
                r'clusterDomain\s*:\s*([^\n,]+)',
                content,
                re.IGNORECASE
            )
            if domain_match:
                domain_value = domain_match.group(1).strip().strip('"\'')
                self.cis_config["clusterDomain"] = domain_value
                print(f"[INFO] Preserved clusterDomain: {domain_value}")
            
            # Try to extract cgroupDriver
            cgroup_match = re.search(
                r'cgroupDriver\s*:\s*([^\n,]+)',
                content,
                re.IGNORECASE
            )
            if cgroup_match:
                cgroup_value = cgroup_match.group(1).strip().strip('"\'')
                self.cis_config["cgroupDriver"] = cgroup_value
                print(f"[INFO] Preserved cgroupDriver: {cgroup_value}")
        
        except Exception as e:
            print(f"[WARN] Could not extract values from broken config: {e}")
            print("[INFO] Using all default values")
    
    def create_backup(self):
        """Create backup of current (broken) config."""
        if not self.config_path.exists():
            print("[INFO] No existing config to backup")
            return None
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"config.yaml.{timestamp}.broken"
        
        try:
            shutil.copy2(self.config_path, backup_file)
            print(f"[INFO] Backup created: {backup_file}")
            return backup_file
        except Exception as e:
            print(f"[ERROR] Failed to create backup: {e}")
            return None
    
    def write_config(self):
        """Write CIS-compliant config as JSON (valid YAML)."""
        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.cis_config, f, indent=2)
            
            # Verify file was written
            if not self.config_path.exists() or self.config_path.stat().st_size == 0:
                raise RuntimeError("Config file write failed or empty")
            
            print(f"[PASS] Config written to {self.config_path}")
            return True
        except Exception as e:
            print(f"[ERROR] Failed to write config: {e}")
            return False
    
    def restart_kubelet(self):
        """Restart kubelet service."""
        try:
            print("[INFO] Running systemctl daemon-reload...")
            result = subprocess.run(
                ["systemctl", "daemon-reload"],
                capture_output=True,
                timeout=10,
                text=True
            )
            if result.returncode != 0:
                print(f"[WARN] daemon-reload returned: {result.returncode}")
            
            print("[INFO] Restarting kubelet...")
            result = subprocess.run(
                ["systemctl", "restart", "kubelet"],
                capture_output=True,
                timeout=30,
                text=True
            )
            
            if result.returncode != 0:
                print(f"[ERROR] kubelet restart failed: {result.stderr}")
                return False
            
            # Wait and verify status
            import time
            time.sleep(2)
            
            result = subprocess.run(
                ["systemctl", "is-active", "kubelet"],
                capture_output=True,
                timeout=5,
                text=True
            )
            
            if result.returncode == 0 and "active" in result.stdout:
                print("[PASS] kubelet is running")
                return True
            else:
                print(f"[ERROR] kubelet not running: {result.stdout}")
                return False
        
        except subprocess.TimeoutExpired:
            print("[ERROR] systemctl command timed out")
            return False
        except Exception as e:
            print(f"[ERROR] Failed to restart kubelet: {e}")
            return False
    
    def verify_config(self):
        """Verify the written config is valid JSON/YAML."""
        try:
            with open(self.config_path, 'r') as f:
                config = json.load(f)
            
            # Check critical CIS settings
            required_keys = [
                "authentication",
                "authorization",
                "readOnlyPort",
                "podPidsLimit",
                "seccompDefault"
            ]
            
            for key in required_keys:
                if key not in config:
                    print(f"[ERROR] Missing required key: {key}")
                    return False
            
            print("[PASS] Config structure verified")
            return True
        except json.JSONDecodeError as e:
            print(f"[ERROR] Config is not valid JSON: {e}")
            return False
        except Exception as e:
            print(f"[ERROR] Failed to verify config: {e}")
            return False
    
    def recover(self):
        """Execute full recovery procedure."""
        print("[INFO] Starting kubelet recovery...")
        print(f"[INFO] Config path: {self.config_path}")
        
        # Step 1: Extract any salvageable values
        print("\n[STEP 1] Extracting values from broken config...")
        self.extract_from_broken_config()
        
        # Step 2: Backup broken config
        print("\n[STEP 2] Backing up broken config...")
        self.create_backup()
        
        # Step 3: Write new config
        print("\n[STEP 3] Writing CIS-compliant config...")
        if not self.write_config():
            print("[FAIL] Failed to write config")
            return False
        
        # Step 4: Verify config
        print("\n[STEP 4] Verifying config structure...")
        if not self.verify_config():
            print("[FAIL] Config verification failed")
            return False
        
        # Step 5: Restart kubelet
        print("\n[STEP 5] Restarting kubelet service...")
        if not self.restart_kubelet():
            print("[FAIL] kubelet restart failed")
            return False
        
        print("\n[PASS] Kubelet recovery complete!")
        return True


def main():
    """Main entry point."""
    # Check if running as root
    if os.geteuid() != 0:
        print("[ERROR] This script must be run as root")
        sys.exit(1)
    
    # Allow custom config path via environment or argument
    config_path = os.environ.get('KUBELET_CONFIG', '/var/lib/kubelet/config.yaml')
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    recovery = KubeletRecovery(config_path)
    
    if recovery.recover():
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
