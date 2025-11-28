#!/bin/bash
# CIS Benchmark: 4.1.8
# Title: Ensure that the client certificate authorities file ownership is set to root:root (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	echo "[INFO] Starting check for 4.1.8..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	echo "[CMD] Executing: ## Run the following command: ps -ef | grep kubelet Find the file specified by the --client-ca-file argument. Run the following command: stat -c %U:%G <filename> Verify that the ownership is set to root:"
	## Run the following command: ps -ef | grep kubelet Find the file specified by the --client-ca-file argument. Run the following command: stat -c %U:%G <filename> Verify that the ownership is set to root:
	##
	echo "[CMD] Executing: ## Command hint: Run the following command: ps -ef | grep kubelet Find the file specified by the --client-ca-file argument. Run the following command: stat -c %U:%G <filename> Verify that the ownership is set to root:root."
	## Command hint: Run the following command: ps -ef | grep kubelet Find the file specified by the --client-ca-file argument. Run the following command: stat -c %U:%G <filename> Verify that the ownership is set to root:root.
	##

	echo "[CMD] Executing: client_ca_file=$(ps -ef | grep kubelet | grep -v grep | grep -o \' --client-ca-file=[^ ]*\' | awk -F= \'{print $2}\')"
	client_ca_file=$(ps -ef | grep kubelet | grep -v grep | grep -o ' --client-ca-file=[^ ]*' | awk -F= '{print $2}')
	if [ -z "$client_ca_file" ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --client-ca-file not set")
	else
		if [ -f "$client_ca_file" ]; then
			echo "[CMD] Executing: if stat -c %U:%G \"$client_ca_file\" | grep -q \"root:root\"; then"
			if stat -c %U:%G "$client_ca_file" | grep -q "root:root"; then
				echo "[INFO] Check Passed"
				a_output+=(" - Check Passed: $client_ca_file ownership is root:root")
			else
				echo "[INFO] Check Failed"
				a_output2+=(" - Check Failed: $client_ca_file ownership is not root:root")
				echo "[FAIL_REASON] Check Failed: $client_ca_file ownership is not root:root"
				echo "[FIX_HINT] Run remediation script: 4.1.8_remediate.sh"
			fi
		else
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $client_ca_file does not exist")
		fi
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
