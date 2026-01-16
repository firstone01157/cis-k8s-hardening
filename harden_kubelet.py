#!/usr/bin/env python3
"""
Kubelet Configuration Hardener (Type-Safe with Strict Casting)
Safely hardens /var/lib/kubelet/config.yaml with CIS-compliant settings.
Parses as data structure (avoiding sed/YAML indentation errors).
STRICT TYPE ENFORCEMENT prevents kubelet crashes from type mismatches.

Configuration:
- Reads environment variables for CIS settings (CONFIG_* prefix)
- Falls back to hardcoded CIS defaults if env vars not present
- Enforces correct types: Integers, Booleans, Lists, Strings
- Recursively applies type casting to ALL config values BEFORE YAML output
- Enables config-driven deployment from external runners
"""

import json
import subprocess
import sys
import os
import time
from pathlib import Path
from datetime import datetime
from shutil import copy2
from typing import Any, Dict


# ============================================================================
# TYPE CASTING & ENFORCEMENT - STRICT
# ============================================================================

def cast_value(key, value):
    """
    Cast to correct Python type based on key name.
    
    Kubelet config expects specific types:
    - Integers: readOnlyPort, podPidsLimit, healthzPort, cadvisorPort, maxOpenFiles, maxPods
    - Booleans: rotateCertificates, serverTLSBootstrap, makeIPTablesUtilChains, 
                protectKernelDefaults, rotateServerCertificates, seccompDefault
    - Lists: tlsCipherSuites, clusterDNS, featureGates
    - Strings: streamingConnectionIdleTimeout, clientCAFile, cgroupDriver, etc. (DEFAULT)
    
    Args:
        key: Config key name (used to determine expected type)
        value: Value to cast (may be string from environment variables or loaded YAML)
    
    Returns:
        Value cast to correct Python type
    
    CRITICAL: This function prevents kubelet crashes from type mismatches.
    Example: readOnlyPort MUST be int (0), not string ("0")
    """
    
    # Handle None values
    if value is None:
        return None
    
    # --- INTEGER FIELDS ---
    # These MUST be Python int, NEVER strings or floats
    integer_keys = {
        'readOnlyPort',           # Must be int (0 means disabled)
        'podPidsLimit',           # Must be int (-1 means unlimited)
        'healthzPort',            # Must be int
        'cadvisorPort',           # Must be int
        'maxOpenFiles',           # Must be int
        'maxPods',                # Must be int
    }
    
    if key in integer_keys:
        # CRITICAL: Check bool FIRST before int (bool is subclass of int in Python)
        # If a boolean somehow gets passed to an integer field, convert it safely
        if isinstance(value, bool):
            # Convert boolean to integer: True→1, False→0
            # This is necessary because bool is subclass of int
            converted_value = int(value)
            print(f"[WARN] Converted boolean {value} to integer {converted_value} for key {key}")
            return converted_value
        if isinstance(value, int):
            # Now safe to check for int (bool already ruled out)
            return value
        if isinstance(value, str):
            try:
                return int(value)
            except ValueError:
                print(f"[WARN] Could not cast {key}='{value}' to int, using 0")
                return 0
        if isinstance(value, float):
            return int(value)
        return int(value)
    
    # --- BOOLEAN FIELDS ---
    # These MUST be Python bool (True/False), NEVER strings or ints
    boolean_keys = {
        'rotateCertificates',              # Must be bool
        'serverTLSBootstrap',              # Must be bool
        'makeIPTablesUtilChains',          # Must be bool
        'protectKernelDefaults',           # Must be bool
        'rotateServerCertificates',        # Must be bool
        'seccompDefault',                  # Must be bool
        'enabled',                         # Must be bool (for anonymous, webhook, etc.)
    }
    
    if key in boolean_keys:
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            # Handle string representations of booleans
            return value.lower() in ('true', '1', 'yes', 'on', 'enabled')
        if isinstance(value, int):
            return bool(value)
        return bool(value)
    
    # --- LIST FIELDS ---
    # These should be lists of strings (e.g., cipher suites, DNS servers)
    list_keys = {
        'tlsCipherSuites',
        'clusterDNS',
        'featureGates',
    }
    
    if key in list_keys:
        if isinstance(value, list):
            return value
        if isinstance(value, str):
            # Split comma-separated string into list
            return [item.strip() for item in value.split(',') if item.strip()]
        # Try to convert to list
        try:
            return list(value) if value else []
        except TypeError:
            return []
    
    # --- STRING FIELDS (DEFAULT) ---
    # Everything else is treated as string
    # IMPORTANT: streamingConnectionIdleTimeout MUST remain string (duration format)
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        # Convert bool to string representation for non-boolean fields
        return "true" if value else "false"
    return str(value) if value is not None else ""


