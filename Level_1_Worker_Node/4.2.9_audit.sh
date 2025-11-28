#!/bin/bash
# CIS Benchmark: 4.2.9
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.2.9..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP \'(?<=--config=)[^ ]+\' | head -n 1)"
	config_path=$(ps -ef | grep kubelet | grep -v grep | grep -oP '(?<=--config=)[^ ]+' | head -n 1)
	[ -z "$config_path" ] && config_path="/var/lib/kubelet/config.yaml"

	# 2. Priority 1: Check Flag
	echo "[CMD] Executing: flag_cert=$(ps -ef | grep kubelet | grep -v grep | grep -E \"\\s--tls-cert-file(=|\\s|$)\")"
	flag_cert=$(ps -ef | grep kubelet | grep -v grep | grep -E "\s--tls-cert-file(=|\s|$)")
	echo "[CMD] Executing: flag_key=$(ps -ef | grep kubelet | grep -v grep | grep -E \"\\s--tls-private-key-file(=|\\s|$)\")"
	flag_key=$(ps -ef | grep kubelet | grep -v grep | grep -E "\s--tls-private-key-file(=|\s|$)")

	if [ -n "$flag_cert" ] && [ -n "$flag_key" ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --tls-cert-file and --tls-private-key-file are set (Flag)")
	elif [ -n "$flag_cert" ] || [ -n "$flag_key" ]; then
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: Only one of --tls-cert-file or --tls-private-key-file is set (Flag)")
		echo "[FAIL_REASON] Check Failed: Only one of --tls-cert-file or --tls-private-key-file is set (Flag)"
		echo "[FIX_HINT] Run remediation script: 4.2.9_remediate.sh"
	
	# 3. Priority 2: Check Config File
	# 3. Priority 2: Check Config File
	elif [ -f "$config_path" ]; then
		# Check for serverTLSBootstrap: true (handling whitespace)
		echo "[CMD] Executing: if grep -E -q \"serverTLSBootstrap:\\s*true\" \"$config_path\"; then"
		if grep -E -q "serverTLSBootstrap:\s*true" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: serverTLSBootstrap is set to true in $config_path")
		elif grep -E -q "tlsCertFile:" "$config_path" && grep -E -q "tlsPrivateKeyFile:" "$config_path"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: tlsCertFile and tlsPrivateKeyFile are set in $config_path")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: Neither serverTLSBootstrap: true nor (tlsCertFile AND tlsPrivateKeyFile) are set in $config_path")
			echo "[FAIL_REASON] Check Failed: TLS configuration missing in $config_path"
			echo "[FIX_HINT] Run remediation script: 4.2.9_remediate.sh"
		fi
	
	# 4. Priority 3: Default
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: TLS args not set and config file not found (Default: missing)")
		echo "[FAIL_REASON] Check Failed: TLS args not set and config file not found (Default: missing)"
		echo "[FIX_HINT] Run remediation script: 4.2.9_remediate.sh"
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
