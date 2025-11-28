#!/bin/bash
# CIS Benchmark: 1.2.3
# Title: Ensure that the DenyServiceExternalIPs is set (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.3..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E \"\\s--enable-admission-plugins(=|\\s|$)\" | grep -q \"DenyServiceExternalIPs\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E "\s--enable-admission-plugins(=|\s|$)" | grep -q "DenyServiceExternalIPs"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: DenyServiceExternalIPs is enabled")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: DenyServiceExternalIPs is NOT enabled")
		echo "[FAIL_REASON] Check Failed: DenyServiceExternalIPs is NOT enabled"
		echo "[FIX_HINT] Run remediation script: 1.2.3_remediate.sh"
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
