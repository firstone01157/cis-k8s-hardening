#!/bin/bash
# CIS Benchmark: 4.2.14
# Title: Ensure that the --seccomp-default parameter is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.14..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP \'(?<=--config=)[^ ]+\' | head -n 1)"
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP '(?<=--config=)[^ ]+' | head -n 1)
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--seccomp-default=true(\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--seccomp-default=true(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --seccomp-default is set to true (Flag)")
	echo "[CMD] Executing: elif ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--seccomp-default=false(\\s|$)\"; then"
	elif ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--seccomp-default=false(\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --seccomp-default is set to false (Flag)")
		echo "[FAIL_REASON] Check Failed: --seccomp-default is set to false (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.14_remediate.sh"
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Executing: if grep -E -q \"seccompDefault:\\s*true\" \"$config_path\"; then"
		if grep -E -q "seccompDefault:\s*true" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: seccompDefault is set to true in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: seccompDefault is NOT set to true in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: seccompDefault is NOT set to true in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.14_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --seccomp-default not set and config file not found (Default: false/insecure)")
		echo "[FAIL_REASON] Check Failed: --seccomp-default not set and config file not found (Default: false/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.14_remediate.sh"
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
