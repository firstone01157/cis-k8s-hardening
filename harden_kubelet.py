#!/usr/bin/env python3
"""
Kubelet Configuration Hardener
Safely hardens /var/lib/kubelet/config.yaml with CIS-compliant settings.
Parses as data structure (avoiding sed/YAML indentation errors).
Outputs lowercase booleans (true/false) for audit compatibility.

Configuration:
- Reads environment variables for CIS settings (CONFIG_* prefix)
- Falls back to hardcoded CIS defaults if env vars not present
- Enables config-driven deployment from external runners
"""

import json
import subprocess
import sys
import os
from pathlib import Path
from datetime import datetime
from shutil import copy2


def _get_env_bool(var_name, default):
    """Parse environment variable as boolean.
    
    Args:
        var_name: Name of environment variable
        default: Default boolean value if not set
    
    Returns:
        Boolean value from env var or default
    """
    value = os.environ.get(var_name)
    if value is None:
        return default
    
    # Handle string representations of booleans
    if isinstance(value, str):
        return value.lower() in ('true', '1', 'yes', 'on')
    return bool(value)


def _get_env_int(var_name, default):
    """Parse environment variable as integer.
    
    Args:
        var_name: Name of environment variable
        default: Default integer value if not set
    
    Returns:
        Integer value from env var or default
    """
    value = os.environ.get(var_name)
    if value is None:
        return default
    
    try:
        return int(value)
    except (ValueError, TypeError):
        print(f"[WARN] Could not parse {var_name}='{value}' as int, using default: {default}")
        return default


def _get_env_string(var_name, default):
    """Get environment variable as string.
    
    Args:
        var_name: Name of environment variable
        default: Default string value if not set
    
    Returns:
        String value from env var or default
    """
    value = os.environ.get(var_name)
    return value if value is not None else default


def _get_env_list(var_name, default):
    """Parse environment variable as comma-separated list.
    
    Args:
        var_name: Name of environment variable
        default: Default list if not set
    
    Returns:
        List of strings from comma-separated env var or default
    """
    value = os.environ.get(var_name)
    if value is None:
        return default
    
    # Split by comma and strip whitespace
    return [item.strip() for item in value.split(',') if item.strip()]


def to_yaml_string(data, indent=0):
    """Convert Python dict to clean YAML string format.
    
    Args:
        data: Dictionary to convert
        indent: Current indentation level (0-based spaces)
    
    Returns:
        String in YAML format with lowercase booleans and no quotes
    """
    lines = []
    indent_str = "  " * indent
    next_indent_str = "  " * (indent + 1)
    
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, dict):
                # Nested dictionary
                lines.append(f"{indent_str}{key}:")
                lines.append(to_yaml_string(value, indent + 1))
            elif isinstance(value, list):
                # List items
                lines.append(f"{indent_str}{key}:")
                for item in value:
                    if isinstance(item, dict):
                        # Complex list item
                        lines.append(f"{next_indent_str}-")
                        lines.append(to_yaml_string(item, indent + 2))
                    else:
                        # Simple list item
                        formatted_item = _format_yaml_value(item)
                        lines.append(f"{next_indent_str}- {formatted_item}")
            elif isinstance(value, bool):
                # Boolean values (lowercase)
                formatted_value = "true" if value else "false"
                lines.append(f"{indent_str}{key}: {formatted_value}")
            elif isinstance(value, (int, float)):
                # Numeric values
                lines.append(f"{indent_str}{key}: {value}")
            else:
                # String values
                formatted_value = _format_yaml_value(value)
                lines.append(f"{indent_str}{key}: {formatted_value}")
    
    return "\n".join(lines)


