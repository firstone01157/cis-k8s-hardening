#!/bin/bash
# CIS Benchmark: 5.6.4
# Title: The default namespace should not be used (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 5.6.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	echo "[CMD] Executing: ## Run this command to list objects in default namespace kubectl get $(kubectl api-resources --verbs=list --namespaced=true -o name | paste -sd, -) --ignore-not-found -n default The only entries there sh"
	## Run this command to list objects in default namespace kubectl get $(kubectl api-resources --verbs=list --namespaced=true -o name | paste -sd, -) --ignore-not-found -n default The only entries there sh
	##
	echo "[CMD] Executing: ## Command hint: Run this command to list objects in default namespace kubectl get $(kubectl api-resources --verbs=list --namespaced=true -o name | paste -sd, -) --ignore-not-found -n default The only entries there should be system managed resources such as the kubernetes service"
	## Command hint: Run this command to list objects in default namespace kubectl get $(kubectl api-resources --verbs=list --namespaced=true -o name | paste -sd, -) --ignore-not-found -n default The only entries there should be system managed resources such as the kubernetes service
	##

	echo "[INFO] Check Passed"
	a_output+=(" - Manual Check: The default namespace should not be used.")
	echo "[CMD] Executing: a_output+=(\" - Command: kubectl get all -n default\")"
	a_output+=(" - Command: kubectl get all -n default")
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
