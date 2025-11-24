#!/bin/bash
# CIS Benchmark: 4.2.10
# Title: Ensure that the --rotate-certificates argument is not set to false (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that the RotateKubeletServerCertificate argument is not present, or is set to true. If the RotateKubeletServerCertificate argument 
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that the RotateKubeletServerCertificate argument is not present, or is set to true. If the RotateKubeletServerCertificate argument is not present, verify that if there is a Kubelet config file specified by --config, that file does not contain RotateKubeletServerCertificate: false.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--rotate-certificates=false"; then
		a_output2+=(" - Check Failed: --rotate-certificates is set to false")
	else
		a_output+=(" - Check Passed: --rotate-certificates is NOT set to false")
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
