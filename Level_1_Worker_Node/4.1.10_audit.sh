#!/bin/bash
# CIS Benchmark: 4.1.10
# Title: If the kubelet config.yaml configuration file is being used validate file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node

set -x  # Enable debugging
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.1.10..."
	local -a a_output a_output2
	a_output=()
	a_output2=()

	## Description from CSV:
	## Automated AAC auditing has been modified to allow CIS-CAT to input a variable for the <PATH>/<FILENAME> of the kubelet config yaml file. Please set $kubelet_config_yaml based on the file location on your system.
	## Command hint: use "stat -c %U:%G <path>" and verify that the ownership is set to root:root.

	echo "[CMD] Executing: kubelet_config_yaml=$(kubelet_config_path)"
	local kubelet_config_yaml
	kubelet_config_yaml=$(kubelet_config_path)
	echo "[DEBUG] kubelet_config_yaml = $kubelet_config_yaml"
	
	if [ -f "$kubelet_config_yaml" ]; then
		echo "[CMD] Executing: stat -c %U:%G '$kubelet_config_yaml' | grep -F -q -- 'root:root'"
		if stat -c %U:%G "$kubelet_config_yaml" | grep -F -q -- "root:root"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $kubelet_config_yaml ownership is root:root")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: $kubelet_config_yaml ownership is not root:root")
			echo "[FAIL_REASON] Check Failed: $kubelet_config_yaml ownership is not root:root"
			echo "[FIX_HINT] Run remediation script: 4.1.10_remediate.sh"
		fi
	else
		echo "[INFO] Check Passed (config file does not exist)"
		a_output+=(" - Check Passed: $kubelet_config_yaml does not exist")
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
