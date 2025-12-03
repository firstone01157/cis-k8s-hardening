#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true
# Level: • Level 1 - Worker Node

set -x  # Enable debugging
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
    echo "[INFO] Starting check for 4.2.6..."
    local -a a_output a_output2
    a_output=()
    a_output2=()

    echo "[CMD] Executing: config_path=$(kubelet_config_path)"
    local config_path
    config_path=$(kubelet_config_path)
    echo "[DEBUG] config_path = $config_path"

    # Check 1: Look for explicit false flag using safe grep
    echo "[CMD] Checking for --make-iptables-util-chains=false in process..."
    if ps -ef | grep -v grep | grep -F -- "kubelet" | grep -F -q -- "--make-iptables-util-chains=false"; then
        echo "[INFO] Check Failed - Flag set to false"
        a_output2+=(" - Check Failed: --make-iptables-util-chains is explicitly set to false in process flags")
    # Check 2: Look for explicit true flag using safe grep
    elif ps -ef | grep -v grep | grep -F -- "kubelet" | grep -F -q -- "--make-iptables-util-chains=true"; then
        echo "[INFO] Check Passed - Flag set to true"
        a_output+=(" - Check Passed: --make-iptables-util-chains is explicitly set to true in process flags")
    # Check 3: Check config file
    elif [ -f "$config_path" ]; then
        echo "[CMD] Checking config file: grep -F 'makeIPTablesUtilChains: false' '$config_path'"
        if grep -F -q "makeIPTablesUtilChains: false" "$config_path"; then
            echo "[INFO] Check Failed - Config set to false"
            a_output2+=(" - Check Failed: makeIPTablesUtilChains is set to false in $config_path")
        else
            echo "[INFO] Check Passed - Config is true or default"
            a_output+=(" - Check Passed: makeIPTablesUtilChains is true or using default in $config_path")
        fi
    else
        echo "[INFO] Check Passed - Using default (true)"
        a_output+=(" - Check Passed: No config found, using default (true)")
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
RESULT="$?"
exit "${RESULT:-1}"