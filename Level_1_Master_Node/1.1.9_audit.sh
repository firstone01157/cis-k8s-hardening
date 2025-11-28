#!/bin/bash
# CIS Benchmark: 1.1.9
# Title: Ensure that the Container Network Interface file permissions are set to 600 or more restrictive (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.1.9..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_cni_dir="/etc/cni/net.d"
	if [ -d "$l_cni_dir" ]; then
		while IFS= read -r -d '' l_file; do
			echo "[CMD] Executing: l_mode=$(stat -c %a \"$l_file\")"
			l_mode=$(stat -c %a "$l_file")
			if [ "$l_mode" -le 600 ]; then
				echo "[INFO] Check Passed"
				a_output+=(" - Check Passed: Permissions on $l_file are $l_mode")
			else
				echo "[INFO] Check Failed"
				a_output2+=(" - Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)")
				echo "[FAIL_REASON] Check Failed: Permissions on $l_file are $l_mode (should be 600 or more restrictive)"
				echo "[FIX_HINT] Run remediation script: 1.1.9_remediate.sh"
			fi
		done < <(find "$l_cni_dir" -maxdepth 1 -type f \( -name "*.conf" -o -name "*.conflist" -o -name "*.json" \) -print0)
		
		if [ ${#a_output[@]} -eq 0 ] && [ ${#a_output2[@]} -eq 0 ]; then
             echo "[INFO] Check Passed"
             a_output+=(" - Check Passed: No CNI configuration files found in $l_cni_dir")
        fi
	else
		echo "[INFO] Check Passed"
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
