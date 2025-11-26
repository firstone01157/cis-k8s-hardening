#!/bin/bash
# CIS Benchmark: 1.2.1
# Title: Ensure that the --anonymous-auth argument is set to false
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    l_flag="--anonymous-auth"
    l_value="false"

    if [ -e "$l_file" ]; then
        # 1. Backup First
        cp "$l_file" "$l_file.bak_$(date +%s)"

        # 2. Check & Apply
        if grep -q -- "$l_flag" "$l_file"; then
            # Case A: Flag exists -> Update value
            sed -i "s/$l_flag=[^ \"]*/$l_flag=$l_value/g" "$l_file"
            a_output+=(" - Remediation applied: Updated existing $l_flag to $l_value")
        else
            # Case B: Flag missing -> Insert new line
            # เทคนิค: แทรกต่อจากบรรทัด command: - kube-apiserver
            sed -i "/- kube-apiserver/a \    - $l_flag=$l_value" "$l_file"
            a_output+=(" - Remediation applied: Inserted new flag $l_flag=$l_value")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    # 3. Verify
    if grep -q -- "$l_flag=$l_value" "$l_file"; then
        return 0
    else
        a_output2+=(" - Remediation verification failed")
        return 1
    fi
}

remediate_rule
exit $?