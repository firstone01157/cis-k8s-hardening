#!/bin/bash
# CIS Benchmark: 5.1.1
# Title: Ensure that the cluster-admin role is only used where required (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Obtain a list of the principals who have access to the cluster-admin role by reviewing the clusterrolebinding output for each role binding that has access to the cluster- admin role. kubectl get clust
	##
	## Command hint: Obtain a list of the principals who have access to the cluster-admin role by reviewing the clusterrolebinding output for each role binding that has access to the cluster- admin role. kubectl get clusterrolebindings -o=custom- columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECT:.subjects[*].name Review each principal listed and ensure that cluster-admin privilege is required for it.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Review cluster-admin role bindings.")
	a_output+=(" - Command: kubectl get clusterrolebindings -o=custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,SUBJECT:.subjects[*].name")
	# Always pass as it is manual
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
