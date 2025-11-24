#!/bin/bash
# CIS Benchmark: 1.2.30
# Title: Ensure that the --service-account-extend-token-expiration parameter is set to false (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml on the Control Plane node and set the --service-account-extend-token-expiration parameter to false. --service-a
	##
	## Command hint: Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml on the Control Plane node and set the --service-account-extend-token-expiration parameter to false. --service-account-extend-token-expiration=false
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	l_file="/etc/kubernetes/manifests/kube-apiserver.yaml"
	if [ -e "$l_file" ]; then
		if grep -q "\--service-account-extend-token-expiration" "$l_file"; then
			# Ensure it is set to false
			sed -i 's/--service-account-extend-token-expiration=[^ "]*/--service-account-extend-token-expiration=false/g' "$l_file"
			a_output+=(" - Remediation applied: --service-account-extend-token-expiration set to false in $l_file")
			return 0
		else
			# If missing, default is true (bad). Add it.
			# Adding flags is tricky with sed. I'll warn.
			a_output2+=(" - Remediation required: --service-account-extend-token-expiration missing in $l_file. Please add '--service-account-extend-token-expiration=false' manually.")
			return 1
		fi
	else
		a_output+=(" - Remediation not needed: $l_file not found")
		return 0
	fi
}

remediate_rule
exit $?
