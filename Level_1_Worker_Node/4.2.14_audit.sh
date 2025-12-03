#!/bin/bash
# CIS Benchmark: 4.2.14
# Title: Ensure that the --seccomp-default parameter is set to true (Manual)
# Level: • Level 1 - Worker Node

set -x  # Enable debugging
set -euo pipefail

audit_rule() {
	echo "[INFO] Starting check for 4.2.14..."
	local -a a_output a_output2
	a_output=()
	a_output2=()

	echo "[CMD] Executing: Detecting config file path from kubelet process..."
	local config_path
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -o -- "--config=[^ ]*" | head -n 1 | cut -d= -f2- || echo "")
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"
	echo "[DEBUG] config_path = $config_path"

	echo "[CMD] Checking for --seccomp-default=true in process..."
	if ps -ef | grep -v grep | grep -F -- "kubelet" | grep -F -q -- "--seccomp-default=true"; then
		echo "[INFO] Check Passed (Flag set to true)"
		a_output+=(" - Check Passed: --seccomp-default is set to true (Flag)")
	elif ps -ef | grep -v grep | grep -F -- "kubelet" | grep -F -q -- "--seccomp-default=false"; then
		echo "[INFO] Check Failed (Flag set to false)"
		a_output2+=(" - Check Failed: --seccomp-default is set to false (Flag)")
		echo "[FAIL_REASON] Check Failed: --seccomp-default is set to false (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.14_remediate.sh"
	elif [ -f "$config_path" ]; then
		echo "[CMD] Checking config file: grep -F 'seccompDefault: true' '$config_path'"
		if grep -F -q "seccompDefault: true" "$config_path"; then
			echo "[INFO] Check Passed (Config set to true)"
			a_output+=(" - Check Passed: seccompDefault is set to true in $config_path")
		else
			echo "[INFO] Check Failed (Config not set to true)"
			a_output2+=(" - Check Failed: seccompDefault is NOT set to true in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: seccompDefault is NOT set to true in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.14_remediate.sh"
		fi
	else
		echo "[INFO] Check Failed (Config file not found)"
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
RESULT="$?"
exit "${RESULT:-1}"