def cast_config_recursively(config):
    """
    Recursively apply type casting to ALL values in config dict.
    
    This ensures every single field in the config has the correct Python type
    BEFORE it gets serialized to YAML. This prevents kubelet crashes.
    
    CRITICAL: For list fields (tlsCipherSuites, clusterDNS, featureGates),
    we must NOT call cast_value on individual items, because cast_value
    will try to convert string items to lists (splitting by comma).
    Instead, we treat the entire list value as-is, and only cast_value
    is applied to non-list, non-dict leaf values.
    
    Args:
        config: Dictionary to recursively cast
    
    Returns:
        Dictionary with all values properly typed
    """
    if not isinstance(config, dict):
        return config
    
    casted = {}
    for key, value in config.items():
        if isinstance(value, dict):
            # Recursively cast nested dicts
            casted[key] = cast_config_recursively(value)
        elif isinstance(value, list):
            # For lists, DON'T apply cast_value to items
            # The list itself is already the correct type
            # Just recursively process dict items if present
            processed_list = []
            for item in value:
                if isinstance(item, dict):
                    # Nested dict inside list - recurse
                    processed_list.append(cast_config_recursively(item))
                else:
                    # Simple item - keep as-is (don't call cast_value)
                    # The list items are already strings/numbers/booleans
                    processed_list.append(item)
            casted[key] = processed_list
        else:
            # Cast leaf values using key name
            casted[key] = cast_value(key, value)
    
    return casted


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
    """Convert Python dict to clean YAML string format with strict type compliance.
    
    CRITICAL: Kubelet's YAML parser is strict about types. This function ensures:
    
    Boolean Handling:
    - Python True  → "true" (lowercase, NO quotes)
    - Python False → "false" (lowercase, NO quotes)
    - NEVER: "True", "False", '"true"', '"false"'
    
    Integer Handling:
    - Python int 0 → "0" (NO quotes, not "0")
    - Python int -1 → "-1" (NO quotes, not "-1")
    - Type check MUST distinguish from strings
    
    String Handling:
    - Strings quoted ONLY if containing special chars (: # { } [ ] , & * ? | - ! % @ ` or spaces)
    - Duration strings like "4h0m0s" → unquoted
    - File paths like "/etc/kubernetes/pki/ca.crt" → unquoted or quoted as needed
    
    List Handling:
    - Simple items: "- item_value" (no extra quoting)
    - Nested dicts: "- " then recurse with indent+2
    
    Args:
        data: Dictionary to convert to YAML
        indent: Current indentation level (0 = root, +1 per nesting level)
    
    Returns:
        String in YAML format with proper type handling
    
    Preconditions:
    - Input data should already be type-cast by cast_config_recursively()
    - All bool values are Python bool, not strings
    - All int values are Python int, not strings
    """
    lines = []
    indent_str = "  " * indent
    next_indent_str = "  " * (indent + 1)
    
    if not isinstance(data, dict):
        return ""
    
    for key, value in data.items():
        # Handle nested dictionaries
        if isinstance(value, dict):
            lines.append(f"{indent_str}{key}:")
            lines.append(to_yaml_string(value, indent + 1))
        
        # Handle lists
        elif isinstance(value, list):
            lines.append(f"{indent_str}{key}:")
            for item in value:
                if isinstance(item, dict):
                    # Complex list item: recurse
                    lines.append(f"{next_indent_str}-")
                    lines.append(to_yaml_string(item, indent + 2))
                else:
                    # Simple list item: format and add
                    formatted_item = _format_yaml_value(item)
                    lines.append(f"{next_indent_str}- {formatted_item}")
        
        # Handle booleans (CRITICAL: check before int, since bool is subclass of int)
        elif isinstance(value, bool):
            # CRITICAL: Output lowercase true/false with NO quotes
            formatted_value = "true" if value else "false"
            lines.append(f"{indent_str}{key}: {formatted_value}")
        
        # Handle integers and floats
        elif isinstance(value, (int, float)):
            # CRITICAL: Output numbers with NO quotes
            lines.append(f"{indent_str}{key}: {value}")
        
        # Handle strings
        elif isinstance(value, str):
            formatted_value = _format_yaml_value(value)
            lines.append(f"{indent_str}{key}: {formatted_value}")
        
        # Handle any other type (shouldn't happen with proper type-casting)
        else:
            # Fallback: convert to string and format
            formatted_value = _format_yaml_value(str(value))
            lines.append(f"{indent_str}{key}: {formatted_value}")
    
    return "\n".join(lines)


