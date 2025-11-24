#!/bin/bash
# CIS Benchmark: 1.1.13
# Title: Ensure that the default administrative credential file permissions are set to 600 (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command (based on the file location on your system) on the Control Plane node. For example, stat -c %a /etc/kubernetes/admin.conf On Kubernetes version 1.29 and higher run the follow
	##
	## Command hint: Run the following command (based on the file location on your system) on the Control Plane node. For example, stat -c %a /etc/kubernetes/admin.conf On Kubernetes version 1.29 and higher run the following command as well :- stat -c %a /etc/kubernetes/super-admin.conf Verify that the permissions are 600 or more restrictive.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ -e "/etc/kubernetes/admin.conf" ]; then
		l_mode=$(stat -c %a /etc/kubernetes/admin.conf)
		if [ "$l_mode" -le 600 ]; then
			a_output+=(" - Check Passed: Permissions on /etc/kubernetes/admin.conf are $l_mode")
		else
			a_output2+=(" - Check Failed: Permissions on /etc/kubernetes/admin.conf are $l_mode (should be 600 or more restrictive)")
		fi
	else
		a_output+=(" - Check Passed: /etc/kubernetes/admin.conf not found")
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
