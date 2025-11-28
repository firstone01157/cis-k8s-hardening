#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/var/lib/kubelet/config.yaml"
    
    if [ -e "$l_file" ]; then
        # Backup
        cp "$l_file" "$l_file.bak_$(date +%s)"
        
        # Check if explicitly set to false
        if grep -q "makeIPTablesUtilChains:\s*false" "$l_file"; then
            # Change false to true
            sed -i 's/makeIPTablesUtilChains:\s*false/makeIPTablesUtilChains: true/' "$l_file"
            a_output+=(" - Remediation applied: Changed makeIPTablesUtilChains to true")
        else
            # If not present, we can either add it or verify it's not false.
            # Since default is true, removing 'false' is enough, or adding 'true' explicitly.
            if ! grep -q "makeIPTablesUtilChains:" "$l_file"; then
                 # Optional: Explicitly add it if missing (not strictly required as default is true)
                 # echo "makeIPTablesUtilChains: true" >> "$l_file"
                 a_output+=(" - Remediation not needed: using default (true)")
            else
                 a_output+=(" - Remediation not needed: already set to true")
            fi
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi
    
    # Warn about restart
    echo "[INFO] Action Required: Run 'systemctl daemon-reload && systemctl restart kubelet' to apply changes."

    return 0
}

remediate_rule
exit $?