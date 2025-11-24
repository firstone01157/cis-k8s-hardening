#!/bin/bash
# CIS Benchmark: 3.2.2
# Title: Ensure that the audit policy covers key security concerns (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	policy_file=$(ps -ef | grep kube-apiserver | grep -v grep | grep -oP '(?<=--audit-policy-file=)[^ ]+')

	if [ -n "$policy_file" ]; then
		if [ -f "$policy_file" ]; then
			# Basic check for key security areas in the policy file
			if grep -q "secrets" "$policy_file" && grep -q "Metadata" "$policy_file"; then
				a_output+=(" - Check Passed: Audit policy file exists and appears to cover secrets metadata.")
			else
				a_output2+=(" - Check Failed: Audit policy file exists but might be missing 'secrets' or 'Metadata' rules.")
			fi
		else
			a_output2+=(" - Check Failed: Audit policy file specified ($policy_file) but does not exist.")
		fi
	else
		a_output2+=(" - Check Failed: --audit-policy-file argument is not set.")
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
