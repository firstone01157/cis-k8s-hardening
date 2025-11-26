#!/bin/bash
# CIS Benchmark: 1.2.28
# Title: Ensure that encryption providers are appropriately configured
# Level: • Level 1 - Master Node
# Remediation Script - CHECKER & GUIDANCE MODE

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_apiserver="/etc/kubernetes/manifests/kube-apiserver.yaml"
    # Config file path (Same as defined in 1.2.27)
    l_config="/etc/kubernetes/pki/encryption-config.yaml"

    # -------------------------------------------------------------------------
    # [TH] คำชี้แจง / Explanation:
    # สคริปต์ข้อนี้ (1.2.28) ถูกออกแบบมาให้เป็นตัว "ตรวจสอบ (Checker)" เท่านั้น ไม่ได้สั่งแก้ Auto
    # สาเหตุที่มีคำสั่งน้อย: เพราะการตั้งค่า Encryption Provider มีความซับซ้อนและเสี่ยงข้อมูลหาย 
    # หากต้องการแก้ไข (เช่น เปลี่ยนจาก identity เป็น aescbc) ต้องทำด้วยมือผ่านไฟล์ Config โดยตรง
    #
    # [EN] Description:
    # This script (1.2.28) is designed to act as a "Checker", avoiding automatic risks.
    # Reason for few commands: Encryption Provider configuration is complex and risky (data loss).
    # Remediation must be done manually by editing the configuration file directly.
    #
    # Target File to Edit: /etc/kubernetes/pki/encryption-config.yaml
    # -------------------------------------------------------------------------

    if [ -e "$l_apiserver" ]; then
        # 1. Check if flag is present (Prerequisite from 1.2.27)
        if grep -q -- "--encryption-provider-config" "$l_apiserver"; then
            
            # 2. Check if the config file actually exists
            if [ -f "$l_config" ]; then
                # 3. Validate basic structure
                if grep -q "kind: EncryptionConfiguration" "$l_config"; then
                    a_output+=(" - OK: Encryption config file found at $l_config")
                    a_output+=(" - INFO: Current provider configuration is valid.")
                    a_output+=(" - To enable strong encryption (aescbc), please edit $l_config manually.")
                else
                    a_output2+=(" - Remediation Required: File $l_config is invalid or empty.")
                    a_output2+=(" - Action: Edit $l_config to have valid EncryptionConfiguration structure.")
                fi
            else
                a_output2+=(" - Remediation Required: Config file missing at $l_config")
                a_output2+=(" - Action: Run '1.2.27_remediate.sh' first to generate the default safe config.")
            fi
        else
            a_output2+=(" - Remediation Required: Flag --encryption-provider-config is not set in API Server.")
            a_output2+=(" - Action: Run '1.2.27_remediate.sh' to enable the flag.")
        fi
    else
        a_output+=(" - Remediation not needed: API Server manifest not found")
    fi

    if [ "${#a_output2[@]}" -le 0 ]; then
        return 0
    else
        # Print guidance for the user
        printf '%s\n' "${a_output2[@]}"
        return 1
    fi
}

remediate_rule
exit $?