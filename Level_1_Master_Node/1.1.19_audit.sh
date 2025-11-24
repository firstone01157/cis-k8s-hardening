#!/bin/bash
# CIS Benchmark: 1.1.19
# Title: Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, ls -laR /etc/kubernetes/pki/ Verify that the ownership of all files and directories in this hi
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, ls -laR /etc/kubernetes/pki/ Verify that the ownership of all files and directories in this hierarchy is set to root:root.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ -d "/etc/kubernetes/pki" ]; then
		# Check if any file or directory in /etc/kubernetes/pki is NOT owned by root:root
		if find /etc/kubernetes/pki -not -user root -o -not -group root | grep -q .; then
			a_output2+=(" - Check Failed: Found files or directories in /etc/kubernetes/pki not owned by root:root")
			# Optional: List specific files (limited to first 5 to avoid flooding output)
			while IFS= read -r l_file; do
				a_output2+=("   * $l_file")
			done < <(find /etc/kubernetes/pki -not -user root -o -not -group root | head -n 5)
		else
			a_output+=(" - Check Passed: All files and directories in /etc/kubernetes/pki are owned by root:root")
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
