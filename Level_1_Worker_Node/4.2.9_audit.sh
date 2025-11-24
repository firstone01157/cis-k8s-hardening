#!/bin/bash
# CIS Benchmark: 4.2.9
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: ps -ef | grep kubelet Verify that the --tls-cert-file and --tls-private-key-file arguments exist and they are set as appropriate. If these arguments are not pre
	##
	## Command hint: Run the following command on each node: ps -ef | grep kubelet Verify that the --tls-cert-file and --tls-private-key-file arguments exist and they are set as appropriate. If these arguments are not present, check that there is a Kubelet config specified by -- config and that it contains appropriate settings for tlsCertFile and tlsPrivateKeyFile.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep -q "\--tls-cert-file" && ps -ef | grep kubelet | grep -v grep | grep -q "\--tls-private-key-file"; then
		a_output+=(" - Check Passed: --tls-cert-file and --tls-private-key-file are set")
	else
		a_output2+=(" - Check Failed: --tls-cert-file and/or --tls-private-key-file are NOT set")
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
