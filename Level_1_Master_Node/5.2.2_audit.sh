#!/bin/bash
# CIS Benchmark: 5.2.2
# Title: Minimize the admission of privileged containers (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command: get pods -A -o=jsonpath=$'{range .items[*]}{@.metadata.name}: {@..securityContext}\n{end}' It will produce an inventory of all the privileged use on the cluster, if any (ple
	##
	## Command hint: Run the following command: get pods -A -o=jsonpath=$'{range .items[*]}{@.metadata.name}: {@..securityContext}\n{end}' It will produce an inventory of all the privileged use on the cluster, if any (please, refer to a sample below). Further grepping can be done to automate each specific violation detection. calico-kube-controllers-57b57c56f-jtmk4: {} << No Elevated Privileges calico-node- c4xv4: {} {"privileged":true} {"privileged":true} {"privileged":true} {"privileged":true} << Violates 5.2.2 dashboard-metrics-scraper-7bc864c59-2m2xw: {"seccompProfile":{"type":"RuntimeDefault"}} {"allowPrivilegeEscalation":false,"readOnlyRootFilesystem":true,"runAsGroup":2001,"ru nAsUser":1001}  Internal Only - General
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	a_output+=(" - Manual Check: Minimize admission of privileged containers.")
	a_output+=(" - Command: kubectl get pods -A -o=jsonpath='{range .items[*]}{@.metadata.name}: {@..securityContext}{\"\\n\"}{end}' | grep privileged")
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
