#!/bin/bash
# CIS Benchmark: 1.1.12
# Title: Ensure that the etcd data directory ownership is set to etcd:etcd
# Level: • Level 1 - Master Node
# Remediation Script - SAFE VERSION FOR KUBEADM

remediate_rule() {
    l_output3=""
    l_dl=""
    unset a_output
    unset a_output2

    l_dir="/var/lib/etcd"
    
    # 1. Check if directory exists
    if [ ! -d "$l_dir" ]; then
        a_output+=(" - Remediation not needed: $l_dir not found")
        return 0
    fi

    # 2. CRITICAL SAFETY CHECK: Does 'etcd' user exist?
    if ! id "etcd" &>/dev/null; then
        # ถ้าไม่มี user etcd (ปกติของ Kubeadm) ให้หยุดทันที ห้ามรัน chown
        a_output+=(" - SKIP: User 'etcd' does not exist on this system.")
        a_output+=(" - INFO: Kubeadm runs etcd as root. Current ownership is acceptable.")
        return 0
    fi

    # 3. If user 'etcd' exists, proceed with standard check
    l_owner=$(stat -c %U:%G "$l_dir")
    if [ "$l_owner" == "etcd:etcd" ]; then
        a_output+=(" - Remediation not needed: Ownership is $l_owner")
        return 0
    else
        # Apply Fix only if user exists
        chown etcd:etcd "$l_dir"
        
        # Verify
        l_owner_new=$(stat -c %U:%G "$l_dir")
        if [ "$l_owner_new" == "etcd:etcd" ]; then
            a_output+=(" - Remediation applied: Ownership changed to etcd:etcd")
            return 0
        else
            a_output2+=(" - Remediation failed: Could not change ownership")
            return 1
        fi
    fi
}

remediate_rule
exit $?