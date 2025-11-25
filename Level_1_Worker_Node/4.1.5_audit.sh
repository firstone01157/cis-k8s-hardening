#!/bin/bash
# CIS Benchmark: 4.1.5
# Title: Ensure that the --kubeconfig kubelet.conf file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Automated AAC auditing has been modified to allow CIS-CAT to input a variable for the <PATH>/<FILENAME> of the kubelet config file. Please set $kubelet_config=<PATH> based on the file location on your
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %a /etc/kubernetes/kubelet.conf Verify that the ownership is set to root:root.Verify that the permissions are 600 or more restrictive.
	##

	kubelet_config=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	[ -z "$kubelet_config" ] && kubelet_config="/etc/kubernetes/kubelet.conf"
	
	if [ -f "$kubelet_config" ]; then
		if stat -c %a "$kubelet_config" | grep -qE '^[0-6]00$'; then
			a_output+=(" - Check Passed: $kubelet_config permissions are 600 or more restrictive")
		else
			a_output2+=(" - Check Failed: $kubelet_config permissions are not 600 or more restrictive")
		fi
	else
		a_output+=(" - Check Passed: $kubelet_config does not exist")
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
