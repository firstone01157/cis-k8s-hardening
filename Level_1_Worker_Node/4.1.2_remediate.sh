#!/bin/bash
# CIS Benchmark: 4.1.2
# Title: Ensure that the kubelet service file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	file_path="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
	if [ -f "$file_path" ]; then
		chown root:root "$file_path"
		a_output+=(" - Remediation applied: Set ownership of $file_path to root:root")
		return 0
	else
		a_output+=(" - Remediation skipped: $file_path does not exist")
		return 0
	fi
}

remediate_rule
exit $?
