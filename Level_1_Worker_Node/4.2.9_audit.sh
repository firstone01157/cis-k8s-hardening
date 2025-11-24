#!/bin/bash
# CIS Benchmark: 4.2.9
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--tls-cert-file" && ps -ef | grep kubelet | grep -v grep | grep -q "\--tls-private-key-file"; then
		a_output+=(" - Check Passed: --tls-cert-file and --tls-private-key-file are set")
	else
		# Check config file
		config_file="/var/lib/kubelet/config.yaml"
		if [ -f "$config_file" ] && grep -q "tlsCertFile" "$config_file" && grep -q "tlsPrivateKeyFile" "$config_file"; then
			a_output+=(" - Check Passed: tlsCertFile and tlsPrivateKeyFile are set in $config_file")
		else
			a_output2+=(" - Check Failed: --tls-cert-file and/or --tls-private-key-file are NOT set")
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
