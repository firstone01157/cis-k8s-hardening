#!/bin/bash
# CIS Benchmark: 1.2.15
# Title: Ensure that the --profiling argument is set to false (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.15..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Check process arguments
	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--profiling=false(\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--profiling=false(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --profiling is explicitly set to false in process arguments")
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	fi

	# 2. Check manifest file on disk (Fallback)
	manifest="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -f "$manifest" ]; then
		echo "[CMD] Executing: grep for profiling in $manifest"
		if grep -E -q "(--profiling=false|profiling:\s*false)" "$manifest"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: profiling is set to false in $manifest")
			printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
			return 0
		fi
	fi

	echo "[INFO] Check Failed"
	a_output2+=(" - Check Failed: --profiling is not set to false in process or manifest")
	echo "[FAIL_REASON] Check Failed: --profiling is not set to false in process or manifest"
	echo "[FIX_HINT] Run remediation script: 1.2.15_remediate.sh"
	
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
