#!/bin/bash
# CIS Benchmark: 1.2.27
# Title: Ensure that the --encryption-provider-config argument is set as appropriate (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.27..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check if argument is present
	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--encryption-provider-config(=|\\s|$)\"; then"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--encryption-provider-config(=|\s|$)"; then
		# Extract the path
		echo "[CMD] Executing: config_path=$(ps -ef | grep kube-apiserver | grep -v grep | grep -oP \'(?<=--encryption-provider-config=)[^ ]+\' | head -n 1)"
		config_path=$(ps -ef | grep kube-apiserver | grep -v grep | grep -oP '(?<=--encryption-provider-config=)[^ ]+' | head -n 1)
		
		if [ -n "$config_path" ] && [ -f "$config_path" ]; then
			# Check for valid providers in the file
			echo "[CMD] Executing: if grep -qE \"providers:|aescbc|secretbox|kms\" \"$config_path\"; then"
			if grep -qE "providers:|aescbc|secretbox|kms" "$config_path"; then
				echo "[INFO] Check Passed"
				a_output+=(" - Check Passed: --encryption-provider-config is set to $config_path and file appears valid")
			else
				echo "[INFO] Check Failed"
				a_output2+=(" - Check Failed: Encryption config file $config_path found but does not appear to contain valid providers")
				echo "[FAIL_REASON] Check Failed: Encryption config file $config_path found but does not appear to contain valid providers"
				echo "[FIX_HINT] Run remediation script: 1.2.27_remediate.sh"
			fi
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: --encryption-provider-config is set but file '$config_path' not found")
			echo "[FAIL_REASON] Check Failed: --encryption-provider-config is set but file '$config_path' not found"
			echo "[FIX_HINT] Run remediation script: 1.2.27_remediate.sh"
		fi
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --encryption-provider-config argument is not set")
		echo "[FAIL_REASON] Check Failed: --encryption-provider-config argument is not set"
		echo "[FIX_HINT] Run remediation script: 1.2.27_remediate.sh"
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
