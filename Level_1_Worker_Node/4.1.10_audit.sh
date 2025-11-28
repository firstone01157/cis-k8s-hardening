#!/bin/bash
# CIS Benchmark: 4.1.10
# Title: If the kubelet config.yaml configuration file is being used validate file ownership is set to root:root (Automated)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.1.10..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Automated AAC auditing has been modified to allow CIS-CAT to input a variable for the <PATH>/<FILENAME> of the kubelet config yaml file. Please set $kubelet_config_yaml=<PATH> based on the file locati
	##
	echo "[CMD] Executing: ## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %U:%G /var/lib/kubelet/config.yaml ```Verify that the ownership is set to `root:root`."
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %U:%G /var/lib/kubelet/config.yaml ```Verify that the ownership is set to `root:root`.
	##

	echo "[CMD] Executing: kubelet_config_yaml=$(ps -ef | grep kubelet | grep -v grep | grep -o \" --config=[^ ]*\" | awk -F= '{print $2}' | head -n 1)"
	kubelet_config_yaml=$(ps -ef | grep kubelet | grep -v grep | grep -o " --config=[^ ]*" | awk -F= '{print $2}' | head -n 1)
	[ -z "$kubelet_config_yaml" ] && kubelet_config_yaml="/var/lib/kubelet/config.yaml"
	
	if [ -f "$kubelet_config_yaml" ]; then
		echo "[CMD] Executing: if stat -c %U:%G \"$kubelet_config_yaml\" | grep -q \"root:root\"; then"
		if stat -c %U:%G "$kubelet_config_yaml" | grep -q "root:root"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $kubelet_config_yaml ownership is root:root")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: $kubelet_config_yaml ownership is not root:root")
			echo "[FAIL_REASON] Check Failed: $kubelet_config_yaml ownership is not root:root"
			echo "[FIX_HINT] Run remediation script: 4.1.10_remediate.sh"
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
