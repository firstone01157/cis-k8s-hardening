#!/bin/bash
# CIS Benchmark: 1.1.19
# Title: Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.1.19..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/etc/kubernetes/pki"
	if [ -d "$l_dir" ]; then
		# Recursively check ownership
		# Finding files/dirs NOT owned by root:root
		# If any output, check failed.
		
		# Using find to list non-compliant files
		l_files=$(find "$l_dir" -not -user root -o -not -group root)
		
		if [ -z "$l_files" ]; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: All files and directories in $l_dir are owned by root:root")
		else
			# Limit output to first few
			l_head=$(echo "$l_files" | head -n 5)
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: Some files/directories in $l_dir are not owned by root:root")
			echo "[FAIL_REASON] Check Failed: Some files/directories in $l_dir are not owned by root:root"
			echo "[FIX_HINT] Run remediation script: 1.1.19_remediate.sh"
			echo "[INFO] Check Failed"
			a_output2+=("   Examples: $l_head ...")
		fi
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: $l_dir not found")
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
