#!/bin/bash
# CIS Benchmark: 4.2.3
# Title: Ensure that the --client-ca-file argument is set as appropriate (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.3..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o \" --config=[^ ]*\" | awk -F= '{print $2}' | head -n 1)"
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o " --config=[^ ]*" | awk -F= '{print $2}' | head -n 1)
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--client-ca-file(=|\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--client-ca-file(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --client-ca-file is set (Flag)")
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		# Check for authentication: x509: clientCAFile
		echo "[CMD] Executing: if grep -A5 \"authentication:\" \"$config_path\" | grep -A2 \"x509:\" | grep -E -q \"clientCAFile:\"; then"
		if grep -A5 "authentication:" "$config_path" | grep -A2 "x509:" | grep -E -q "clientCAFile:\s*\S+"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: authentication.x509.clientCAFile is set in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: authentication.x509.clientCAFile is NOT set in $config_path")
			echo "[FAIL_REASON] Check Failed: authentication.x509.clientCAFile is NOT set in $config_path"
			echo "[FIX_HINT] Run remediation script: 4.2.3_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --client-ca-file not set and config file not found (Default: missing/insecure)")
		echo "[FAIL_REASON] Check Failed: --client-ca-file not set and config file not found (Default: missing/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.3_remediate.sh"
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
