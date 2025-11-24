#!/bin/bash
# CIS Benchmark: 4.1.7
# Title: Ensure that the certificate authorities file permissions are set to 644 or more restrictive (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	client_ca_file=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --client-ca-file=[^ ]*' | awk -F= '{print $2}')
	if [ -z "$client_ca_file" ]; then
		a_output+=(" - Check Passed: --client-ca-file not set")
	else
		if [ -f "$client_ca_file" ]; then
			if stat -c %a "$client_ca_file" | grep -qE '^[0-6][0-4][0-4]$'; then
				a_output+=(" - Check Passed: $client_ca_file permissions are 644 or more restrictive")
			else
				a_output2+=(" - Check Failed: $client_ca_file permissions are not 644 or more restrictive")
			fi
		else
			a_output+=(" - Check Passed: $client_ca_file does not exist")
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