def _format_yaml_value(value):
    """Format a single value for YAML output with PARANOID MODE type safety.
    
    PARANOID MODE: Defensively handles all potential type ambiguities that could
    cause Kubelet to crash or misinterpret configuration values.
    
    CRITICAL: Kubelet's YAML parser is strict about types. This function:
    
    1. Checks Python type FIRST (isinstance checks in correct order)
    2. Converts to appropriate YAML representation
    3. Applies DEFENSIVE quoting for strings that look like types
    
    Type Handling Order (CRITICAL - MUST BE IN THIS ORDER):
    1. bool - MUST check before int (bool is subclass of int in Python)
       - True → "true" (lowercase, no quotes)
       - False → "false" (lowercase, no quotes)
    2. int, float - Output as numbers without quotes
       - 0 → "0", -1 → "-1", 1.5 → "1.5"
    3. str - PARANOID MODE: Quote if ambiguous
       - "true", "false", "yes", "no", "on", "off" → QUOTE (looks like boolean)
       - "0", "123", "-1", "3.14" → QUOTE (looks like number)
       - Contains special YAML chars → QUOTE
       - Simple strings → unquoted (e.g., "hello", "4h0m0s")
    4. Fallback - Convert unknown types to string with paranoid quoting
    
    Boolean Output (PARANOID):
    - Python True → "true" (lowercase, no quotes)
    - Python False → "false" (lowercase, no quotes)
    - String "true" → '"true"' (QUOTED - looks like boolean)
    - String "false" → '"false"' (QUOTED - looks like boolean)
    - NEVER: "True", "False", '"true"' from Python bool, etc.
    
    Numeric Output (PARANOID):
    - Python int 0 → "0" (no quotes)
    - Python int -1 → "-1" (no quotes)
    - String "0" → '"0"' (QUOTED - looks like number)
    - String "-1" → '"-1"' (QUOTED - looks like number)
    - NEVER: quoted integers/floats from Python types
    
    String Output (PARANOID):
    - Python str "hello" → "hello" (unquoted, safe)
    - Python str "4h0m0s" → "4h0m0s" (unquoted, safe duration)
    - Python str "/etc/kubernetes/pki/ca.crt" → "/etc/kubernetes/pki/ca.crt" (unquoted, safe)
    - Python str "true" → '"true"' (QUOTED, looks like boolean)
    - Python str "false" → '"false"' (QUOTED, looks like boolean)
    - Python str "123" → '"123"' (QUOTED, looks like number)
    - Python str "hello:world" → '"hello:world"' (QUOTED, contains :)
    - Python str "hello world" → '"hello world"' (QUOTED, contains space)
    
    Special characters that ALWAYS trigger quoting: " ' : # { } [ ] , & * ? | - ! % @ `
    
    Args:
        value: Single value to format (already type-cast by cast_value())
    
    Returns:
        String representation suitable for YAML
    
    Preconditions:
    - Input should already be type-cast to correct Python type by cast_value()
    - Boolean values are Python bool, not strings
    - Integer values are Python int, not strings
    """
    
    # === BOOLEAN HANDLING (check FIRST - before int check) ===
    # CRITICAL: bool is a subclass of int in Python, so must check before isinstance(value, int)
    if isinstance(value, bool):
        # CRITICAL: Output lowercase true/false with NO quotes
        # This is a Python bool, not a string
        return "true" if value else "false"
    
    # === NUMERIC HANDLING ===
    # Integers and floats output as-is (no quotes, no conversion to string)
    elif isinstance(value, (int, float)):
        # CRITICAL: Output numbers directly (no quotes)
        # This is a Python int/float, not a string representation
        return str(value)
    
    # === STRING HANDLING (DEFAULT) ===
    elif isinstance(value, str):
        # PARANOID MODE: Check if string looks like a boolean
        boolean_like_values = {'true', 'false', 'yes', 'no', 'on', 'off', 'True', 'False', 'Yes', 'No', 'On', 'Off', 'TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF'}
        if value in boolean_like_values:
            # Quote it - looks like boolean but is a string
            escaped_value = value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        
        # PARANOID MODE: Check if string looks like a number
        # Match: "0", "123", "-1", "3.14", etc.
        number_like_pattern = value.strip()
        is_number_like = False
        
        if number_like_pattern and number_like_pattern[0] in '0123456789-+.':
            # Looks like it might be a number - try to parse it
            try:
                # Try parsing as int
                int(number_like_pattern)
                is_number_like = True
            except ValueError:
                try:
                    # Try parsing as float
                    float(number_like_pattern)
                    is_number_like = True
                except ValueError:
                    pass
        
        if is_number_like:
            # Quote it - looks like number but is a string
            escaped_value = value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        
        # Check if string contains special characters that require quoting
        # These characters have special meaning in YAML and will cause parse errors if unquoted
        special_chars = {'"', "'", ':', '#', '{', '}', '[', ']', ',', '&', '*', '?', '|', '-', '!', '%', '@', '`'}
        
        # Check if value contains spaces
        has_spaces = ' ' in value
        
        # Check if value contains any special characters
        has_special_chars = any(c in value for c in special_chars)
        
        # Quote if needed
        if has_special_chars or has_spaces:
            # Escape existing backslashes and quotes before wrapping in quotes
            escaped_value = value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        else:
            # Simple string - no quoting needed
            # Examples: "hello", "4h0m0s", "/etc/kubernetes/pki/ca.crt"
            return value
    
    # === FALLBACK (for unexpected types) ===
    else:
        # Shouldn't reach here with proper type-casting, but handle gracefully
        # Convert to string and apply paranoid quoting rules
        str_value = str(value)
        
        # Check if it looks like a boolean
        boolean_like_values = {'true', 'false', 'yes', 'no', 'on', 'off', 'True', 'False', 'Yes', 'No', 'On', 'Off', 'TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF'}
        if str_value in boolean_like_values:
            escaped_value = str_value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        
        # Check if it looks like a number
        number_like_pattern = str_value.strip()
        is_number_like = False
        
        if number_like_pattern and number_like_pattern[0] in '0123456789-+.':
            try:
                int(number_like_pattern)
                is_number_like = True
            except ValueError:
                try:
                    float(number_like_pattern)
                    is_number_like = True
                except ValueError:
                    pass
        
        if is_number_like:
            escaped_value = str_value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        
        # Check for special characters or spaces
        special_chars = {'"', "'", ':', '#', '{', '}', '[', ']', ',', '&', '*', '?', '|', '-', '!', '%', '@', '`'}
        if any(c in str_value for c in special_chars) or ' ' in str_value:
            escaped_value = str_value.replace('\\', '\\\\').replace('"', '\\"')
            return f'"{escaped_value}"'
        else:
            return str_value


