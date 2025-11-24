#!/bin/bash
# CIS Benchmark: 4.1.2
# Title: Ensure that the kubelet service file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Automated AAC auditing has been modified to allow CIS-CAT to input a variable for the <PATH>/<FILENAME> of the kubelet service config file. Please set $kubelet_service_config=<PATH> based on the file 
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %U:%G /etc/systemd/system/kubelet.service.d/10-kubeadm.conf Verify that the ownership is set to root:root.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	file_path="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
	if [ -f "$file_path" ]; then
		if stat -c %U:%G "$file_path" | grep -q "root:root"; then
			a_output+=(" - Check Passed: $file_path ownership is root:root")
		else
			a_output2+=(" - Check Failed: $file_path ownership is not root:root")
		fi
	else
		a_output+=(" - Check Passed: $file_path does not exist")
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
