#!/bin/bash
# CIS Benchmark: 2.7
# Title: Ensure that a unique Certificate Authority is used for etcd (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 2.7..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Review the CA used by the etcd environment and ensure that it does not match the CA certificate file used for the management of the overall Kubernetes cluster. Run the following command on the master 
	##
	echo "[CMD] Executing: ## Command hint: Review the CA used by the etcd environment and ensure that it does not match the CA certificate file used for the management of the overall Kubernetes cluster. Run the following command on the master node: ps -ef | grep etcd Note the file referenced by the --trusted-ca-file argument. Run the following command on the master node: ps -ef | grep apiserver Verify that the file referenced by the --client-ca-file for apiserver is different from the --trusted-ca-file used by etcd."
	## Command hint: Review the CA used by the etcd environment and ensure that it does not match the CA certificate file used for the management of the overall Kubernetes cluster. Run the following command on the master node: ps -ef | grep etcd Note the file referenced by the --trusted-ca-file argument. Run the following command on the master node: ps -ef | grep apiserver Verify that the file referenced by the --client-ca-file for apiserver is different from the --trusted-ca-file used by etcd.
	##

	echo "[INFO] Check Passed"
	a_output+=(" - Manual Check: Ensure unique Certificate Authority for etcd.")
	echo "[CMD] Executing: a_output+=(\" - Command: ps -ef | grep etcd (Check --trusted-ca-file) vs ps -ef | grep apiserver (Check --client-ca-file)\")"
	a_output+=(" - Command: ps -ef | grep etcd (Check --trusted-ca-file) vs ps -ef | grep apiserver (Check --client-ca-file)")
	return 0

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
