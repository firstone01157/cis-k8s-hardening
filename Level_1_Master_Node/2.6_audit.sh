#!/bin/bash
# CIS Benchmark: 2.6
# Title: Ensure that the --peer-auto-tls argument is not set to true (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 2.6..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep etcd | grep -v grep | grep -E -q \"\\s--peer-auto-tls=true(\\s|$)\"; then"
	if ps -ef | grep etcd | grep -v grep | grep -E -q "\s--peer-auto-tls=true(\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --peer-auto-tls is set to true")
		echo "[FAIL_REASON] Check Failed: --peer-auto-tls is set to true"
		echo "[FIX_HINT] Run remediation script: 2.6_remediate.sh"
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --peer-auto-tls is not set to true")
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
