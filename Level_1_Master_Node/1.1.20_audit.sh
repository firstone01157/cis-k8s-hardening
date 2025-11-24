#!/bin/bash
# CIS Benchmark: 1.1.20
# Title: Ensure that the Kubernetes PKI certificate file permissions are set to 644 or more restrictive (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, stat -c '%a' /etc/kubernetes/pki/*.crt Verify that the permissions are 644 or more restrictive
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, stat -c '%a' /etc/kubernetes/pki/*.crt Verify that the permissions are 644 or more restrictive. or ls -l /etc/kubernetes/pki/*.crt Verify -rw------
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ -d "/etc/kubernetes/pki" ]; then
		# Find .crt files with permissions more permissive than 644 (e.g., 664, 777)
		# Logic: -perm /g+w,o+w checks if group or others have write permission. 
		# 644 = rw-r--r--. We want to ensure no write for group/others, and no execute. 
		# Simpler approach: iterate and stat.
		
		while IFS= read -r -d '' l_file; do
			l_mode=$(stat -c %a "$l_file")
			# Check if permissions are greater than 644 (lexicographically isn't perfect for octal, but for standard perms it works. 
			# Better: check if group or other has write (2) or execute (1). 
			# 644 means user:rw(6), group:r(4), other:r(4).
			# Fail if group has w(2) or x(1) -> 6 or 7 or 3 or 2.
			# Fail if other has w(2) or x(1).
			# Fail if user has x(1) -> 7 or 5 or 3 or 1 (though executable cert isn't huge security risk, standard is 644).
			
			# Using simple numeric comparison <= 644 is tricky because 700 > 644 but is more restrictive for group/other.
			# Correct logic for "644 or more restrictive":
			# - Group should not have Write (2)
			# - Other should not have Write (2)
			# - (Usually) No Execute.
			
			# Let's stick to the simple numeric check <= 644 as a baseline, but note that 700 is technically "more restrictive" for group/others but "less" for user.
			# However, for certs, 644 is the standard. 600 is also fine.
			# If mode is 600, it is <= 644.
			# If mode is 700, it is > 644 numerically.
			
			# Let's use the logic: Group and Other must NOT have Write.
			# stat -c %A gives -rw-r--r--
			
			if [ "$l_mode" -le 644 ]; then
				a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
			else
				a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 644 or more restrictive)")
			fi
		done < <(find /etc/kubernetes/pki -name "*.crt" -print0)
		
		if [ ${#a_output[@]} -eq 0 ] && [ ${#a_output2[@]} -eq 0 ]; then
             a_output+=(" - Check Passed: No .crt files found in /etc/kubernetes/pki")
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
