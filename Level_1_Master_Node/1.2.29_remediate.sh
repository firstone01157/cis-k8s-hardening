#!/bin/bash
# CIS Benchmark: 1.2.29
# Title: Ensure that the API Server only makes use of Strong Cryptographic Ciphers
# Level: • Level 1 - Master Node
# Remediation Script - AUTO FIX

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    l_flag="--tls-cipher-suites"
    # ค่ามาตรฐาน CIS (ยาวหน่อยนะครับ)
    l_val="TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256"

    if [ -e "$l_file" ]; then
        cp "$l_file" "$l_file.bak_$(date +%s)"

        if grep -q -- "$l_flag" "$l_file"; then
            # Update existing (ใช้ | เป็น delimiter เพราะใน value มีเครื่องหมายเยอะ)
            sed -i "s|$l_flag=[^ \"]*|$l_flag=$l_val|g" "$l_file"
            a_output+=(" - Remediation applied: Updated existing $l_flag")
        else
            # Insert new
            sed -i "/- kube-apiserver/a \    - $l_flag=$l_val" "$l_file"
            a_output+=(" - Remediation applied: Inserted $l_flag")
        fi
    else
        a_output2+=(" - Remediation failed: $l_file not found")
        return 1
    fi

    if grep -q "$l_flag" "$l_file"; then
        return 0
    else
        return 1
    fi
}

remediate_rule
exit $?