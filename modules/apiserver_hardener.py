#!/usr/bin/env python3
import os
import sys
import yaml
import shutil
import time
import subprocess
from datetime import datetime

# Configuration
MANIFEST_PATH = "/etc/kubernetes/manifests/kube-apiserver.yaml"
BACKUP_DIR = "/etc/kubernetes/manifests/backups"
ADMISSION_CONTROL_DIR = "/etc/kubernetes/admission-control"

ENFORCED_FLAGS = {
    "--audit-log-path": "/var/log/kubernetes/audit/audit.log",
    "--audit-log-maxage": "30",
    "--audit-log-maxbackup": "10",
    "--audit-log-maxsize": "100",
    "--profiling": "false",
    "--service-account-lookup": "true",
    "--kubelet-certificate-authority": "/etc/kubernetes/pki/ca.crt",
    "--kubelet-client-certificate": "/etc/kubernetes/pki/apiserver-kubelet-client.crt",
    "--kubelet-client-key": "/etc/kubernetes/pki/apiserver-kubelet-client.key",
    "--tls-cipher-suites": "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "--authorization-mode": "Node,RBAC",
    "--admission-control-config-file": "/etc/kubernetes/admission-control/admission-control.yaml",
    "--service-account-key-file": "/etc/kubernetes/pki/sa.pub",
    "--etcd-certfile": "/etc/kubernetes/pki/apiserver-etcd-client.crt",
    "--etcd-keyfile": "/etc/kubernetes/pki/apiserver-etcd-client.key",
    "--tls-cert-file": "/etc/kubernetes/pki/apiserver.crt",
    "--tls-private-key-file": "/etc/kubernetes/pki/apiserver.key"
}

class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'

def log_info(msg):
    print(f"{Colors.CYAN}[INFO]{Colors.ENDC} {msg}")

def log_success(msg):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.ENDC} {msg}")

def log_warn(msg):
    print(f"{Colors.YELLOW}[WARN]{Colors.ENDC} {msg}")

def log_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.ENDC} {msg}")

def ensure_directories():
    """Ensure necessary directories exist."""
    if not os.path.exists(BACKUP_DIR):
        os.makedirs(BACKUP_DIR, exist_ok=True)
        log_info(f"Created backup directory: {BACKUP_DIR}")
    
    if not os.path.exists(ADMISSION_CONTROL_DIR):
        os.makedirs(ADMISSION_CONTROL_DIR, exist_ok=True)
        log_info(f"Created admission control directory: {ADMISSION_CONTROL_DIR}")

def create_backup(file_path):
    """Create a timestamped backup of the file."""
    if not os.path.exists(file_path):
        log_error(f"File not found: {file_path}")
        return None
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = os.path.basename(file_path)
    backup_path = os.path.join(BACKUP_DIR, f"{filename}.{timestamp}.bak")
    shutil.copy2(file_path, backup_path)
    log_info(f"Backup created: {backup_path}")
    return backup_path

def enforce_apiserver_hardening():
    log_info(f"{Colors.BOLD}Starting Force Enforcement for kube-apiserver...{Colors.ENDC}")
    
    ensure_directories()
    
    if not os.path.exists(MANIFEST_PATH):
        log_error(f"Manifest not found at {MANIFEST_PATH}")
        sys.exit(1)
    
    # 1. Create Backup
    create_backup(MANIFEST_PATH)
    
    # 2. Load YAML
    try:
        with open(MANIFEST_PATH, 'r') as f:
            data = yaml.safe_load(f)
    except Exception as e:
        log_error(f"Failed to load YAML: {e}")
        sys.exit(1)
    
    # 3. Locate command list
    try:
        containers = data.get('spec', {}).get('containers', [])
        if not containers:
            log_error("No containers found in manifest spec")
            sys.exit(1)
        
        # Target the first container (usually kube-apiserver)
        container = containers[0]
        if 'command' not in container:
            container['command'] = ['kube-apiserver']
        
        command = container['command']
    except Exception as e:
        log_error(f"Failed to parse manifest structure: {e}")
        sys.exit(1)
    
    # 4. Enforce Flags
    modified = False
    for flag, value in ENFORCED_FLAGS.items():
        found = False
        for i, arg in enumerate(command):
            if arg.startswith(f"{flag}="):
                if arg != f"{flag}={value}":
                    log_info(f"Updating {flag} to {value}")
                    command[i] = f"{flag}={value}"
                    modified = True
                found = True
                break
            elif arg == flag:
                # Flag exists without value, but we expect a value
                log_info(f"Updating {flag} with value {value}")
                command[i] = f"{flag}={value}"
                modified = True
                found = True
                break
        
        if not found:
            log_info(f"Appending {flag}={value}")
            command.append(f"{flag}={value}")
            modified = True
    
    if not modified:
        log_success("All flags are already correctly set. No changes needed.")
        # We still proceed to write and restart to be absolutely sure of persistence
    
    # 5. Write YAML
    try:
        with open(MANIFEST_PATH, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False, indent=2, width=1000)
        log_success("Manifest written to disk.")
    except Exception as e:
        log_error(f"Failed to write manifest: {e}")
        sys.exit(1)
    
    # 6. Verify Write
    log_info("Verifying write...")
    try:
        with open(MANIFEST_PATH, 'r') as f:
            content = f.read()
        
        missing_flags = []
        for flag, value in ENFORCED_FLAGS.items():
            expected = f"{flag}={value}"
            if expected not in content:
                missing_flags.append(expected)
        
        if missing_flags:
            log_error(f"Verification FAILED! Missing flags: {missing_flags}")
            raise Exception("Write verification failed - flags not found in file after write")
        
        log_success("Write verification PASSED.")
    except Exception as e:
        log_error(f"Verification error: {e}")
        sys.exit(1)
    
    # 7. Restart Logic
    log_warn("Triggering kube-apiserver restart via crictl...")
    try:
        # Stop pods
        subprocess.run("crictl pods --name kube-apiserver -q | xargs -r crictl stopp", shell=True, check=False)
        # Remove pods
        subprocess.run("crictl pods --name kube-apiserver -q | xargs -r crictl rmp", shell=True, check=False)
        log_success("Restart commands sent.")
    except Exception as e:
        log_error(f"Failed to execute crictl commands: {e}")
    
    log_info("Waiting 30s for Kubelet to reload the manifest...")
    time.sleep(30)
    
    log_success("Hardening process completed.")

if __name__ == "__main__":
    if os.geteuid() != 0:
        log_error("This script must be run as root (sudo).")
        sys.exit(1)
    
    enforce_apiserver_hardening()
