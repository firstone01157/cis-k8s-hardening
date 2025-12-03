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
