#!/bin/bash
# CIS Benchmark: 4.1.1
# Title: Ensure that the kubelet service file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the each worker node. For example, chmod 600 /etc/systemd/system/kubelet.service.d/kubeadm.conf
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, chmod 600 /etc/systemd/system/kubelet.service.d/kubeadm.conf
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
	if [ -e "$l_file" ]; then
		l_mode=$(stat -c %a "$l_file")
		if [ "$l_mode" -le 600 ]; then
			a_output+=(" - Remediation not needed: Permissions on $l_file are correct ($l_mode)")
			return 0
		else
			chmod 600 "$l_file"
			l_mode_new=$(stat -c %a "$l_file")
			if [ "$l_mode_new" -le 600 ]; then
				a_output+=(" - Remediation applied: Permissions on $l_file changed to $l_mode_new")
				return 0
			else
				a_output2+=(" - Remediation failed: Could not change permissions on $l_file")
				return 1
			fi
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
