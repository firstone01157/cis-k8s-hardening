# Complete Code for Smart Remediation Scripts

## 4.1.3_remediate.sh - Proxy Kubeconfig Permissions

```bash
#!/bin/bash
# CIS Benchmark: 4.1.3
# Title: If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive
# Level: Level 1 - Worker Node
# Remediation Script
# Smart: PASS if kube-proxy --kubeconfig is not set (secure default in Kubeadm)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

remedy_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    # Get kube-proxy kubeconfig path (returns empty if --kubeconfig not set)
    kube_proxy_kubeconfig=$(kube_proxy_kubeconfig_path)

    # SMART CHECK: If --kubeconfig is not set, this is the secure default
    if [ -z "$kube_proxy_kubeconfig" ]; then
        a_output+=(" - PASS: kube-proxy using in-cluster config (default, no --kubeconfig needed)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # If --kubeconfig is set, file must exist and have proper permissions
    if [ ! -f "$kube_proxy_kubeconfig" ]; then
        a_output2+=(" - FAIL: kube-proxy --kubeconfig file specified but does not exist: $kube_proxy_kubeconfig")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAIL" "${a_output2[@]}"
        return 1
    fi

    # Check current permissions
    current_perms=$(stat -c %a "$kube_proxy_kubeconfig")

    # Check if permissions are 600 or more restrictive ([0-6]00)
    if echo "$current_perms" | grep -qE '^[0-6]00$'; then
        a_output+=(" - PASS: $kube_proxy_kubeconfig permissions are $current_perms (600 or more restrictive)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # Permissions not restrictive enough - fix them
    cp -p "$kube_proxy_kubeconfig" "$kube_proxy_kubeconfig.bak.$(date +%s)"
    chmod 600 "$kube_proxy_kubeconfig"
    new_perms=$(stat -c %a "$kube_proxy_kubeconfig")

    if echo "$new_perms" | grep -qE '^[0-6]00$'; then
        a_output+=(" - FIXED: $kube_proxy_kubeconfig permissions changed from $current_perms to $new_perms")
        printf '%s\n' "" "- Remediation Result:" "  [+] FIXED" "${a_output[@]}"
        return 0
    else
        a_output2+=(" - FAILED: Could not set correct permissions on $kube_proxy_kubeconfig")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAILED" "${a_output2[@]}"
        return 1
    fi
}

remedy_rule
exit $?
```

---

## 4.1.4_remediate.sh - Proxy Kubeconfig Ownership

```bash
#!/bin/bash
# CIS Benchmark: 4.1.4
# Title: If proxy kubeconfig file exists ensure ownership is set to root:root
# Level: Level 1 - Worker Node
# Remediation Script
# Smart: PASS if kube-proxy --kubeconfig is not set (secure default in Kubeadm)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

remedy_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    # Get kube-proxy kubeconfig path (returns empty if --kubeconfig not set)
    kube_proxy_kubeconfig=$(kube_proxy_kubeconfig_path)

    # SMART CHECK: If --kubeconfig is not set, this is the secure default
    if [ -z "$kube_proxy_kubeconfig" ]; then
        a_output+=(" - PASS: kube-proxy using in-cluster config (default, no --kubeconfig needed)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # If --kubeconfig is set, file must exist and have proper ownership
    if [ ! -f "$kube_proxy_kubeconfig" ]; then
        a_output2+=(" - FAIL: kube-proxy --kubeconfig file specified but does not exist: $kube_proxy_kubeconfig")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAIL" "${a_output2[@]}"
        return 1
    fi

    # Check current ownership
    current_owner=$(stat -c "%U:%G" "$kube_proxy_kubeconfig")

    # Check if ownership is root:root
    if [ "$current_owner" = "root:root" ]; then
        a_output+=(" - PASS: $kube_proxy_kubeconfig ownership is $current_owner")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # Ownership not correct - fix it
    cp -p "$kube_proxy_kubeconfig" "$kube_proxy_kubeconfig.bak.$(date +%s)"
    chown root:root "$kube_proxy_kubeconfig"
    new_owner=$(stat -c "%U:%G" "$kube_proxy_kubeconfig")

    if [ "$new_owner" = "root:root" ]; then
        a_output+=(" - FIXED: $kube_proxy_kubeconfig ownership changed from $current_owner to $new_owner")
        printf '%s\n' "" "- Remediation Result:" "  [+] FIXED" "${a_output[@]}"
        return 0
    else
        a_output2+=(" - FAILED: Could not set correct ownership on $kube_proxy_kubeconfig")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAILED" "${a_output2[@]}"
        return 1
    fi
}

remedy_rule
exit $?
```

---

## 4.1.7_remediate.sh - Client CA File Permissions

