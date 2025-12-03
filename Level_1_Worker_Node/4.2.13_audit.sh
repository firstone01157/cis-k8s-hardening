#!/bin/bash
# CIS Benchmark: 4.2.13
# Title: Ensure that a limit is set on pod PIDs (Manual)
# Level: • Level 1 - Worker Node

set -x  # Enable debugging
set -euo pipefail

audit_rule() {
	echo "[INFO] Starting check for 4.2.13..."
	local -a a_output a_output2
	a_output=()
	a_output2=()

	# 1. Detect Config File
	echo "[CMD] Executing: Detecting config file path from kubelet process..."
	local config_path
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o -- "--config=[^ ]*" | head -n 1 | cut -d= -f2- || echo "")
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"
	echo "[DEBUG] config_path = $config_path"

	# 2. Priority 1: Check Flag
	echo "[CMD] Checking for --pod-max-pids in process..."
	if ps -ef | grep -v grep | grep -F -- "kubelet" | grep -F -q -- "--pod-max-pids"; then
		echo "[INFO] Check Passed (Flag set)"
		a_output+=(" - Check Passed: --pod-max-pids is set (Flag)")

	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Checking config file: grep -F 'podPidsLimit:' '$config_path'"
		if grep -F -q "podPidsLimit:" "$config_path"; then
			echo "[INFO] Check Passed (Config file)"
			a_output+=(" - Check Passed: podPidsLimit is set in $config_path")
		else
			echo "[INFO] Check Failed (Config not set)"
			a_output2+=(" - Check Failed: podPidsLimit is NOT set in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: podPidsLimit is NOT set in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.13_remediate.sh"
		fi

	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed (Config file not found)"
		a_output2+=(" - Check Failed: --pod-max-pids not set and config file not found (Default: -1/insecure)")
		echo "[FAIL_REASON] Check Failed: --pod-max-pids not set and config file not found (Default: -1/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.13_remediate.sh"
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
RESULT="$?"
exit "${RESULT:-1}"