def _format_yaml_value(value):
    """Format a value for YAML output.
    
    Args:
        value: Value to format
    
    Returns:
        Formatted string suitable for YAML
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, str):
        # Quote strings that need it (contain special chars, spaces, etc)
        if any(c in value for c in ['"', "'", ':', '#', '{', '}', '[', ']', ',', '&', '*', '?', '|', '-', '!', '%', '@', '`']) or ' ' in value:
            # Escape and quote
            value = value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{value}"'
        else:
            return value
    else:
        return str(value)


class KubeletHardener:
    """Harden kubelet config with CIS-compliant settings."""
    
    def __init__(self, config_path="/var/lib/kubelet/config.yaml"):
        self.config_path = Path(config_path)
        self.backup_dir = Path("/var/backups/cis-kubelet")
        self.config = {}
        self.preserved_values = {}
        
        # Load CIS settings from environment variables or use hardcoded defaults
        self.cis_settings = self._load_cis_settings()
        
        # Default secure configuration (CIS-hardened) - will be overridden by env vars
        self.default_config = {
            "apiVersion": "kubelet.config.k8s.io/v1beta1",
            "kind": "KubeletConfiguration",
            "authentication": {
                "anonymous": {
                    "enabled": self.cis_settings["anonymous_auth"]
                },
                "webhook": {
                    "enabled": self.cis_settings["webhook_auth"],
                    "cacheTTL": "2m0s"
                },
                "x509": {
                    "clientCAFile": self.cis_settings["client_ca_file"]
                }
            },
            "authorization": {
                "mode": self.cis_settings["authorization_mode"],
                "webhook": {
                    "cacheAuthorizedTTL": "5m0s",
                    "cacheUnauthorizedTTL": "30s"
                }
            },
            "readOnlyPort": self.cis_settings["read_only_port"],
            "streamingConnectionIdleTimeout": self.cis_settings["streaming_timeout"],
            "makeIPTablesUtilChains": self.cis_settings["make_iptables_util_chains"],
            "rotateCertificates": self.cis_settings["rotate_certificates"],
            "serverTLSBootstrap": True,
            "rotateServerCertificates": self.cis_settings["rotate_server_certificates"],
            "tlsCipherSuites": self.cis_settings["tls_cipher_suites"],
            "podPidsLimit": self.cis_settings["pod_pids_limit"],
            "seccompDefault": self.cis_settings["seccomp_default"],
            "protectKernelDefaults": True,
            "cgroupDriver": "systemd",
            "clusterDNS": ["10.96.0.10"],
            "clusterDomain": "cluster.local"
        }
    
    def _load_cis_settings(self):
        """Load CIS settings from environment variables with defaults.
        
        Environment variables:
        - CONFIG_ANONYMOUS_AUTH: "true"/"false"
        - CONFIG_WEBHOOK_AUTH: "true"/"false"
        - CONFIG_CLIENT_CA_FILE: path to CA file
        - CONFIG_AUTHORIZATION_MODE: "Webhook"
        - CONFIG_READ_ONLY_PORT: integer
        - CONFIG_STREAMING_TIMEOUT: duration string
        - CONFIG_MAKE_IPTABLES_UTIL_CHAINS: "true"/"false"
        - CONFIG_ROTATE_CERTIFICATES: "true"/"false"
        - CONFIG_ROTATE_SERVER_CERTIFICATES: "true"/"false"
        - CONFIG_TLS_CIPHER_SUITES: comma-separated cipher suite list
        - CONFIG_POD_PIDS_LIMIT: integer
        - CONFIG_SECCOMP_DEFAULT: "true"/"false"
        
        Returns:
            Dictionary with CIS settings
        """
        settings = {
            "anonymous_auth": _get_env_bool("CONFIG_ANONYMOUS_AUTH", False),
            "webhook_auth": _get_env_bool("CONFIG_WEBHOOK_AUTH", True),
            "client_ca_file": _get_env_string(
                "CONFIG_CLIENT_CA_FILE",
                "/etc/kubernetes/pki/ca.crt"
            ),
            "authorization_mode": _get_env_string(
                "CONFIG_AUTHORIZATION_MODE",
                "Webhook"
            ),
            "read_only_port": _get_env_int("CONFIG_READ_ONLY_PORT", 0),
            "streaming_timeout": _get_env_string(
                "CONFIG_STREAMING_TIMEOUT",
                "4h0m0s"
            ),
            "make_iptables_util_chains": _get_env_bool(
                "CONFIG_MAKE_IPTABLES_UTIL_CHAINS",
                True
            ),
            "rotate_certificates": _get_env_bool("CONFIG_ROTATE_CERTIFICATES", True),
            "rotate_server_certificates": _get_env_bool(
                "CONFIG_ROTATE_SERVER_CERTIFICATES",
                True
            ),
            "tls_cipher_suites": _get_env_list(
                "CONFIG_TLS_CIPHER_SUITES",
                [
                    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
                    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
                    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
                    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
                    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
                ]
            ),
            "pod_pids_limit": _get_env_int("CONFIG_POD_PIDS_LIMIT", -1),
            "seccomp_default": _get_env_bool("CONFIG_SECCOMP_DEFAULT", True),
        }
        
        # Log which settings came from environment variables
        print("[INFO] Loading CIS settings from environment variables...")
        if os.environ.get("CONFIG_ANONYMOUS_AUTH"):
            print(f"  CONFIG_ANONYMOUS_AUTH={os.environ.get('CONFIG_ANONYMOUS_AUTH')}")
        if os.environ.get("CONFIG_WEBHOOK_AUTH"):
            print(f"  CONFIG_WEBHOOK_AUTH={os.environ.get('CONFIG_WEBHOOK_AUTH')}")
        if os.environ.get("CONFIG_CLIENT_CA_FILE"):
            print(f"  CONFIG_CLIENT_CA_FILE={os.environ.get('CONFIG_CLIENT_CA_FILE')}")
        if os.environ.get("CONFIG_AUTHORIZATION_MODE"):
            print(f"  CONFIG_AUTHORIZATION_MODE={os.environ.get('CONFIG_AUTHORIZATION_MODE')}")
        if os.environ.get("CONFIG_READ_ONLY_PORT"):
            print(f"  CONFIG_READ_ONLY_PORT={os.environ.get('CONFIG_READ_ONLY_PORT')}")
        if os.environ.get("CONFIG_STREAMING_TIMEOUT"):
            print(f"  CONFIG_STREAMING_TIMEOUT={os.environ.get('CONFIG_STREAMING_TIMEOUT')}")
        if os.environ.get("CONFIG_MAKE_IPTABLES_UTIL_CHAINS"):
            print(f"  CONFIG_MAKE_IPTABLES_UTIL_CHAINS={os.environ.get('CONFIG_MAKE_IPTABLES_UTIL_CHAINS')}")
        if os.environ.get("CONFIG_ROTATE_CERTIFICATES"):
            print(f"  CONFIG_ROTATE_CERTIFICATES={os.environ.get('CONFIG_ROTATE_CERTIFICATES')}")
        if os.environ.get("CONFIG_ROTATE_SERVER_CERTIFICATES"):
            print(f"  CONFIG_ROTATE_SERVER_CERTIFICATES={os.environ.get('CONFIG_ROTATE_SERVER_CERTIFICATES')}")
        if os.environ.get("CONFIG_TLS_CIPHER_SUITES"):
            print(f"  CONFIG_TLS_CIPHER_SUITES={os.environ.get('CONFIG_TLS_CIPHER_SUITES')}")
        if os.environ.get("CONFIG_POD_PIDS_LIMIT"):
            print(f"  CONFIG_POD_PIDS_LIMIT={os.environ.get('CONFIG_POD_PIDS_LIMIT')}")
        if os.environ.get("CONFIG_SECCOMP_DEFAULT"):
            print(f"  CONFIG_SECCOMP_DEFAULT={os.environ.get('CONFIG_SECCOMP_DEFAULT')}")
        
        return settings
    
    def load_config(self):
        """Load only critical values from existing config.
        
        Strategy: Extract only clusterDNS, clusterDomain, cgroupDriver, address
        and discard everything else. Fresh config will be constructed from defaults.
        """
        self.preserved_values = {}
        
        if not self.config_path.exists():
            print(f"[INFO] Config file not found at {self.config_path}")
            print("[INFO] Will create new config from CIS defaults")
            return True
        
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            loaded_config = None
            
            # Try JSON first (valid JSON is valid YAML)
            try:
                loaded_config = json.loads(content)
                print("[PASS] Loaded existing config as JSON")
            except json.JSONDecodeError:
                pass
            
            # Try PyYAML if available
            if loaded_config is None:
                try:
                    import yaml
                    loaded_config = yaml.safe_load(content)
                    if loaded_config is not None:
                        print("[PASS] Loaded existing config with PyYAML")
                except ImportError:
                    pass
            
            # Fallback: Simple key=value parsing for broken configs
            if loaded_config is None:
                print("[WARN] Could not parse as JSON/YAML, using smart parsing")
                loaded_config = self._parse_broken_config(content)
            
            # Extract ONLY critical cluster-specific values
            if isinstance(loaded_config, dict):
                self._extract_critical_values(loaded_config)
                print("[INFO] Extracted critical cluster values")
            
            return True
        
        except Exception as e:
            print(f"[WARN] Failed to load config: {e}")
            print("[INFO] Will create new config from CIS defaults")
            return True
    
    def _extract_critical_values(self, loaded_config):
        """Extract ONLY critical cluster-specific values from loaded config.
        
        Extracts:
        - clusterDNS: DNS servers for pods
        - clusterDomain: DNS domain for cluster
        - cgroupDriver: systemd or cgroupfs
        - address: bind address for kubelet API
        """
        # clusterDNS
        if isinstance(loaded_config.get("clusterDNS"), list):
            self.preserved_values["clusterDNS"] = loaded_config["clusterDNS"]
            print(f"  ✓ clusterDNS: {loaded_config['clusterDNS']}")
        
        # clusterDomain
        if isinstance(loaded_config.get("clusterDomain"), str):
            self.preserved_values["clusterDomain"] = loaded_config["clusterDomain"]
            print(f"  ✓ clusterDomain: {loaded_config['clusterDomain']}")
        
        # cgroupDriver
        if isinstance(loaded_config.get("cgroupDriver"), str):
            self.preserved_values["cgroupDriver"] = loaded_config["cgroupDriver"]
            print(f"  ✓ cgroupDriver: {loaded_config['cgroupDriver']}")
        
        # address (bind address for kubelet API)
        if isinstance(loaded_config.get("address"), str):
            self.preserved_values["address"] = loaded_config["address"]
            print(f"  ✓ address: {loaded_config['address']}")
    
    def _parse_broken_config(self, content):
        """Parse broken config using simple key=value extraction."""
        config = {}
        lines = content.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Simple extraction for top-level keys
            if ':' in line:
                key, val = line.split(':', 1)
                key = key.strip()
                val = val.strip().strip('"\'')
                
                # Try to convert to appropriate type
                if val.lower() == 'true':
                    config[key] = True
                elif val.lower() == 'false':
                    config[key] = False
                elif val.isdigit() or (val.startswith('-') and val[1:].isdigit()):
                    config[key] = int(val)
                else:
                    config[key] = val
        
        return config if config else {}
    
    def create_backup(self):
        """Create timestamped backup of original config."""
        if not self.config_path.exists():
            print("[INFO] No existing config to backup")
            return None
        
        try:
            # Create backup directory if needed
            self.backup_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"[WARN] Could not create backup directory: {e}")
            # Fall back to backup in same directory
            self.backup_dir = self.config_path.parent
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"config.yaml.{timestamp}.bak"
        
        try:
            copy2(self.config_path, backup_file)
            print(f"[INFO] Backup created: {backup_file}")
            return backup_file
        except Exception as e:
            print(f"[ERROR] Failed to create backup: {e}")
            return None
    
    def harden_config(self):
        """Apply CIS hardening by constructing fresh config from defaults.
        
        Strategy: Don't modify loaded config in-place. Instead:
        1. Start with fresh SAFE_DEFAULTS copy
        2. Inject preserved cluster-specific values
        3. This ensures config is clean and CIS-compliant
        """
        print("[INFO] Constructing fresh config from CIS-compliant defaults...")
        
        # Start with clean defaults (already loaded from env vars in __init__)
        self.config = self._get_safe_defaults()
        
        # Inject preserved values
        if self.preserved_values:
            print("[INFO] Injecting preserved cluster values...")
            
            if "clusterDNS" in self.preserved_values:
                self.config["clusterDNS"] = self.preserved_values["clusterDNS"]
                print(f"  ✓ clusterDNS: {self.preserved_values['clusterDNS']}")
            
            if "clusterDomain" in self.preserved_values:
                self.config["clusterDomain"] = self.preserved_values["clusterDomain"]
                print(f"  ✓ clusterDomain: {self.preserved_values['clusterDomain']}")
            
            if "cgroupDriver" in self.preserved_values:
                self.config["cgroupDriver"] = self.preserved_values["cgroupDriver"]
                print(f"  ✓ cgroupDriver: {self.preserved_values['cgroupDriver']}")
            
            if "address" in self.preserved_values:
                self.config["address"] = self.preserved_values["address"]
                print(f"  ✓ address: {self.preserved_values['address']}")
        
        print("[PASS] Fresh config constructed with CIS defaults + preserved values")
        return True
    
    def _get_safe_defaults(self):
        """Return a fresh copy of CIS-compliant safe defaults using loaded settings."""
        return {
            "apiVersion": "kubelet.config.k8s.io/v1beta1",
            "kind": "KubeletConfiguration",
            "authentication": {
                "anonymous": {
                    "enabled": self.cis_settings["anonymous_auth"]
                },
                "webhook": {
                    "enabled": self.cis_settings["webhook_auth"],
                    "cacheTTL": "2m0s"
                },
                "x509": {
                    "clientCAFile": self.cis_settings["client_ca_file"]
                }
            },
            "authorization": {
                "mode": self.cis_settings["authorization_mode"],
                "webhook": {
                    "cacheAuthorizedTTL": "5m0s",
                    "cacheUnauthorizedTTL": "30s"
                }
            },
            "readOnlyPort": self.cis_settings["read_only_port"],
            "streamingConnectionIdleTimeout": self.cis_settings["streaming_timeout"],
            "makeIPTablesUtilChains": self.cis_settings["make_iptables_util_chains"],
            "rotateCertificates": self.cis_settings["rotate_certificates"],
            "serverTLSBootstrap": True,
            "rotateServerCertificates": self.cis_settings["rotate_server_certificates"],
            "tlsCipherSuites": self.cis_settings["tls_cipher_suites"],
            "podPidsLimit": self.cis_settings["pod_pids_limit"],
            "seccompDefault": self.cis_settings["seccomp_default"],
            "protectKernelDefaults": True,
            "cgroupDriver": "systemd",
            "clusterDNS": ["10.96.0.10"],
            "clusterDomain": "cluster.local"
        }
    
    def write_config(self):
        """Write hardened config back to file in clean YAML format."""
        try:
            # Ensure config is a dict
            if not isinstance(self.config, dict):
                print("[ERROR] Config is not a dictionary")
                return False
            
            print(f"[INFO] Writing config to {self.config_path}")
            
            # Write as clean YAML format (not JSON)
            # This ensures grep-friendly format for audit scripts
            yaml_content = to_yaml_string(self.config)
            
            with open(self.config_path, 'w') as f:
                f.write(yaml_content)
                f.write('\n')  # Add trailing newline
            
            # Verify write
            if not self.config_path.exists() or self.config_path.stat().st_size == 0:
                print("[ERROR] Config file write failed or empty")
                return False
            
            print("[PASS] Config written successfully")
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to write config: {e}")
            return False
    
    def verify_config(self):
        """Verify config is valid YAML/can be parsed."""
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            # Try to parse as YAML first
            try:
                import yaml
                config = yaml.safe_load(content)
                print("[PASS] Config structure verified (parsed as YAML)")
            except ImportError:
                # Fall back to checking structure manually
                # Verify it contains expected keys
                if "authentication" not in content or "authorization" not in content:
                    print("[ERROR] Missing critical keys in config")
                    return False
                print("[PASS] Config structure verified (manual check)")
            
            # Verify key settings are present
            if "enabled: false" not in content and "enabled: true" not in content:
                print("[WARN] Could not verify boolean settings in output")
            
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to verify config: {e}")
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
            
            # Wait for kubelet to become active (up to 15 seconds)
            import time
            max_attempts = 15
            for attempt in range(max_attempts):
                time.sleep(1)
                
                result = subprocess.run(
                    ["systemctl", "is-active", "kubelet"],
                    capture_output=True,
                    timeout=5,
                    text=True
                )
                
                if result.returncode == 0 and result.stdout.strip() == "active":
                    print("[PASS] kubelet is running")
                    return True
                
                if attempt < max_attempts - 1:
                    print(f"[INFO] Waiting for kubelet to start... ({attempt + 1}/{max_attempts})")
            
            # Final check
            result = subprocess.run(
                ["systemctl", "status", "kubelet"],
                capture_output=True,
                timeout=5,
                text=True
            )
            print(f"[ERROR] kubelet not running after {max_attempts} seconds")
            print(f"[DEBUG] Status: {result.stdout}")
            return False
        
        except subprocess.TimeoutExpired:
            print("[ERROR] systemctl command timed out")
            return False
        except Exception as e:
            print(f"[ERROR] Failed to restart kubelet: {e}")
            return False
    
    def harden(self):
        """Execute full hardening procedure."""
        print("=" * 80)
        print("KUBELET CONFIGURATION HARDENER")
        print("=" * 80)
        print(f"[INFO] Target: {self.config_path}")
        print()
        
        # Step 1: Load config
        print("[STEP 1] Loading kubelet configuration...")
        if not self.load_config():
            print("[FAIL] Failed to load config")
            return False
        print()
        
        # Step 2: Backup
        print("[STEP 2] Creating backup...")
        self.create_backup()
        print()
        
        # Step 3: Harden
        print("[STEP 3] Applying CIS hardening settings...")
        if not self.harden_config():
            print("[FAIL] Failed to harden config")
            return False
        print()
        
        # Step 4: Write
        print("[STEP 4] Writing hardened config...")
        if not self.write_config():
            print("[FAIL] Failed to write config")
            return False
        print()
        
        # Step 5: Verify
        print("[STEP 5] Verifying config...")
        if not self.verify_config():
            print("[FAIL] Config verification failed")
            return False
        print()
        
        # Step 6: Restart
        print("[STEP 6] Restarting kubelet service...")
        if not self.restart_kubelet():
            print("[FAIL] kubelet restart failed")
            return False
        print()
        
        print("=" * 80)
        print("[PASS] Kubelet hardening complete!")
        print("=" * 80)
        return True


def main():
    """Main entry point."""
    # Check root
    if os.geteuid() != 0:
        print("[ERROR] This script must be run as root")
        sys.exit(1)
    
    # Allow custom config path
    config_path = os.environ.get('KUBELET_CONFIG', '/var/lib/kubelet/config.yaml')
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    hardener = KubeletHardener(config_path)
    
    if hardener.harden():
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()


def to_yaml_string(data, indent=0):
    """Convert Python dict to clean YAML string format.
    
    Args:
        data: Dictionary to convert
        indent: Current indentation level (0-based spaces)
    
    Returns:
        String in YAML format with lowercase booleans and no quotes
    """
    lines = []
    indent_str = "  " * indent
    next_indent_str = "  " * (indent + 1)
    
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, dict):
                # Nested dictionary
                lines.append(f"{indent_str}{key}:")
                lines.append(to_yaml_string(value, indent + 1))
            elif isinstance(value, list):
                # List items
                lines.append(f"{indent_str}{key}:")
                for item in value:
                    if isinstance(item, dict):
                        # Complex list item
                        lines.append(f"{next_indent_str}-")
                        lines.append(to_yaml_string(item, indent + 2))
                    else:
                        # Simple list item
                        formatted_item = _format_yaml_value(item)
                        lines.append(f"{next_indent_str}- {formatted_item}")
            elif isinstance(value, bool):
                # Boolean values (lowercase)
                formatted_value = "true" if value else "false"
                lines.append(f"{indent_str}{key}: {formatted_value}")
            elif isinstance(value, (int, float)):
                # Numeric values
                lines.append(f"{indent_str}{key}: {value}")
            else:
                # String values
                formatted_value = _format_yaml_value(value)
                lines.append(f"{indent_str}{key}: {formatted_value}")
    
    return "\n".join(lines)


def _format_yaml_value(value):
    """Format a value for YAML output.
    
    Args:
        value: Value to format
    
    Returns:
        Formatted string suitable for YAML
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, str):
        # Quote strings that need it (contain special chars, spaces, etc)
        if any(c in value for c in ['"', "'", ':', '#', '{', '}', '[', ']', ',', '&', '*', '?', '|', '-', '!', '%', '@', '`']) or ' ' in value:
            # Escape and quote
            value = value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{value}"'
        else:
            return value
    else:
        return str(value)


