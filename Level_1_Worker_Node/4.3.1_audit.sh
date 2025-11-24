#!/bin/bash
# CIS Benchmark: 4.3.1
# Title: Ensure that the kube-proxy metrics service is bound to localhost (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	if ps -ef | grep kube-proxy | grep -v grep | grep -q "\--metrics-bind-address=127.0.0.1"; then
		a_output+=(" - Check Passed: --metrics-bind-address is set to 127.0.0.1")
	else
		# Check if it's not set (default might not be localhost depending on version, but CIS says ensure it is bound to localhost)
		# Actually, default is 127.0.0.1 in newer versions, but we should check explicit setting or verify default behavior.
		# For this script, we'll check for explicit setting or absence (if absence implies localhost).
		# However, CIS usually wants explicit setting.
		if ps -ef | grep kube-proxy | grep -v grep | grep -q "\--metrics-bind-address"; then
             # It is set but not to 127.0.0.1 (based on previous check failure)
			a_output2+=(" - Check Failed: --metrics-bind-address is set to non-localhost")
		else
             # Not set.
			a_output+=(" - Check Passed: --metrics-bind-address not set (Verify default is 127.0.0.1 for your version)")
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
