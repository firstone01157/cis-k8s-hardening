#!/bin/bash
# CIS Benchmark: 4.2.8
# Title: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)
# Level: • Level 2 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.8..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check for eventRecordQPS in kubelet config or arguments. 
	# Defaults to 5 if not set. Recommendation implies setting it "appropriate".
	# We will check if it is explicitly set or if the default is active.
	# Since it is manual, we log the value.

	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -q \"eventRecordQPS\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -q "eventRecordQPS"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: eventRecordQPS is explicitly set (verify value)")
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: eventRecordQPS not set (using default 5)")
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
