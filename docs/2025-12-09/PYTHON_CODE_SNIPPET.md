# Python Code - Reference to Copy-Paste into cis_k8s_unified.py

## Installation Instructions

1. **Backup your current file:**
   ```bash
   cp cis_k8s_unified.py cis_k8s_unified.py.backup
   ```

2. **Replace the `load_config()` method** (around line 108-154)
3. **Add the two new methods** `_resolve_references()` and `_get_nested_value()` after `load_config()`

---

## COMPLETE PYTHON CODE

### Updated Method: load_config()

```python
def load_config(self):
    """Load configuration from JSON file / โหลดการตั้งค่าจากไฟล์ JSON"""
    self.excluded_rules = {}
    self.component_mapping = {}
    self.remediation_config = {}
    self.remediation_global_config = {}
    self.remediation_checks_config = {}
    self.remediation_env_vars = {}
    self.variables = {}  # Store variables section for reference resolution
    
    # Initialize API timeout settings with defaults
    self.api_check_interval = 5  # seconds
    self.api_max_retries = 60    # 60 * 5 = 300 seconds total (5 minutes)
    self.api_settle_time = 15    # settle time after API becomes ready (seconds)
    self.wait_for_api_enabled = True
    
    if not os.path.exists(self.config_file):
        print(f"{Colors.YELLOW}[!] Config not found. Using defaults.{Colors.ENDC}")
        return
    
    try:
        with open(self.config_file, 'r') as f:
            config = json.load(f)
            self.excluded_rules = config.get("excluded_rules", {})
            self.component_mapping = config.get("component_mapping", {})
            self.variables = config.get("variables", {})  # Load variables for reference resolution
            
            # Load remediation configuration / โหลดการตั้งค่าการแก้ไข
            self.remediation_config = config.get("remediation_config", {})
            self.remediation_global_config = self.remediation_config.get("global", {})
            self.remediation_checks_config = self.remediation_config.get("checks", {})
            self.remediation_env_vars = self.remediation_config.get("environment_overrides", {})
            
            # Load API timeout settings from global config
            self.wait_for_api_enabled = self.remediation_global_config.get("wait_for_api", True)
            self.api_check_interval = self.remediation_global_config.get("api_check_interval", 5)
            self.api_max_retries = self.remediation_global_config.get("api_max_retries", 60)
            self.api_settle_time = self.remediation_global_config.get("api_settle_time", 15)
            
            # Resolve all variable references in checks / แก้ไขการอ้างอิงตัวแปรทั้งหมด
            self._resolve_references()
            
            if self.verbose >= 1:
                print(f"{Colors.BLUE}[DEBUG] Loaded remediation config for {len(self.remediation_checks_config)} checks{Colors.ENDC}")
                print(f"{Colors.BLUE}[DEBUG] API timeout settings: interval={self.api_check_interval}s, max_retries={self.api_max_retries}, settle_time={self.api_settle_time}s{Colors.ENDC}")
                print(f"{Colors.BLUE}[DEBUG] Resolved variable references in checks{Colors.ENDC}")
    except json.JSONDecodeError as e:
        print(f"{Colors.RED}[!] Config parse error: {e}{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.RED}[!] Config load error: {e}{Colors.ENDC}")
```

### New Method: _resolve_references()

