#!/bin/bash
# CIS Benchmark: 4.2.11
# Title: Verify that the RotateKubeletServerCertificate argument is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep "\--feature-gates" | grep -q "RotateKubeletServerCertificate=true"; then
		a_output+=(" - Check Passed: RotateKubeletServerCertificate is enabled via flags")
	else
		# Check config file
		config_file="/var/lib/kubelet/config.yaml"
		if [ -f "$config_file" ] && grep -q "serverTLSBootstrap: true" "$config_file"; then
			a_output+=(" - Check Passed: serverTLSBootstrap is true in $config_file (implies rotation)")
		else
			a_output2+=(" - Check Failed: RotateKubeletServerCertificate/serverTLSBootstrap is NOT enabled")
		fi
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
