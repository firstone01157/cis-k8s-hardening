#!/bin/bash
# CIS Benchmark: 4.2.9
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.2.9..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# 1. Detect Config File
	echo "[CMD] Executing: config_path=$(kubelet_config_path)"
	config_path=$(kubelet_config_path)

	# 2. Priority 1: Check Flag
	flag_cert_set=0
	flag_key_set=0
	flag_cert_cmd='ps -ef | grep kubelet | grep -v grep | grep -E "[[:space:]]--tls-cert-file(=|[[:space:]]|$)"'
	flag_key_cmd='ps -ef | grep kubelet | grep -v grep | grep -E "[[:space:]]--tls-private-key-file(=|[[:space:]]|$)"'
	echo "[CMD] Executing: $flag_cert_cmd"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "[[:space:]]--tls-cert-file(=|[[:space:]]|$)"; then
		flag_cert_set=1
	fi
	echo "[CMD] Executing: $flag_key_cmd"
	if ps -ef | grep kubelet | grep -v grep | grep -E -q "[[:space:]]--tls-private-key-file(=|[[:space:]]|$)"; then
		flag_key_set=1
	fi

	if [ "$flag_cert_set" -eq 1 ] && [ "$flag_key_set" -eq 1 ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --tls-cert-file and --tls-private-key-file are set (Flag)")
	elif [ "$flag_cert_set" -eq 1 ] || [ "$flag_key_set" -eq 1 ]; then
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
