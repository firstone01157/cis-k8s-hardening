#!/bin/bash
# CIS Benchmark: 4.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Automated)
# Level: • Level 1 - Worker Node

set -e  # Exit on error
set -u  # Exit on undefined variable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.1: anonymous-auth must be false"
	local -a a_output=()
	local -a a_output2=()
	local config_path=""
	local result=1

	# Detect config file path
	echo "[DEBUG] Detecting kubelet config path..."
	config_path=$(kubelet_config_path)
	echo "[DEBUG] config_path = $config_path"

	# Priority 1: Check command-line flags
	echo "[DEBUG] Checking for --anonymous-auth flag in process..."
	if ps -ef | grep -v grep | grep "kubelet" | grep -q -- "--anonymous-auth=false"; then
		echo "[PASS] Found --anonymous-auth=false in process"
		a_output+=(" - Check Passed: --anonymous-auth is explicitly set to false (Flag)")
		result=0
	elif ps -ef | grep -v grep | grep "kubelet" | grep -q -- "--anonymous-auth=true"; then
		echo "[FAIL] Found --anonymous-auth=true in process"
		a_output2+=(" - Check Failed: --anonymous-auth is explicitly set to true (Flag)")
		result=1
	# Priority 2: Check config file with YAML-aware grep
	elif [ -f "$config_path" ]; then
		echo "[DEBUG] Checking YAML config file: $config_path"
		
		# Use context-aware grep to find 'enabled: false' within the anonymous block
		# Look for 'anonymous:' then check the next 2-3 lines for 'enabled: false'
		if grep -A 2 "anonymous:" "$config_path" | grep -q "enabled: false"; then
			echo "[PASS] Config file shows authentication.anonymous.enabled = false"
			a_output+=(" - Check Passed: authentication.anonymous.enabled is set to false in $config_path")
			result=0
		else
			echo "[FAIL] authentication.anonymous.enabled is NOT false in config"
			a_output2+=(" - Check Failed: authentication.anonymous.enabled is NOT set to false in $config_path")
			result=1
		fi
	else
		echo "[FAIL] Config file not found and no flag set"
		a_output2+=(" - Check Failed: --anonymous-auth not set and config file not found (Default: true/insecure)")
		result=1
	fi

	# Output audit results
	if [ "${#a_output2[@]}" -eq 0 ]; then
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" "${a_output[@]}"
		return 0
	else
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${a_output2[@]}"
		if [ "${#a_output[@]}" -gt 0 ]; then
			printf '%s\n' "- Correctly set:" "${a_output[@]}"
		fi
		echo "[FIX_HINT] Run remediation script: 4.2.1_remediate.sh"
		return 1
	fi
}

audit_rule
exit $?
