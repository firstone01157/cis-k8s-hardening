#!/bin/bash
# CIS Benchmark: 4.1.4
# Title: If proxy kubeconfig file exists ensure ownership is set to root:root (Manual)
# Level: • Level 1 - Worker Node

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/kubelet_helpers.sh"

audit_rule() {
	echo "[INFO] Starting check for 4.1.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	echo "[CMD] Executing: ## Find the kubeconfig file being used by kube-proxy by running the following command: ps -ef | grep kube-proxy If kube-proxy is running, get the kubeconfig file location from the --kubeconfig parameter."
	## Find the kubeconfig file being used by kube-proxy by running the following command: ps -ef | grep kube-proxy If kube-proxy is running, get the kubeconfig file location from the --kubeconfig parameter.
	##
	echo "[CMD] Executing: ## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %U:%G <path><filename> Verify that the ownership is set to root:root."
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %U:%G <path><filename> Verify that the ownership is set to root:root.
	##

	echo "[CMD] Executing: kube_proxy_kubeconfig=$(kube_proxy_kubeconfig_path)"
	kube_proxy_kubeconfig=$(kube_proxy_kubeconfig_path)
	if [ -z "$kube_proxy_kubeconfig" ]; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: kube-proxy not running or --kubeconfig not set")
	else
		if [ -f "$kube_proxy_kubeconfig" ]; then
			echo "[CMD] Executing: if stat -c %U:%G \"$kube_proxy_kubeconfig\" | grep -q \"root:root\"; then"
			if stat -c %U:%G "$kube_proxy_kubeconfig" | grep -q "root:root"; then
				echo "[INFO] Check Passed"
				a_output+=(" - Check Passed: $kube_proxy_kubeconfig ownership is root:root")
			else
				echo "[INFO] Check Failed"
				a_output2+=(" - Check Failed: $kube_proxy_kubeconfig ownership is not root:root")
				echo "[FAIL_REASON] Check Failed: $kube_proxy_kubeconfig ownership is not root:root"
				echo "[FIX_HINT] Run remediation script: 4.1.4_remediate.sh"
			fi
		else
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: $kube_proxy_kubeconfig does not exist")
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
