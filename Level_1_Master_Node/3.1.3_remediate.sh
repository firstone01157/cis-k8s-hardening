#!/bin/bash
# CIS Benchmark: 3.1.3
# Title: Bootstrap token authentication should not be used for users (Manual)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Alternative mechanisms provided by Kubernetes such as the use of OIDC should be implemented in place of bootstrap tokens.
	##
	## Command hint: Alternative mechanisms provided by Kubernetes such as the use of OIDC should be implemented in place of bootstrap tokens.
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--enable-bootstrap-token-auth=true" "$l_file"; then
			# Remove it or set to false
			sed -i 's/--enable-bootstrap-token-auth=true/--enable-bootstrap-token-auth=false/g' "$l_file"
			a_output+=(" - Remediation applied: --enable-bootstrap-token-auth set to false in $l_file")
			return 0
		else
			a_output+=(" - Remediation not needed: --enable-bootstrap-token-auth is not set to true in $l_file")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
