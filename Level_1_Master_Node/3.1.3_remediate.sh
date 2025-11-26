#!/bin/bash
# CIS Benchmark: 3.1.3
# Title: Bootstrap token authentication should not be used for users
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    l_flag="--enable-bootstrap-token-auth"
    l_val="false"

    if [ -e "$l_file" ]; then
        cp "$l_file" "$l_file.bak_$(date +%s)"

        if grep -q -- "$l_flag" "$l_file"; then
            # Update existing
            sed -i "s/$l_flag=[^ \"]*/$l_flag=$l_val/g" "$l_file"
            a_output+=(" - Remediation applied: Set $l_flag to $l_val")
        else
            # Insert explicitly disabled
            sed -i "/- kube-apiserver/a \    - $l_flag=$l_val" "$l_file"
            a_output+=(" - Remediation applied: Inserted $l_flag=$l_val")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    if grep -q "$l_flag=$l_val" "$l_file"; then
        return 0
    else
        return 1
    fi
}

remediate_rule
exit $?