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
