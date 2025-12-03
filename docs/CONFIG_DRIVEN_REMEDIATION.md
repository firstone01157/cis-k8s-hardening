# CIS Kubernetes Benchmark - Config-Driven Remediation System

## Overview

The CIS Kubernetes Benchmark system has been refactored to support **config-driven remediation**, allowing you to:

- ✅ Control remediation behavior via JSON configuration (`cis_config.json`)
- ✅ Skip specific checks without modifying scripts
- ✅ Adjust remediation parameters dynamically
- ✅ Pass environment variables to bash scripts
- ✅ Implement dry-run testing before actual changes
- ✅ Log all configuration decisions

## Architecture

### 1. Configuration Structure (`cis_config.json`)

#### Global Remediation Settings
```json
"remediation_config": {
    "global": {
        "backup_enabled": true,          # Create backups before changes
        "backup_dir": "/var/backups/cis-remediation",
        "dry_run": false,                # Preview changes without applying
        "wait_for_api": true,            # Wait for API server health
        "api_timeout": 30,               # kubectl timeout in seconds
        "api_retries": 10                # Number of API health check retries
    }
}
```

#### Check-Specific Configuration
```json
"checks": {
    "3.2.1": {
        "enabled": true,                 # Enable/disable this check
        "skip": false,                   # Skip remediation for this check
        "audit_level": "Metadata",       # Metadata or RequestResponse
        "log_sensitive_resources": true,
        "sensitive_resources": [
            "secrets", "configmaps", "pods/exec", "pods/attach"
        ]
    },
    "5.2.1": {
        "enabled": true,
        "skip": false,
        "mode": "warn-audit",            # warn-audit, warn-only, audit-only, enforce
        "namespaces": {
            "default": {
                "warn": "restricted",
                "audit": "restricted",
                "enforce": "disabled"
            }
        }
    }
}
```

#### Environment Variable Overrides
```json
"environment_overrides": {
    "PSS_MODE": "warn-audit",            # Pod Security Standards mode
    "AUDIT_LEVEL": "Metadata",           # Audit policy level
    "ENFORCE_MODE": "disabled",          # Enforcement mode
    "DRY_RUN": "false"                   # Dry-run flag
}
```

### 2. Python Runner Changes

#### `load_config()` - Enhanced Configuration Loading
```python
def load_config(self):
    """Load configuration including remediation settings"""
    self.remediation_config = config.get("remediation_config", {})
    self.remediation_global_config = self.remediation_config.get("global", {})
    self.remediation_checks_config = self.remediation_config.get("checks", {})
    self.remediation_env_vars = self.remediation_config.get("environment_overrides", {})
```

#### `get_remediation_config_for_check()` - Check-Specific Config Retrieval
```python
def get_remediation_config_for_check(self, check_id):
    """Get remediation configuration for a specific check"""
    return self.remediation_checks_config.get(check_id, {})
```

#### `run_script()` - Environment Variable Injection
```python
# Check remediation config for skipping
if mode == "remediate":
    remediation_cfg = self.get_remediation_config_for_check(script_id)
    if remediation_cfg.get("skip", False):
        return self._create_result(script, "SKIPPED", "Skipped by config", ...)

# Prepare environment variables
env = os.environ.copy()

if mode == "remediate":
    # Add global config
    env.update({
        "BACKUP_ENABLED": str(self.remediation_global_config.get("backup_enabled", True)).lower(),
        "DRY_RUN": str(self.remediation_global_config.get("dry_run", False)).lower(),
        ...
    })
    
    # Add check-specific config
    remediation_cfg = self.get_remediation_config_for_check(script_id)
    for key, value in remediation_cfg.items():
        env[f"CONFIG_{key.upper()}"] = str(value) or json.dumps(value)
    
    # Add environment overrides
    env.update(self.remediation_env_vars)

# Run script with environment variables
result = subprocess.run(
    ["bash", script["path"]],
    capture_output=True,
    text=True,
    env=env
)
```