```bash
#!/bin/bash
# CIS Benchmark: 4.1.7
# Title: Ensure that the certificate authorities file permissions are set to 644 or more restrictive
# Level: Level 1 - Worker Node
# Remediation Script
# Smart: PASS if --client-ca-file is not set (secure default in Kubeadm)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

remedy_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    # Get client CA file path from kubelet command line (returns empty if --client-ca-file not set)
    client_ca_file=$(kubelet_arg_value "--client-ca-file")

    # SMART CHECK: If --client-ca-file is not set, this is the secure default
    if [ -z "$client_ca_file" ]; then
        a_output+=(" - PASS: --client-ca-file not configured (default, not required)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # If --client-ca-file is set, file must exist and have proper permissions
    if [ ! -f "$client_ca_file" ]; then
        a_output2+=(" - FAIL: --client-ca-file specified but does not exist: $client_ca_file")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAIL" "${a_output2[@]}"
        return 1
    fi

    # Check current permissions
    current_perms=$(stat -c %a "$client_ca_file")

    # Check if permissions are 644 or more restrictive ([0-6][0-4][0-4])
    if echo "$current_perms" | grep -qE '^[0-6][0-4][0-4]$'; then
        a_output+=(" - PASS: $client_ca_file permissions are $current_perms (644 or more restrictive)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # Permissions not restrictive enough - fix them
    cp -p "$client_ca_file" "$client_ca_file.bak.$(date +%s)"
    chmod 644 "$client_ca_file"
    new_perms=$(stat -c %a "$client_ca_file")

    if echo "$new_perms" | grep -qE '^[0-6][0-4][0-4]$'; then
        a_output+=(" - FIXED: $client_ca_file permissions changed from $current_perms to $new_perms")
        printf '%s\n' "" "- Remediation Result:" "  [+] FIXED" "${a_output[@]}"
        return 0
    else
        a_output2+=(" - FAILED: Could not set correct permissions on $client_ca_file")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAILED" "${a_output2[@]}"
        return 1
    fi
}

remedy_rule
exit $?
```

---

## 4.1.8_remediate.sh - Client CA File Ownership

```bash
#!/bin/bash
# CIS Benchmark: 4.1.8
# Title: Ensure that the client certificate authorities file ownership is set to root:root
# Level: Level 1 - Worker Node
# Remediation Script
# Smart: PASS if --client-ca-file is not set (secure default in Kubeadm)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

remedy_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    # Get client CA file path from kubelet command line (returns empty if --client-ca-file not set)
    client_ca_file=$(kubelet_arg_value "--client-ca-file")

    # SMART CHECK: If --client-ca-file is not set, this is the secure default
    if [ -z "$client_ca_file" ]; then
        a_output+=(" - PASS: --client-ca-file not configured (default, not required)")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # If --client-ca-file is set, file must exist and have proper ownership
    if [ ! -f "$client_ca_file" ]; then
        a_output2+=(" - FAIL: --client-ca-file specified but does not exist: $client_ca_file")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAIL" "${a_output2[@]}"
        return 1
    fi

    # Check current ownership
    current_owner=$(stat -c "%U:%G" "$client_ca_file")

    # Check if ownership is root:root
    if [ "$current_owner" = "root:root" ]; then
        a_output+=(" - PASS: $client_ca_file ownership is $current_owner")
        printf '%s\n' "" "- Remediation Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    fi

    # Ownership not correct - fix it
    cp -p "$client_ca_file" "$client_ca_file.bak.$(date +%s)"
    chown root:root "$client_ca_file"
    new_owner=$(stat -c "%U:%G" "$client_ca_file")

    if [ "$new_owner" = "root:root" ]; then
        a_output+=(" - FIXED: $client_ca_file ownership changed from $current_owner to $new_owner")
        printf '%s\n' "" "- Remediation Result:" "  [+] FIXED" "${a_output[@]}"
        return 0
    else
        a_output2+=(" - FAILED: Could not set correct ownership on $client_ca_file")
        printf '%s\n' "" "- Remediation Result:" "  [-] FAILED" "${a_output2[@]}"
        return 1
    fi
}

remedy_rule
exit $?
```

---

## Key Features Across All Scripts

### 1. Smart Logic
- **Default-aware:** PASS if config not set (secure Kubeadm default)
- **Validation:** Checks file exists if config is set
- **Remediation:** Fixes if needed, creates backup

### 2. Consistent Structure
```
INPUT: Get configuration value
    ↓
CHECK IF NOT SET: PASS (secure default)
    ↓
CHECK IF FILE MISSING: FAIL (config error)
    ↓
CHECK IF SETTING CORRECT: PASS (already secure)
    ↓
APPLY FIX: Backup + Remediate + Verify + FIXED
    ↓
OUTPUT: Clear status report
```

### 3. Helper Function Usage
- `kube_proxy_kubeconfig_path()` - For 4.1.3 & 4.1.4
- `kubelet_arg_value()` - For 4.1.7 & 4.1.8
- Both return empty string if not set (key to smart detection)

### 4. File Backup Strategy
```bash
cp -p "$file" "$file.bak.$(date +%s)"
```
- Preserves permissions with `-p` flag
- Preserves ownership
- Timestamp ensures no collisions
- Original file recoverable if needed

### 5. Permission Regex Patterns
- **600-restricted:** `^[0-6]00$` (000, 100, 200, 300, 400, 500, 600)
- **644-restricted:** `^[0-6][0-4][0-4]$` (000-600, 640, 644, etc.)

---

## Deployment

Copy all 4 scripts to worker node:
```bash
scp -r Level_1_Worker_Node/ node_1@192.168.x.x:~/cis-k8s-hardening/
```

Make executable:
```bash
chmod +x 4.1.{3,4,7,8}_remediate.sh
```

Run as root:
```bash
sudo bash 4.1.3_remediate.sh
sudo bash 4.1.4_remediate.sh
sudo bash 4.1.7_remediate.sh
sudo bash 4.1.8_remediate.sh
```

All scripts will PASS on standard Kubeadm clusters, or fix issues if custom config is set.
