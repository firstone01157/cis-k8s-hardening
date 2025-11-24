#!/bin/bash
# CIS Benchmark: 1.1.21
# Title: Ensure that the Kubernetes PKI key file permissions are set to 600 (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, stat -c '%a' /etc/kubernetes/pki/*.key Verify that the permissions are 600 or more restrictive
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, stat -c '%a' /etc/kubernetes/pki/*.key Verify that the permissions are 600 or more restrictive. or ls -l /etc/kubernetes/pki/*.key Verify that the permissions are -rw------
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ -d "/etc/kubernetes/pki" ]; then
		while IFS= read -r -d '' l_file; do
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 600 ]; then
				a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
			else
				a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)")
			fi
		done < <(find /etc/kubernetes/pki -name "*.key" -print0)
		
		if [ ${#a_output[@]} -eq 0 ] && [ ${#a_output2[@]} -eq 0 ]; then
             a_output+=(" - Check Passed: No .key files found in /etc/kubernetes/pki")
        fi
	else
		a_output+=(" - Check Passed: /etc/kubernetes/pki directory not found")
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