```python
def _resolve_references(self):
    """
    Resolve all variable references in remediation checks.
    
    Algorithm:
    1. Iterate through each check in remediation_checks_config
    2. Identify all keys ending with '_ref' (e.g., '_required_value_ref', '_file_mode_ref')
    3. Parse the dotted path from the reference value (e.g., "variables.api_server_flags.secure_port")
    4. Fetch the actual value from self.variables using the dotted path
    5. Inject/Overwrite the target key with the fetched value
    6. Handle type conversions (JSON booleans to strings if needed)
    7. Log warnings for invalid references
    
    Error Handling:
    - Invalid reference paths log a warning but don't halt execution
    - Missing variables are logged at verbose level 1+
    - Type conversion is handled gracefully
    """
    reference_count = 0
    invalid_refs = []
    
    for check_id, check_config in self.remediation_checks_config.items():
        if not isinstance(check_config, dict):
            continue
        
        # Find all keys ending with '_ref'
        ref_keys = [key for key in check_config.keys() if key.endswith('_ref')]
        
        for ref_key in ref_keys:
            ref_path = check_config[ref_key]
            target_key = ref_key.replace('_ref', '')  # e.g., '_required_value_ref' -> '_required_value'
            
            # Fetch the value from variables using dotted path
            # ref_path is like "variables.api_server_flags.secure_port"
            # Extract the part after "variables." to search in self.variables
            if ref_path.startswith("variables."):
                var_path = ref_path[len("variables."):]  # Remove "variables." prefix
                resolved_value = self._get_nested_value(self.variables, var_path)
            else:
                resolved_value = None
            
            if resolved_value is None:
                invalid_refs.append({
                    'check_id': check_id,
                    'ref_key': ref_key,
                    'ref_path': ref_path
                })
                if self.verbose >= 1:
                    print(f"{Colors.YELLOW}[!] Invalid reference in check {check_id}: {ref_path} not found{Colors.ENDC}")
            else:
                # Type conversion: Convert JSON boolean to string if appropriate
                if isinstance(resolved_value, bool):
                    resolved_value = str(resolved_value).lower()  # true -> "true", false -> "false"
                
                # Inject the resolved value into the check config
                check_config[target_key] = resolved_value
                reference_count += 1
                
                if self.verbose >= 2:
                    print(f"{Colors.BLUE}[DEBUG] Resolved {check_id}.{target_key} = {resolved_value}{Colors.ENDC}")
    
    if self.verbose >= 1 and reference_count > 0:
        print(f"{Colors.GREEN}[+] Resolved {reference_count} variable references{Colors.ENDC}")
    
    if invalid_refs and self.verbose >= 1:
        print(f"{Colors.YELLOW}[!] Found {len(invalid_refs)} invalid references{Colors.ENDC}")
        for invalid in invalid_refs:
            print(f"    - {invalid['check_id']}: {invalid['ref_path']}")
```

### New Method: _get_nested_value()

```python
def _get_nested_value(self, data, dotted_path):
    """
    Retrieve a value from nested dictionary using dotted path notation.
    
    Example:
        dotted_path = "api_server_flags.secure_port"
        Returns the value at data['api_server_flags']['secure_port']
    
    Args:
        data (dict): The root dictionary to search
        dotted_path (str): Dot-separated path (e.g., "api_server_flags.secure_port")
    
    Returns:
        The value at the path, or None if path is invalid
    """
    try:
        keys = dotted_path.split('.')
        current = data
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
        
        return current
    except Exception:
        return None
```

---

## Verification Steps

After copying the code:

1. **Run syntax check:**
   ```bash
   python3 -m py_compile cis_k8s_unified.py
   ```

2. **Test the loader:**
   ```bash
   python3 test_refs_simple.py
   ```

3. **Expected output:**
   ```
   ✓ Check 1.2.8 (Secure port)
   ✓ Check 1.2.14 (Request timeout)
   ✓ Check 1.2.17 (etcd prefix)
   ✓ Check 1.2.20 (TLS min version)
   ✓ Check 1.2.23 (Audit policy file)
   ✓ Check 1.2.30 (Event TTL)
   ✓ ALL TESTS PASSED
   ```

---

## Debugging Tips

If you encounter issues:

1. **Enable verbose mode** to see what's being resolved:
   ```bash
   python3 cis_k8s_unified.py -vv
   ```

2. **Check reference paths** in cis_config.json for typos

3. **Validate JSON**:
   ```bash
   python3 -m json.tool cis_config.json > /dev/null && echo "OK" || echo "INVALID"
   ```

4. **Check variable availability**:
   ```bash
   python3 -c "import json; c=json.load(open('cis_config.json')); print(c['variables']['api_server_flags'].keys())"
   ```
