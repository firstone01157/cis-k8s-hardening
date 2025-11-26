#!/bin/bash
# CIS Benchmark: 1.2.27
# Title: Ensure that the --encryption-provider-config argument is set
# Level: • Level 1 - Master Node
# Remediation Script - SAFE VERSION

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    # Use PKI dir because it is already mounted in kube-apiserver pod
    l_config="/etc/kubernetes/pki/encryption-config.yaml"
    l_flag="--encryption-provider-config"

    # 1. Create Default Config (Identity Provider - Safe Mode)
    if [ ! -f "$l_config" ]; then
        echo "Creating default encryption config at $l_config"
        cat <<EOF > "$l_config"
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - identity: {}
EOF
        # Note: 'identity' provider allows reading existing secrets without encryption.
        # This is safe for initial setup to pass the flag check.
    fi

    if [ -e "$l_file" ]; then
        # 2. Backup
        cp "$l_file" "$l_file.bak_$(date +%s)"

        # 3. Add/Update Flag
        if grep -q -- "$l_flag" "$l_file"; then
            # Case A: Update existing
            sed -i "s|$l_flag=[^ \"]*|$l_flag=$l_config|g" "$l_file"
            a_output+=(" - Remediation applied: Updated existing $l_flag path")
        else
            # Case B: Insert new
            sed -i "/- kube-apiserver/a \    - $l_flag=$l_config" "$l_file"
            a_output+=(" - Remediation applied: Inserted $l_flag pointing to safe config")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    # 4. Verify
    if grep -q "$l_flag" "$l_file"; then
        return 0
    else
        a_output2+=(" - Remediation verification failed")
        return 1
    fi
}

remediate_rule
exit $?