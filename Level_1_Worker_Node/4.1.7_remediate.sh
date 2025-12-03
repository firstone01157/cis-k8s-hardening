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
