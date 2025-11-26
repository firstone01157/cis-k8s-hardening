#!/bin/bash
# CIS Benchmark: 1.3.6
# Title: Ensure that the RotateKubeletServerCertificate argument is set to true
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-controller-manager.yaml"
    l_gate_key="RotateKubeletServerCertificate"
    l_gate_val="true"
    
    if [ -e "$l_file" ]; then
        # 1. Backup First
        cp "$l_file" "$l_file.bak_$(date +%s)"

        # 2. Check if Feature Gates flag exists
        if grep -q -- "--feature-gates" "$l_file"; then
            # Case A: --feature-gates exists
            
            # Check if our specific gate exists inside it
            if grep -q "$l_gate_key=" "$l_file"; then
                # If exists but wrong value (e.g. =false), fix it
                if grep -q "$l_gate_key=false" "$l_file"; then
                    sed -i "s/$l_gate_key=false/$l_gate_key=$l_gate_val/g" "$l_file"
                    a_output+=(" - Remediation applied: Changed $l_gate_key to $l_gate_val")
                else
                    a_output+=(" - Remediation not needed: $l_gate_key is already $l_gate_val")
                fi
            else
                # If gate missing, append it to the end of the feature-gates line
                # Regex: match line starting with --feature-gates=..., then replace match (&) with match + string
                sed -i "s/--feature-gates=[^\"]*/&,$l_gate_key=$l_gate_val/" "$l_file"
                a_output+=(" - Remediation applied: Appended $l_gate_key=$l_gate_val to existing feature-gates")
            fi
        else
            # Case B: --feature-gates MISSING -> Insert new line
            # Insert after the binary command
            sed -i "/- kube-controller-manager/a \    - --feature-gates=$l_gate_key=$l_gate_val" "$l_file"
            a_output+=(" - Remediation applied: Inserted new flag --feature-gates=$l_gate_key=$l_gate_val")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    # 3. Verification (Simple grep)
    if grep -q "$l_gate_key=$l_gate_val" "$l_file"; then
        return 0
    else
        a_output2+=(" - Remediation verification failed")
        return 1
    fi
}

remediate_rule
exit $?