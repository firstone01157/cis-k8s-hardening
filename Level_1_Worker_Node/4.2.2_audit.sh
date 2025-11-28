#!/bin/bash
# CIS Benchmark: 4.2.2
# Title: Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.2..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o \" --config=[^ ]*\" | awk -F= '{print $2}' | head -n 1)"
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o " --config=[^ ]*" | awk -F= '{print $2}' | head -n 1)
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--authorization-mode=.*AlwaysAllow\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--authorization-mode=.*AlwaysAllow"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --authorization-mode contains AlwaysAllow (Flag)")
		echo "[FAIL_REASON] Check Failed: --authorization-mode contains AlwaysAllow (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.2_remediate.sh"
	echo "[CMD] Executing: elif ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--authorization-mode=Webhook(\\s|$)\"; then"
	elif ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--authorization-mode=Webhook(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --authorization-mode is set to Webhook (Flag)")
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		# Check for authorization: mode: Webhook
		echo "[CMD] Executing: if grep -A5 \"authorization:\" \"$config_path\" | grep -E -q \"mode:\\s*Webhook\"; then"
		if grep -A5 "authorization:" "$config_path" | grep -E -q "mode:\s*Webhook"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: authorization.mode is set to Webhook in $config_path")
		echo "[CMD] Executing: elif grep -A5 \"authorization:\" \"$config_path\" | grep -E -q \"mode:\\s*AlwaysAllow\"; then"
		elif grep -A5 "authorization:" "$config_path" | grep -E -q "mode:\s*AlwaysAllow"; then
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: authorization.mode is set to AlwaysAllow in $config_path")
			echo "[FAIL_REASON] Check Failed: authorization.mode is set to AlwaysAllow in $config_path"
			echo "[FIX_HINT] Run remediation script: 4.2.2_remediate.sh"
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: authorization.mode is NOT set to Webhook in $config_path")
			echo "[FAIL_REASON] Check Failed: authorization.mode is NOT set to Webhook in $config_path"
			echo "[FIX_HINT] Run remediation script: 4.2.2_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --authorization-mode not set and config file not found (Default: AlwaysAllow/insecure)")
		echo "[FAIL_REASON] Check Failed: --authorization-mode not set and config file not found (Default: AlwaysAllow/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.2_remediate.sh"
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
