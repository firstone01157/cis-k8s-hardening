#!/bin/bash
# CIS Benchmark: 1.2.20
# Title: Ensure that the --request-timeout argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--request-timeout"; then
		a_output+=(" - Check Passed: --request-timeout is set (Manual verification of value required)")
	else
		a_output+=(" - Check Passed: --request-timeout is not set (Default 60s is acceptable if appropriate)")
	fi
    # Note: CSV says "Verify that the --request-timeout argument is either not set or set to an appropriate value."
    # So if it's missing, it's also a PASS typically, unless specific requirement exists. 
    # The default script assumed failing if not set? No, let's follow CSV.
    # Actually, default is 60s. Recommendation is "set as appropriate". 
    # "Verify that the --request-timeout argument is either not set or set to an appropriate value."
    # So actually, it always passes unless there is a specific organizational requirement.
    # I will just log the state.

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
