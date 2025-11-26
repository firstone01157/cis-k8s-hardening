#!/bin/bash
# CIS Benchmark: 1.2.3
# Title: Ensure that the DenyServiceExternalIPs is set
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    l_plugin="DenyServiceExternalIPs"

    if [ -e "$l_file" ]; then
        cp "$l_file" "$l_file.bak_$(date +%s)"

        if grep -q -- "--enable-admission-plugins" "$l_file"; then
            if grep -q "$l_plugin" "$l_file"; then
                a_output+=(" - Remediation not needed: $l_plugin is present")
            else
                # Append to existing list
                sed -i "s/--enable-admission-plugins=[^\"]*/&,$l_plugin/" "$l_file"
                a_output+=(" - Remediation applied: Appended $l_plugin")
            fi
        else
            # Insert new line (with NodeRestriction as base)
            sed -i "/- kube-apiserver/a \    - --enable-admission-plugins=NodeRestriction,$l_plugin" "$l_file"
            a_output+=(" - Remediation applied: Inserted new flag")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    if grep -q "$l_plugin" "$l_file"; then
        return 0
    else
        a_output2+=(" - Remediation verification failed")
        return 1
    fi
}

remediate_rule
exit $?