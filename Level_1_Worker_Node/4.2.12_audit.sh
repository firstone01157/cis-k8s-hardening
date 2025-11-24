#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--tls-cipher-suites"; then
		a_output+=(" - Check Passed: --tls-cipher-suites is set")
	else
		# Check config file
		config_file="/var/lib/kubelet/config.yaml"
		if [ -f "$config_file" ] && grep -q "tlsCipherSuites" "$config_file"; then
			a_output+=(" - Check Passed: tlsCipherSuites is set in $config_file")
		else
			a_output2+=(" - Check Failed: --tls-cipher-suites is NOT set")
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