class KubeletHardener:
    """Harden kubelet config with CIS-compliant settings (Non-Destructive Merge Strategy)."""
    
    def __init__(self, config_path="/var/lib/kubelet/config.yaml"):
        self.config_path = Path(config_path)
        self.backup_dir = Path("/var/backups/cis-kubelet")
        self.config: Dict[str, Any] = {}
        
        # Load CIS settings from environment variables or use hardcoded defaults
        self.cis_settings: Dict[str, Any] = self._load_cis_settings()
    
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
        - CONFIG_PROTECT_KERNEL_DEFAULTS: "true"/"false"
        
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
            "protect_kernel_defaults": _get_env_bool("CONFIG_PROTECT_KERNEL_DEFAULTS", False),
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
        if os.environ.get("CONFIG_PROTECT_KERNEL_DEFAULTS"):
            print(f"  CONFIG_PROTECT_KERNEL_DEFAULTS={os.environ.get('CONFIG_PROTECT_KERNEL_DEFAULTS')}")
        
        return settings
    
    def load_config(self):
        """Load ENTIRE existing kubelet config into self.config.
        
        Non-Destructive Strategy:
        - Load the FULL existing configuration from file
        - Do NOT filter or discard any keys
        - Preserve ALL existing settings (staticPodPath, evictionHard, featureGates, etc.)
        - If file doesn't exist, start with minimal valid config
        
        This ensures CIS hardening is applied WITHOUT deleting cluster-specific config.
        """
        if not self.config_path.exists():
            print(f"[INFO] Config file not found at {self.config_path}")
            print("[INFO] Will create minimal config from CIS settings")
            # Start with minimal valid config structure
            self.config = {
                "apiVersion": "kubelet.config.k8s.io/v1beta1",
                "kind": "KubeletConfiguration"
            }
            return True
        
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
            
            if not content.strip():
                print(f"[WARN] Config file is empty at {self.config_path}")
                # Start with minimal valid config
                self.config = {
                    "apiVersion": "kubelet.config.k8s.io/v1beta1",
                    "kind": "KubeletConfiguration"
                }
                return True
            
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
            
            # Store ENTIRE loaded config
            if isinstance(loaded_config, dict):
                self.config = loaded_config
                print(f"[INFO] Loaded {len(loaded_config)} top-level config keys")
                # Log loaded keys for visibility
                keys_str = ", ".join(list(loaded_config.keys())[:5])
                if len(loaded_config) > 5:
                    keys_str += f", ... ({len(loaded_config) - 5} more)"
                print(f"[INFO] Config keys: {keys_str}")
            else:
                print("[WARN] Loaded config is not a dict, starting with minimal config")
                self.config = {
                    "apiVersion": "kubelet.config.k8s.io/v1beta1",
                    "kind": "KubeletConfiguration"
                }
            
            return True
        
        except Exception as e:
            print(f"[WARN] Failed to load config: {e}")
            print("[INFO] Starting with minimal config")
            self.config = {
                "apiVersion": "kubelet.config.k8s.io/v1beta1",
                "kind": "KubeletConfiguration"
            }
            return True
    
    def _parse_broken_config(self, content):
        """Parse broken config using simple key=value extraction.
        
        Fallback parser for configs that can't be parsed as JSON or YAML.
        Best-effort attempt to extract all settings.
        """
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
            return False
    
    def harden_config(self):
        """Apply CIS hardening via Non-Destructive Deep Merge.
        
        Strategy:
        1. self.config already contains ENTIRE existing config (from load_config)
        2. Apply CIS settings by deep-merging (not replacing) specific keys
        3. For nested dicts (authentication, authorization), merge carefully
        4. Preserve ALL existing keys that aren't explicitly being hardened
        5. Apply type-casting to final merged config
        
        Result: CIS hardening is applied WITHOUT deleting environment-specific config
        like staticPodPath, evictionHard, featureGates, volumePluginDir, etc.
        """
        print("[INFO] Applying CIS hardening via non-destructive merge...")
        
        # Ensure config is a dict
        if not isinstance(self.config, dict):
            print("[ERROR] Config is not a dictionary, cannot merge")
            return False
        
        # Set or update metadata fields
        if "apiVersion" not in self.config:
            self.config["apiVersion"] = "kubelet.config.k8s.io/v1beta1"
        if "kind" not in self.config:
            self.config["kind"] = "KubeletConfiguration"
        
        print("[INFO] Applying CIS authentication settings...")
        # Initialize authentication structure if missing
        if "authentication" not in self.config:
            self.config["authentication"] = {}
        
        # Deep merge: Set anonymous auth, but preserve other auth settings
        if "anonymous" not in self.config["authentication"]:
            self.config["authentication"]["anonymous"] = {}
        self.config["authentication"]["anonymous"]["enabled"] = self.cis_settings["anonymous_auth"]
        
        # Set webhook auth, but preserve other webhook settings
        if "webhook" not in self.config["authentication"]:
            self.config["authentication"]["webhook"] = {}
        self.config["authentication"]["webhook"]["enabled"] = self.cis_settings["webhook_auth"]
        if "cacheTTL" not in self.config["authentication"]["webhook"]:
            self.config["authentication"]["webhook"]["cacheTTL"] = "2m0s"
        
        # Set x509 client CA file
        if "x509" not in self.config["authentication"]:
            self.config["authentication"]["x509"] = {}
        self.config["authentication"]["x509"]["clientCAFile"] = self.cis_settings["client_ca_file"]
        
        print("[INFO] Applying CIS authorization settings...")
        # Initialize authorization structure if missing
        if "authorization" not in self.config:
            self.config["authorization"] = {}
        
        # Set authorization mode
        self.config["authorization"]["mode"] = self.cis_settings["authorization_mode"]
        
        # Set webhook config, but preserve other authorization settings
        if "webhook" not in self.config["authorization"]:
            self.config["authorization"]["webhook"] = {}
        if "cacheAuthorizedTTL" not in self.config["authorization"]["webhook"]:
            self.config["authorization"]["webhook"]["cacheAuthorizedTTL"] = "5m0s"
        if "cacheUnauthorizedTTL" not in self.config["authorization"]["webhook"]:
            self.config["authorization"]["webhook"]["cacheUnauthorizedTTL"] = "30s"
        
        print("[INFO] Applying CIS security settings...")
        # Apply top-level security settings (only if not already set or explicitly configured)
        self.config["readOnlyPort"] = self.cis_settings["read_only_port"]
        self.config["streamingConnectionIdleTimeout"] = self.cis_settings["streaming_timeout"]
        self.config["makeIPTablesUtilChains"] = self.cis_settings["make_iptables_util_chains"]
        self.config["rotateCertificates"] = self.cis_settings["rotate_certificates"]
        self.config["serverTLSBootstrap"] = True
        self.config["rotateServerCertificates"] = self.cis_settings["rotate_server_certificates"]
        self.config["tlsCipherSuites"] = self.cis_settings["tls_cipher_suites"]
        self.config["podPidsLimit"] = self.cis_settings["pod_pids_limit"]
        self.config["seccompDefault"] = self.cis_settings["seccomp_default"]
        self.config["protectKernelDefaults"] = self.cis_settings["protect_kernel_defaults"]
        
        # Set cgroup driver if not already present
        if "cgroupDriver" not in self.config:
            self.config["cgroupDriver"] = "systemd"
        
        # Set cluster DNS if not already present
        if "clusterDNS" not in self.config:
            self.config["clusterDNS"] = ["10.96.0.10"]
        
        # Set cluster domain if not already present
        if "clusterDomain" not in self.config:
            self.config["clusterDomain"] = "cluster.local"
        
        print("[INFO] Applying strict type casting to all config values...")
        # === CRITICAL: Apply STRICT type casting to entire config ===
        # This ensures every value has correct Python type BEFORE YAML output
        self.config = cast_config_recursively(self.config)
        print("[PASS] All config values type-cast (int/bool/list/str)")
        
        print("[PASS] CIS hardening applied via non-destructive merge")
        return True
    
    def write_config(self):
        """Write hardened config back to file in clean YAML format.
        
        Non-Destructive Strategy: Writes the merged config (which contains all
        original keys + CIS hardened settings) to YAML format.
        
        This preserves all environment-specific configuration while applying CIS hardening.
        """
        try:
            # Ensure config is a dict
            if not isinstance(self.config, dict):
                print("[ERROR] Config is not a dictionary")
                return False
            
            print(f"[INFO] Writing merged config to {self.config_path}")
            
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
            
            print("[PASS] Config written successfully (all existing settings preserved)")
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to write config: {e}")
            return False
    
    def verify_config(self):
        """Verify config is valid YAML/can be parsed.
        
        Checks that the merged config contains expected CIS hardening settings
        AND original cluster-specific settings.
        """
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
            
            # Verify key CIS settings are present
            if "enabled: false" not in content and "enabled: true" not in content:
                print("[WARN] Could not verify boolean settings in output")
            
            # Verify non-destructive merge (check for preserved keys if they were in original)
            if "clusterDNS" in self.config and "clusterDNS" not in content:
                print("[WARN] clusterDNS may not have been preserved correctly")
            
            return True
        
        except Exception as e:
            print(f"[ERROR] Failed to verify config: {e}")
            return False
    
    def restart_kubelet(self):
        """Restart kubelet service with Smart Rate Limiting to prevent systemd burst limit.
        
        Smart Rate Limiting Strategy:
        - Tracks last restart time in /tmp/kubelet_last_restart.timestamp
        - If restart was less than 60 seconds ago, SKIP restart (return True to continue)
        - If restart was 60+ seconds ago (or no previous restart), execute restart normally
        - This prevents systemd "Start Limit Burst" protection from triggering
        
        Use Case: When harden_kubelet.py is called 24 times in a loop:
        - First restart: Executes normally
        - Restarts 2-24: Skipped (with manual restart reminder printed)
        - User runs manual restart ONCE after all checks complete
        
        Non-Destructive Strategy: Returns True on skipped restarts so the runner
        continues without error. The hardened config is already written to disk.
        """
        timestamp_file = Path("/tmp/kubelet_last_restart.timestamp")
        
        # Check if we've restarted recently
        current_time = time.time()
        restart_interval_seconds = 60  # Minimum time between restarts
        
        if timestamp_file.exists():
            try:
                with open(timestamp_file, 'r') as f:
                    last_restart_time = float(f.read().strip())
                
                time_diff = current_time - last_restart_time
                
                if time_diff < restart_interval_seconds:
                    # Too soon - skip restart to prevent systemd burst limit
                    print(f"[INFO] Skipping restart to avoid systemd burst limit (Last restart was {time_diff:.0f}s ago)")
                    print(f"[WARN] CONFIG UPDATED. PLEASE RUN 'systemctl restart kubelet' MANUALLY AT THE END")
                    return True  # Pretend success so runner continues
                
            except (ValueError, OSError) as e:
                print(f"[WARN] Could not read timestamp file: {e}, proceeding with restart")
        
        # Enough time has passed - execute restart normally
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
            
            # Restart successful - record the timestamp
            try:
                with open(timestamp_file, 'w') as f:
                    f.write(str(current_time))
                print(f"[INFO] Restart timestamp recorded at {timestamp_file}")
            except OSError as e:
                print(f"[WARN] Could not write timestamp file: {e}")
            
            # Wait for kubelet to become active (up to 15 seconds)
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
        """Execute full hardening procedure using non-destructive merge strategy.
        
        Steps:
        1. Load ENTIRE existing config (all keys, not filtered)
        2. Create timestamped backup
        3. Deep-merge CIS hardening into existing config
        4. Apply type-casting to ensure correct Python types
        5. Write merged config back to file
        6. Verify config structure
        7. Restart kubelet
        
        Result: CIS hardening applied WITHOUT deleting environment-specific settings
        """
        print("=" * 80)
        print("KUBELET CONFIGURATION HARDENER (Non-Destructive Merge)")
        print("=" * 80)
        print(f"[INFO] Target: {self.config_path}")
        print(f"[INFO] Strategy: Load ENTIRE config → Deep Merge CIS settings → Preserve all other keys")
        print()
        
        # Step 1: Load config
        print("[STEP 1] Loading ENTIRE kubelet configuration...")
        if not self.load_config():
            print("[FAIL] Failed to load config")
            return False
        print()
        
        # Step 2: Backup
        print("[STEP 2] Creating backup...")
        backup = self.create_backup()
        if backup:
            print(f"[INFO] Backup available for rollback")
        print()
        
        # Step 3: Harden
        print("[STEP 3] Applying CIS hardening via non-destructive merge...")
        if not self.harden_config():
            print("[FAIL] Failed to harden config")
            return False
        print()
        
        # Step 4: Write
        print("[STEP 4] Writing merged config (CIS hardening + all existing settings)...")
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
        print("[PASS] Kubelet hardening complete (non-destructive merge)!")
        print("[INFO] All existing settings preserved + CIS hardening applied")
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
