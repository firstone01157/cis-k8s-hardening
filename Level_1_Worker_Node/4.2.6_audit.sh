#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true
# Level: • Level 1 - Worker Node

audit_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    # 1. Detect Config File
    config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o " --config=[^ ]*" | awk -F= '{print $2}' | head -n 1)
    [ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

    # --- PRIORITY 1: Check Process Flag ---
    # ถ้าใน Process รันด้วย false -> FAIL
    if ps -ef | grep kubelet | grep -v grep | grep -q "\--make-iptables-util-chains=false"; then
        a_output2+=(" - Check Failed: --make-iptables-util-chains is explicitly set to false in process flags")
        
    elif ps -ef | grep kubelet | grep -v grep | grep -q "\--make-iptables-util-chains=true"; then
        a_output+=(" - Check Passed: --make-iptables-util-chains is explicitly set to true in process flags")

    # --- PRIORITY 2: Check Config File ---
    elif [ -f "$config_path" ]; then
        # ถ้าในไฟล์ตั้งเป็น false -> FAIL
        if grep -E -q "makeIPTablesUtilChains:\s*false" "$config_path"; then
            a_output2+=(" - Check Failed: makeIPTablesUtilChains is set to false in $config_path")
        else
            # ถ้าตั้งเป็น true หรือ ไม่มีการตั้งค่าเลย (Default) -> PASS
            a_output+=(" - Check Passed: makeIPTablesUtilChains is true or using default in $config_path")
        fi
    
    # --- PRIORITY 3: Default ---
    else
        # ไม่เจอ Flag และไม่เจอไฟล์ -> Default is true -> PASS
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
exit $?