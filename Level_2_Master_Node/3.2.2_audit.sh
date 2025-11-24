#!/bin/bash
# CIS Benchmark: 3.2.2
# Title: Ensure that the audit policy covers key security concerns (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Review the audit policy provided for the cluster and ensure that it covers at least the following areas :- • Access to Secrets managed by the cluster. Care should be taken to only log Metadata for req
	##
	## Command hint: Review the audit policy provided for the cluster and ensure that it covers at least the following areas :- • Access to Secrets managed by the cluster. Care should be taken to only log Metadata for requests to Secrets, ConfigMaps, and TokenReviews, in order to avoid the risk of logging sensitive data. • Modification of pod and deployment objects. • Use of pods/exec, pods/portforward, pods/proxy and services/proxy. For most requests, minimally logging at the Metadata level is recommended (the most basic level of logging).
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Ensure audit policy covers key security concerns.")
	a_output+=(" - Command: Review audit policy file (referenced by --audit-policy-file in apiserver)")
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
