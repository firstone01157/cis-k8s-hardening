#!/bin/bash
# CIS Benchmark: 4.2.11
# Title: Verify that the RotateKubeletServerCertificate argument is set to true (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.11..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP \'(?<=--config=)[^ ]+\' | head -n 1)"
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP '(?<=--config=)[^ ]+' | head -n 1)
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: if ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--rotate-server-certificates=true(\\s|$)\"; then"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--rotate-server-certificates=true(\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --rotate-server-certificates is set to true (Flag)")
	echo "[CMD] Executing: elif ps -ef | grep kubelet | grep -v grep | grep -E -q \"\\s--rotate-server-certificates=false(\\s|$)\"; then"
	elif ps -ef | grep kubelet | grep -v grep | grep -E -q "\s--rotate-server-certificates=false(\s|$)"; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --rotate-server-certificates is set to false (Flag)")
		echo "[FAIL_REASON] Check Failed: --rotate-server-certificates is set to false (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.11_remediate.sh"
	
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		echo "[CMD] Executing: if grep -E -q \"rotateServerCertificates:\\s*true\" \"$config_path\"; then"
		if grep -E -q "rotateServerCertificates:\s*true" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: rotateServerCertificates is set to true in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: rotateServerCertificates is NOT set to true in $config_path (or missing)")
			echo "[FAIL_REASON] Check Failed: rotateServerCertificates is NOT set to true in $config_path (or missing)"
			echo "[FIX_HINT] Run remediation script: 4.2.11_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --rotate-server-certificates not set and config file not found (Default: false/insecure)")
		echo "[FAIL_REASON] Check Failed: --rotate-server-certificates not set and config file not found (Default: false/insecure)"
		echo "[FIX_HINT] Run remediation script: 4.2.11_remediate.sh"
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
