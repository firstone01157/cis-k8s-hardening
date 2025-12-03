#!/bin/bash
# CIS Benchmark: 4.1.6
# Title: Ensure that the --kubeconfig kubelet.conf file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
    echo "[INFO] Starting check for 4.1.6..."
    l_dl=""
    unset a_output
    unset a_output2

    echo "[CMD] Executing: kubelet_config=$(kubelet_kubeconfig_path)"
    kubelet_config=$(kubelet_kubeconfig_path)

    if [ -f "$kubelet_config" ]; then
        echo "[CMD] Executing: if stat -c %U:%G \"$kubelet_config\" | grep -q \"root:root\"; then"
        if stat -c %U:%G "$kubelet_config" | grep -q "root:root"; then
            echo "[INFO] Check Passed"
            a_output+=(" - Check Passed: $kubelet_config ownership is root:root")
        else
            echo "[INFO] Check Failed"
            a_output2+=(" - Check Failed: $kubelet_config ownership is not root:root")
            echo "[FAIL_REASON] Check Failed: $kubelet_config ownership is not root:root"
            echo "[FIX_HINT] Run remediation script: 4.1.6_remediate.sh"
        fi
    else
        echo "[INFO] Check Passed"
        a_output+=(" - Check Passed: $kubelet_config does not exist")
    fi

    if [ "${#a_output2[@]}" -le 0 ]; then
        printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
        return 0
    else
        printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
        [ "${#a_output[@]}" -gt 0 ] && printf '%s\n' "- Correctly set:" "${a_output[@]}"
        return 1
    fi
}

audit_rule
exit $?
