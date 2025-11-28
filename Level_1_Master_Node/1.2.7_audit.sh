#!/bin/bash
# CIS Benchmark: 1.2.7
# Title: Ensure that the --authorization-mode argument includes Node (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.7..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -- \"--authorization-mode=.*(,|$)Node(,|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -- "--authorization-mode=.*(,|$)Node(,|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --authorization-mode includes Node")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --authorization-mode does NOT include Node")
		echo "[FAIL_REASON] Check Failed: --authorization-mode does NOT include Node"
		echo "[FIX_HINT] Run remediation script: 1.2.7_remediate.sh"
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
