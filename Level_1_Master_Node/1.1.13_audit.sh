#!/bin/bash
# CIS Benchmark: 1.1.13
# Title: Ensure that the default administrative credential file permissions are set to 600 (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.1.13..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	for l_file in "/etc/kubernetes/admin.conf" "/etc/kubernetes/super-admin.conf"; do
		if [ -e "$l_file" ]; then
			echo "[CMD] Executing: l_mode=$(stat -c %a \"$l_file\")"
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 600 ]; then
				echo "[INFO] Check Passed"
				a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
			else
				echo "[INFO] Check Failed"
				a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)")
				echo "[FAIL_REASON] Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)"
				echo "[FIX_HINT] Run remediation script: 1.1.13_remediate.sh"
			fi
		else
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $l_file not found")
		fi
	done

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
