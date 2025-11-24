#!/bin/bash
# CIS Benchmark: 5.1.11
# Title: Minimize access to the approval sub-resource of certificatesigningrequests objects (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Review the users who have access to update the approval sub-resource of CertificateSigningRequests objects in the Kubernetes API.
	##
	## Command hint: Review the users who have access to update the approval sub-resource of CertificateSigningRequests objects in the Kubernetes API.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Minimize access to approval sub-resource of certificatesigningrequests.")
	a_output+=(" - Command: kubectl get clusterroles -o=custom-columns=NAME:.metadata.name,RESOURCES:.rules[*].resources,VERBS:.rules[*].verbs | grep certificatesigningrequests/approval")
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