class KubeletHardener:
    """Harden kubelet config with CIS-compliant settings."""
    
    def __init__(self, config_path="/var/lib/kubelet/config.yaml"):
        self.config_path = Path(config_path)
        self.backup_dir = Path("/var/backups/cis-kubelet")
        self.config = {}
        self.preserved_values = {}
        
        # Default secure configuration (CIS-hardened)
        self.default_config = {
            "apiVersion": "kubelet.config.k8s.io/v1beta1",
            "kind": "KubeletConfiguration",
            "authentication": {
                "anonymous": {
                    "enabled": False
                },
                "webhook": {
                    "enabled": True,
                    "cacheTTL": "2m0s"
                },
                "x509": {
                    "clientCAFile": "/etc/kubernetes/pki/ca.crt"
                }
            },
            "authorization": {
                "mode": "Webhook",
                "webhook": {
                    "cacheAuthorizedTTL": "5m0s",
                    "cacheUnauthorizedTTL": "30s"
                }
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
            "protectKernelDefaults": True,
            "cgroupDriver": "systemd",
            "clusterDNS": ["10.96.0.10"],
            "clusterDomain": "cluster.local"
        }
    
    def load_config(self):
        """Load only critical values from existing config.
        
        Strategy: Extract only clusterDNS, clusterDomain, cgroupDriver, address
        and discard everything else. Fresh config will be constructed from defaults.
        """
        self.preserved_values = {}
        
        if not self.config_path.exists():
            print(f"[INFO] Config file not found at {self.config_path}")
            print("[INFO] Will create new config from CIS defaults")
            return True
        
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            loaded_config = None
            
            # Try JSON first (valid JSON is valid YAML)
            try:
                loaded_config = json.loads(content)
                print("[PASS] Loaded existing config as JSON")
            except json.JSONDecodeError:
                pass
            
            # Try PyYAML if available
            if loaded_config is None:
                try:
                    import yaml
                    loaded_config = yaml.safe_load(content)
                    if loaded_config is not None:
                        print("[PASS] Loaded existing config with PyYAML")
                except ImportError:
                    pass
            
            # Fallback: Simple key=value parsing for broken configs
            if loaded_config is None:
                print("[WARN] Could not parse as JSON/YAML, using smart parsing")
                loaded_config = self._parse_broken_config(content)
            
            # Extract ONLY critical cluster-specific values
            if isinstance(loaded_config, dict):
                self._extract_critical_values(loaded_config)
                print("[INFO] Extracted critical cluster values")
            
            return True
        
        except Exception as e:
            print(f"[WARN] Failed to load config: {e}")
            print("[INFO] Will create new config from CIS defaults")
            return True
    
    def _extract_critical_values(self, loaded_config):
        """Extract ONLY critical cluster-specific values from loaded config.
        
        Extracts:
        - clusterDNS: DNS servers for pods
        - clusterDomain: DNS domain for cluster
        - cgroupDriver: systemd or cgroupfs
        - address: bind address for kubelet API
        """
        # clusterDNS
        if isinstance(loaded_config.get("clusterDNS"), list):
            self.preserved_values["clusterDNS"] = loaded_config["clusterDNS"]
            print(f"  ✓ clusterDNS: {loaded_config['clusterDNS']}")
        
        # clusterDomain
        if isinstance(loaded_config.get("clusterDomain"), str):
            self.preserved_values["clusterDomain"] = loaded_config["clusterDomain"]
            print(f"  ✓ clusterDomain: {loaded_config['clusterDomain']}")
        
        # cgroupDriver
        if isinstance(loaded_config.get("cgroupDriver"), str):
            self.preserved_values["cgroupDriver"] = loaded_config["cgroupDriver"]
            print(f"  ✓ cgroupDriver: {loaded_config['cgroupDriver']}")
        
        # address (bind address for kubelet API)
        if isinstance(loaded_config.get("address"), str):
            self.preserved_values["address"] = loaded_config["address"]
            print(f"  ✓ address: {loaded_config['address']}")
    
    def _parse_broken_config(self, content):
        """Parse broken config using simple key=value extraction."""
        config = {}
        lines = content.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Simple extraction for top-level keys
            if ':' in line:
                key, val = line.split(':', 1)
                key = key.strip()
                val = val.strip().strip('"\'')
                
                # Try to convert to appropriate type
                if val.lower() == 'true':
                    config[key] = True
                elif val.lower() == 'false':
                    config[key] = False
                elif val.isdigit() or (val.startswith('-') and val[1:].isdigit()):
                    config[key] = int(val)
                else:
                    config[key] = val
        
        return config if config else {}
    
    def create_backup(self):
        """Create timestamped backup of original config."""
        if not self.config_path.exists():
            print("[INFO] No existing config to backup")
            return None
        
        try:
            # Create backup directory if needed
            self.backup_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"[WARN] Could not create backup directory: {e}")
            # Fall back to backup in same directory
            self.backup_dir = self.config_path.parent
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"config.yaml.{timestamp}.bak"
        
        try:
            copy2(self.config_path, backup_file)
            print(f"[INFO] Backup created: {backup_file}")
            return backup_file
        except Exception as e:
            print(f"[ERROR] Failed to create backup: {e}")
            return None
    
    def harden_config(self):
        """Apply CIS hardening by constructing fresh config from defaults.
        
        Strategy: Don't modify loaded config in-place. Instead:
        1. Start with fresh SAFE_DEFAULTS copy
        2. Inject preserved cluster-specific values
        3. This ensures config is clean and CIS-compliant
        """
        print("[INFO] Constructing fresh config from CIS-compliant defaults...")
        
        # Start with clean defaults
        self.config = self._get_safe_defaults()
        
        # Inject preserved values
        if self.preserved_values:
            print("[INFO] Injecting preserved cluster values...")
            
            if "clusterDNS" in self.preserved_values:
                self.config["clusterDNS"] = self.preserved_values["clusterDNS"]
                print(f"  ✓ clusterDNS: {self.preserved_values['clusterDNS']}")
            
            if "clusterDomain" in self.preserved_values:
                self.config["clusterDomain"] = self.preserved_values["clusterDomain"]
                print(f"  ✓ clusterDomain: {self.preserved_values['clusterDomain']}")
            
            if "cgroupDriver" in self.preserved_values:
                self.config["cgroupDriver"] = self.preserved_values["cgroupDriver"]
                print(f"  ✓ cgroupDriver: {self.preserved_values['cgroupDriver']}")
            
            if "address" in self.preserved_values:
                self.config["address"] = self.preserved_values["address"]
                print(f"  ✓ address: {self.preserved_values['address']}")
        
        print("[PASS] Fresh config constructed with CIS defaults + preserved values")
        return True
    
    def _get_safe_defaults(self):
        """Return a fresh copy of CIS-compliant safe defaults."""
        return {
            "apiVersion": "kubelet.config.k8s.io/v1beta1",
            "kind": "KubeletConfiguration",
            "authentication": {
                "anonymous": {
                    "enabled": False
                },
                "webhook": {
                    "enabled": True,
                    "cacheTTL": "2m0s"
                },
                "x509": {
                    "clientCAFile": "/etc/kubernetes/pki/ca.crt"
                }
            },
            "authorization": {
                "mode": "Webhook",
                "webhook": {
                    "cacheAuthorizedTTL": "5m0s",
                    "cacheUnauthorizedTTL": "30s"
                }
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
            "protectKernelDefaults": True,
            "cgroupDriver": "systemd",
            "clusterDNS": ["10.96.0.10"],
            "clusterDomain": "cluster.local"
        }
    
    def write_config(self):
        """Write hardened config back to file in clean YAML format."""
        try:
            # Ensure config is a dict
            if not isinstance(self.config, dict):
                print("[ERROR] Config is not a dictionary")
                return False
            
            print(f"[INFO] Writing config to {self.config_path}")
            
            # Write as clean YAML format (not JSON)
            # This ensures grep-friendly format for audit scripts
            yaml_content = to_yaml_string(self.config)
            
            with open(self.config_path, 'w') as f:
                f.write(yaml_content)
                f.write('\n')  # Add trailing newline
            
            # Verify write
            if not self.config_path.exists() or self.config_path.stat().st_size == 0:
                print("[ERROR] Config file write failed or empty")
                return False
            
            print("[PASS] Config written successfully")
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to write config: {e}")
            return False
    
    def verify_config(self):
        """Verify config is valid YAML/can be parsed."""
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            # Try to parse as YAML first
            try:
                import yaml
                config = yaml.safe_load(content)
                print("[PASS] Config structure verified (parsed as YAML)")
            except ImportError:
                # Fall back to checking structure manually
                # Verify it contains expected keys
                if "authentication" not in content or "authorization" not in content:
                    print("[ERROR] Missing critical keys in config")
                    return False
                print("[PASS] Config structure verified (manual check)")
            
            # Verify key settings are present
            if "enabled: false" not in content and "enabled: true" not in content:
                print("[WARN] Could not verify boolean settings in output")
            
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to verify config: {e}")
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
            
            # Wait for kubelet to become active (up to 15 seconds)
            import time
            max_attempts = 15
            for attempt in range(max_attempts):
                time.sleep(1)
                
                result = subprocess.run(
                    ["systemctl", "is-active", "kubelet"],
                    capture_output=True,
                    timeout=5,
                    text=True
                )
                
                if result.returncode == 0 and result.stdout.strip() == "active":
                    print("[PASS] kubelet is running")
                    return True
                
                if attempt < max_attempts - 1:
                    print(f"[INFO] Waiting for kubelet to start... ({attempt + 1}/{max_attempts})")
            
            # Final check
            result = subprocess.run(
                ["systemctl", "status", "kubelet"],
                capture_output=True,
                timeout=5,
                text=True
            )
            print(f"[ERROR] kubelet not running after {max_attempts} seconds")
            print(f"[DEBUG] Status: {result.stdout}")
            return False
        
        except subprocess.TimeoutExpired:
            print("[ERROR] systemctl command timed out")
            return False
        except Exception as e:
            print(f"[ERROR] Failed to restart kubelet: {e}")
            return False
    
    def harden(self):
        """Execute full hardening procedure."""
        print("=" * 80)
        print("KUBELET CONFIGURATION HARDENER")
        print("=" * 80)
        print(f"[INFO] Target: {self.config_path}")
        print()
        
        # Step 1: Load config
        print("[STEP 1] Loading kubelet configuration...")
        if not self.load_config():
            print("[FAIL] Failed to load config")
            return False
        print()
        
        # Step 2: Backup
        print("[STEP 2] Creating backup...")
        self.create_backup()
        print()
        
        # Step 3: Harden
        print("[STEP 3] Applying CIS hardening settings...")
        if not self.harden_config():
            print("[FAIL] Failed to harden config")
            return False
        print()
        
        # Step 4: Write
        print("[STEP 4] Writing hardened config...")
        if not self.write_config():
            print("[FAIL] Failed to write config")
            return False
        print()
        
        # Step 5: Verify
        print("[STEP 5] Verifying config...")
        if not self.verify_config():
            print("[FAIL] Config verification failed")
            return False
        print()
        
        # Step 6: Restart
        print("[STEP 6] Restarting kubelet service...")
        if not self.restart_kubelet():
            print("[FAIL] kubelet restart failed")
            return False
        print()
        
        print("=" * 80)
        print("[PASS] Kubelet hardening complete!")
        print("=" * 80)
        return True


def main():
    """Main entry point."""
    # Check root
    if os.geteuid() != 0:
        print("[ERROR] This script must be run as root")
        sys.exit(1)
    
    # Allow custom config path
    config_path = os.environ.get('KUBELET_CONFIG', '/var/lib/kubelet/config.yaml')
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    hardener = KubeletHardener(config_path)
    
    if hardener.harden():
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
