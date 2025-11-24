#!/bin/bash
# CIS Benchmark: 4.1.10
# Title: If the kubelet config.yaml configuration file is being used validate file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	kubelet_config_yaml=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --config=[^ ]*' | awk -F= '{print $2}')
	[ -z "$kubelet_config_yaml" ] && kubelet_config_yaml="/var/lib/kubelet/config.yaml"
	
	if [ -f "$kubelet_config_yaml" ]; then
		if stat -c %U:%G "$kubelet_config_yaml" | grep -q "root:root"; then
			a_output+=(" - Check Passed: $kubelet_config_yaml ownership is root:root")
		else
			a_output2+=(" - Check Failed: $kubelet_config_yaml ownership is not root:root")
		fi
	else
		a_output+=(" - Check Passed: $kubelet_config_yaml does not exist")
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