### 3. Bash Script Patterns (Config-Driven Templates)

#### Key Features
- ✅ Read configuration from environment variables
- ✅ Provide sensible defaults if not set
- ✅ Support dry-run mode for safe testing
- ✅ Structured logging to `/var/log/cis-*.log`
- ✅ Clear exit codes (0=success, 1=failure)

#### Example: 5.2.1_remediate_template.sh
```bash
# Environment variables (set by Python runner)
PSS_MODE="${PSS_MODE:-warn-audit}"
DRY_RUN="${DRY_RUN:-false}"
CONFIG_CREATE_SECURE_ZONE="${CONFIG_CREATE_SECURE_ZONE:-false}"

# Parse mode to determine labels
parse_pss_mode() {
    case "${PSS_MODE}" in
        warn-audit)
            WARN_MODE="restricted"
            AUDIT_MODE="restricted"
            ENFORCE_MODE="disabled"
            ;;
        enforce)
            WARN_MODE="disabled"
            AUDIT_MODE="disabled"
            ENFORCE_MODE="restricted"
            ;;
    esac
}

# Apply with dry-run support
if [ "${DRY_RUN}" = "true" ]; then
    log_msg "DRYRUN" "Would apply: ${label_cmd}"
else
    eval "${label_cmd}"
fi
```

#### Example: 3.2.1_remediate_template.sh
```bash
# Environment variables
AUDIT_LEVEL="${AUDIT_LEVEL:-Metadata}"
CONFIG_AUDIT_LEVEL="${CONFIG_AUDIT_LEVEL:-Metadata}"
DRY_RUN="${DRY_RUN:-false}"

# Use config if provided
if [ -n "${CONFIG_AUDIT_LEVEL}" ]; then
    AUDIT_LEVEL="${CONFIG_AUDIT_LEVEL}"
fi

# Create policy with audit level
sed -i "s/AUDIT_LEVEL_PLACEHOLDER/${AUDIT_LEVEL}/g" "${AUDIT_POLICY_FILE}"
```

## Workflow

### 1. Configuration Phase
```
User updates cis_config.json
    ↓
Python runner calls load_config()
    ↓
Stores remediation_config, checks_config, env_vars
    ↓
Ready for remediation
```

### 2. Remediation Phase
```
For each remediation script:
    ↓
Check if remediation_cfg.skip == true
    ↓ (if skip: mark SKIPPED, move to next)
    ↓ (if not skip: continue)
    ↓
Build environment variables from config
    ↓
Pass env vars to bash script
    ↓
Script reads env vars and applies remediation
    ↓
Return exit code (0=pass, 1=fail)
```

### 3. Result Processing
```
Script output → parse_script_output()
    ↓
Check for [+] PASS / [-] FAIL markers
    ↓
If returncode==0 and "Manual" in output → MANUAL status
    ↓
Update statistics
    ↓
Log result
```

## Configuration Examples

### Example 1: Skip a Specific Check
```json
"5.2.1": {
    "enabled": true,
    "skip": true,  // ← This check will be SKIPPED
    "mode": "warn-audit"
}
```

### Example 2: Enforce Mode Instead of Warn
```json
"5.2.1": {
    "mode": "enforce"  // ← All namespaces enforce=restricted
}
```

### Example 3: Dry Run Everything
```json
"global": {
    "dry_run": true  // ← All remediations preview-only
}
```

### Example 4: Custom Audit Level
```json
"3.2.1": {
    "audit_level": "RequestResponse",  // ← More verbose logging
    "log_sensitive_resources": true
}
```

## Environment Variables Passed to Scripts

### Global Variables (Always Passed in Remediate Mode)
```bash
BACKUP_ENABLED=true
BACKUP_DIR=/var/backups/cis-remediation
DRY_RUN=false
WAIT_FOR_API=true
API_TIMEOUT=30
API_RETRIES=10
```

