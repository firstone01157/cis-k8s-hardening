#!/bin/bash
# CIS Benchmark: 1.2.9
# Title: Ensure that the admission control plugin EventRateLimit is set
# Level: • Level 1 - Master Node
# Remediation Script - SAFE VERSION

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
    # Path ที่เราจะใช้เก็บ Config (มาตรฐาน CIS)
    l_config_file="/etc/kubernetes/admission-control/event-rate-limit.yaml"
    
    # 1. Safety Check: ตรวจว่ามีไฟล์ Config ของ EventRateLimit หรือยัง?
    if [ ! -f "$l_config_file" ]; then
        a_output2+=(" - Safety Stop: Config file $l_config_file is missing.")
        a_output2+=(" - Manual Action: You MUST create this file first before enabling the plugin.")
        # Return 1 เพื่อบอกว่ายังไม่ผ่าน แต่ไม่ทำอะไรพัง
        return 1
    fi

    if [ -e "$l_file" ]; then
        # 2. ถ้ามี Config แล้ว ค่อยแก้ Manifest
        if grep -q "\--enable-admission-plugins" "$l_file"; then
            if grep -q "EventRateLimit" "$l_file"; then
                a_output+=(" - Remediation not needed: EventRateLimit is already present")
            else
                cp "$l_file" "$l_file.bak_$(date +%s)"
                sed -i 's/\(--enable-admission-plugins=[^ ]*\)/\1,EventRateLimit/' "$l_file"
                a_output+=(" - Remediation applied: Appended EventRateLimit")
            fi
        else
             a_output2+=(" - Error: --enable-admission-plugins flag not found")
             return 1
        fi
        
        # 3. เพิ่ม flag ชี้ไปหา Config File ด้วย (ถ้ายังไม่มี)
        if ! grep -q "\--admission-control-config-file" "$l_file"; then
             sed -i "/- kube-apiserver/a \    - --admission-control-config-file=$l_config_file" "$l_file"
             a_output+=(" - Remediation applied: Added --admission-control-config-file path")
        fi
        
    else
        a_output2+=(" - File not found: $l_file")
        return 1
    fi

    return 0
}

remediate_rule
exit $?