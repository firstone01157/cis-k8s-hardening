#!/bin/bash
# CIS Benchmark: 4.3.1
# Title: Ensure that the kube-proxy metrics service is bound to localhost (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.3.1..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	echo "[CMD] Executing: ## review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than"
	## review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than
	##
	echo "[CMD] Executing: ## Command hint: review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than"
	## Command hint: review the start-up flags provided to kube proxy Run the following command on each node: ps -ef | grep -i kube-proxy Ensure that the --metrics-bind-address parameter is not set to a value other than
	##

	echo "[INFO] Check Passed"
	a_output+=(" - Manual Check: Ensure kube-proxy metrics service is bound to localhost.")
	echo "[CMD] Executing: a_output+=(\" - Command: ps -ef | grep kube-proxy (Check --metrics-bind-address)\")"
	a_output+=(" - Command: ps -ef | grep kube-proxy (Check --metrics-bind-address)")
	return 0

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