### Check-Specific Variables (Prefixed with CONFIG_)
```bash
CONFIG_MODE=restricted
CONFIG_SKIP=false
CONFIG_ENABLED=true
CONFIG_AUDIT_LEVEL=Metadata
CONFIG_NAMESPACES='{"default": {...}}'
CONFIG_CREATE_SECURE_ZONE=false
```

### Environment Overrides
```bash
PSS_MODE=warn-audit
AUDIT_LEVEL=Metadata
ENFORCE_MODE=disabled
DRY_RUN=false
```

## Bash Script Template Requirements

Each config-driven remediation script should:

1. **Read environment variables with defaults**
   ```bash
   PSS_MODE="${PSS_MODE:-warn-audit}"
   DRY_RUN="${DRY_RUN:-false}"
   ```

2. **Support dry-run mode**
   ```bash
   if [ "${DRY_RUN}" = "true" ]; then
       log_msg "DRYRUN" "Would execute: ${cmd}"
       return 0
   fi
   ```

3. **Log to structured file**
   ```bash
   log_msg "INFO" "Starting remediation..."
   log_msg "PASS" "Successfully applied fix"
   log_msg "FAIL" "Failed to apply fix"
   ```

4. **Exit with proper codes**
   ```bash
   exit 0  # Success
   exit 1  # Failure
   ```

5. **Include health checks**
   ```bash
   if [ "${WAIT_FOR_API}" = "true" ]; then
       wait_for_api_server || exit 1
   fi
   ```

## Benefits

### For Operators
- 🎯 **Central Configuration**: All remediation parameters in one JSON file
- 🔄 **Easy Updates**: Change behavior without modifying scripts
- 🚀 **Safe Testing**: Dry-run mode to preview changes
- 📊 **Auditability**: All decisions logged and configurable
- 🛑 **Selective Remediation**: Skip checks per environment

### For DevOps Teams
- 🔧 **Consistency**: All scripts follow same pattern
- 📚 **Documentation**: Config structure is self-documenting
- 🧪 **Testing**: Dry-run mode for validation
- ♻️ **Reusability**: Templates work across clusters
- 🔍 **Debugging**: Environment variables for troubleshooting

### For Security
- 🛡️ **Explicit Control**: Every change is configurable
- 📝 **Audit Trail**: All configuration recorded
- ✅ **Verification**: Built-in health checks
- 🔐 **Backups**: Automatic before each change
- 🚨 **Error Handling**: Clear failure messages

## Troubleshooting

### Check Current Configuration
```bash
# View remediation config for a check
cat cis_config.json | jq '.remediation_config.checks["5.2.1"]'
```

### Test with Dry-Run
```json
{
    "global": {
        "dry_run": true
    }
}
```

### Verify Environment Variables Passed
```bash
# In the Python runner with -vv flag
python3 cis_k8s_unified.py -vv
# Will show: [DEBUG] Remediation env vars for 5.2.1: [...]
```

### Check Script Logs
```bash
tail -f /var/log/cis-5.2.1-remediation.log
tail -f /var/log/cis-3.2.1-remediation.log
tail -f /var/log/cis-manual-remediation.log
```

## Migration Guide

### From Hardcoded Scripts to Config-Driven

**Before:**
```bash
# Hardcoded values in script
PSS_MODE="warn-audit"
AUDIT_LEVEL="Metadata"
```

**After:**
```bash
# Read from environment (set by Python runner)
PSS_MODE="${PSS_MODE:-warn-audit}"
AUDIT_LEVEL="${AUDIT_LEVEL:-Metadata}"
```

### Updating Existing Scripts

1. Replace hardcoded values with environment variables
2. Add environment variable defaults using `${VAR:-default}`
3. Add dry-run support
4. Add configuration to `cis_config.json`
5. Test with `dry_run: true`
6. Deploy when validated

## Future Enhancements

- Multi-environment configurations (dev/stage/prod)
- Configuration validation schema
- Scheduled remediation via cron
- Configuration management system (CM) integration
- Prometheus metrics export
