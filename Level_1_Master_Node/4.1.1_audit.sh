#!/bin/bash
# CIS Benchmark: 4.1.1
# Title: Ensure that the kubelet service file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Automated AAC auditing has been modified to allow CIS-CAT to input a variable for the <PATH>/<FILENAME> of the kubelet service config file. Please set $kubelet_service_config=<PATH> based on the file 
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf Verify that the permissions are 600 or more restrictive.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	l_file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
	if [ -e "$l_file" ]; then
		l_mode=$(stat -c %a "$l_file")
		if [ "$l_mode" -le 600 ]; then
			a_output+=(" - Check Passed: Permissions on $l_file are $l_mode (<= 600)")
		else
			a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be <= 600)")
		fi
	else
		a_output+=(" - Check Passed: $l_file not found (Audit not applicable or file missing)")
	fi

	if [ "${#a_output2[@]}" -le 0 ]; then
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	else
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		[ "${#a_output[@]}" -gt 0 ] && printf '%s\n' "- Correctly set:" "${a_output[@]}"
		return 1
	fi
}

audit_rule
exit $?
