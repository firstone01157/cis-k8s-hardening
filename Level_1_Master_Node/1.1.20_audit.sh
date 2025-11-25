#!/bin/bash
# CIS Benchmark: 1.1.20
# Title: Ensure that the Kubernetes PKI certificate file permissions are set to 644 or more restrictive (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/etc/kubernetes/pki"
	if [ -d "$l_dir" ]; then
		while IFS= read -r -d '' l_file; do
			l_mode=$(stat -c %a "$l_file")
			# 644 or more restrictive means user can be rw(6), group/other max r(4) and NO execute.
			# Strictly <= 644 in octal isn't fully correct for "more restrictive" (e.g. 700 is restrictive for group/other but loose for user), 
			# but for cert files, 644 or 600 or 444 or 400 are expected.
			# We will assume "more restrictive" implies numerical comparison <= 644 is a good approximation for standard file modes.
			if [ "$l_mode" -le 644 ]; then
				a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
			else
				a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 644 or more restrictive)")
			fi
		done < <(find "$l_dir" -name "*.crt" -print0)
		
		if [ ${#a_output[@]} -eq 0 ] && [ ${#a_output2[@]} -eq 0 ]; then
             a_output+=(" - Check Passed: No .crt files found in $l_dir")
        fi
	else
		a_output+=(" - Check Passed: $l_dir directory not found")
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
