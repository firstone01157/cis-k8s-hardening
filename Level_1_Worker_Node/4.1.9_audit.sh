#!/bin/bash
# CIS Benchmark: 4.1.9
# Title: If the kubelet config.yaml configuration file is being used validate permissions set to 600 or more restrictive (Automated)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.1.9..."
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: kubelet_config_yaml=$(kubelet_config_path)"
	kubelet_config_yaml=$(kubelet_config_path)

	if [ -f "$kubelet_config_yaml" ]; then
		echo "[CMD] Executing: if stat -c %a \"$kubelet_config_yaml\" | grep -qE '^[0-6]00$'; then"
		if stat -c %a "$kubelet_config_yaml" | grep -qE '^[0-6]00$'; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $kubelet_config_yaml permissions are 600 or more restrictive")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: $kubelet_config_yaml permissions are not 600 or more restrictive")
			echo "[FAIL_REASON] Check Failed: $kubelet_config_yaml permissions are not 600 or more restrictive"
			echo "[FIX_HINT] Run remediation script: 4.1.9_remediate.sh"
		fi
	else
		echo "[INFO] Check Passed"
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
exit $?
