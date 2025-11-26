#!/bin/bash
# CIS Benchmark: 1.2.11
# Title: Ensure that the admission control plugin AlwaysPullImages is set
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    l_plugin="AlwaysPullImages"

    if [ -e "$l_file" ]; then
        # 1. Backup First
        cp "$l_file" "$l_file.bak_$(date +%s)"

        # 2. Check & Apply
        if grep -q -- "--enable-admission-plugins" "$l_file"; then
            # Case A: Flag exists
            if grep -q "$l_plugin" "$l_file"; then
                a_output+=(" - Remediation not needed: $l_plugin is already present")
            else
                # Append plugin to the end of the list
                sed -i "s/--enable-admission-plugins=[^\"]*/&,$l_plugin/" "$l_file"
                a_output+=(" - Remediation applied: Appended $l_plugin to --enable-admission-plugins")
            fi
        else
            # Case B: Flag MISSING -> Insert new line
            # We add NodeRestriction as a safe default base along with the required plugin
            sed -i "/- kube-apiserver/a \    - --enable-admission-plugins=NodeRestriction,$l_plugin" "$l_file"
            a_output+=(" - Remediation applied: Inserted new flag --enable-admission-plugins=NodeRestriction,$l_plugin")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    # 3. Verify
    if grep -q "$l_plugin" "$l_file"; then
        return 0
    else
        a_output2+=(" - Remediation verification failed")
        return 1
    fi
}

remediate_rule
exit $?