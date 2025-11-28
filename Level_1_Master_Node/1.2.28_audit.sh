#!/bin/bash
# CIS Benchmark: 1.2.28
# Title: Ensure that encryption providers are appropriately configured (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.28..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--encryption-provider-config(=|\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--encryption-provider-config(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --encryption-provider-config is set (Manual verification of config file content required)")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --encryption-provider-config is not set")
		echo "[FAIL_REASON] Check Failed: --encryption-provider-config is not set"
		echo "[FIX_HINT] Run remediation script: 1.2.28_remediate.sh"
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
