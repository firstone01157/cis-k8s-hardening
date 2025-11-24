#!/bin/bash
# CIS Benchmark: 1.1.10
# Title: Ensure that the Container Network Interface file ownership is set to root:root (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_cni_dir="/etc/cni/net.d"
	if [ -d "$l_cni_dir" ]; then
		while IFS= read -r -d '' l_file; do
			l_owner=$(stat -c %U:%G "$l_file")
			if [ "$l_owner" == "root:root" ]; then
				a_output+=(" - Check Passed: Ownership on $l_file is $l_owner")
			else
				a_output2+=(" - Check Failed: Ownership on $l_file is $l_owner (should be root:root)")
			fi
		done < <(find "$l_cni_dir" -maxdepth 1 -type f -print0)

		if [ ${#a_output[@]} -eq 0 ] && [ ${#a_output2[@]} -eq 0 ]; then
             a_output+=(" - Check Passed: No CNI configuration files found in $l_cni_dir")
        fi
	else
		a_output+=(" - Check Passed: $l_cni_dir directory not found")
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
