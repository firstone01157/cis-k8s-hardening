#!/bin/bash
# CIS Benchmark: 4.2.3
# Title: Ensure that the --client-ca-file argument is set as appropriate (Automated)
# Level: • Level 1 - Worker Node

set -e  # Exit on error
set -u  # Exit on undefined variable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.3: client-ca-file must be set"
	local -a a_output=()
	local -a a_output2=()
	local config_path=""
	local clientCAFile=""
	local result=1

	# Detect config file path
	echo "[DEBUG] Detecting kubelet config path..."
	config_path=$(kubelet_config_path)
	echo "[DEBUG] config_path = $config_path"

	# Priority 1: Check command-line flags
	echo "[DEBUG] Checking for --client-ca-file flag in process..."
	if ps -ef | grep -v grep | grep "kubelet" | grep -qE "\s--client-ca-file(=|\s)"; then
		echo "[PASS] Found --client-ca-file flag in process"
		a_output+=(" - Check Passed: --client-ca-file is set (Flag)")
		result=0
	# Priority 2: Check config file with YAML-aware grep
	elif [ -f "$config_path" ]; then
		echo "[DEBUG] Checking YAML config file: $config_path"
		
		# Use context-aware grep:
		# 1. Find the x509 block (under authentication)
		# 2. Check if clientCAFile is present and has a non-empty value
		if grep -A 5 "x509:" "$config_path" | grep -q "clientCAFile:"; then
			# Extract the clientCAFile value
			clientCAFile=$(grep -A 5 "x509:" "$config_path" | grep "clientCAFile:" | awk '{print $2}')
			
			if [ -n "$clientCAFile" ]; then
				echo "[PASS] Found clientCAFile in config: $clientCAFile"
				a_output+=(" - Check Passed: authentication.x509.clientCAFile is set to '$clientCAFile' in $config_path")
				result=0
			else
				echo "[FAIL] clientCAFile is empty in config"
				a_output2+=(" - Check Failed: authentication.x509.clientCAFile is empty in $config_path")
				result=1
			fi
		else
			echo "[FAIL] clientCAFile not found in x509 block"
			a_output2+=(" - Check Failed: authentication.x509.clientCAFile is NOT set in $config_path")
			result=1
		fi
	else
		echo "[FAIL] Config file not found and no flag set"
		a_output2+=(" - Check Failed: --client-ca-file not set and config file not found (Default: missing/insecure)")
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
		echo "[FIX_HINT] Run remediation script: 4.2.3_remediate.sh"
		return 1
	fi
}

audit_rule
exit $?
