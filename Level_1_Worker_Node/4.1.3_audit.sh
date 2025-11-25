#!/bin/bash
# CIS Benchmark: 4.1.3
# Title: If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Find the kubeconfig file being used by kube-proxy by running the following command: ps -ef | grep kube-proxy If kube-proxy is running, get the kubeconfig file location from the --kubeconfig parameter.
	##
	## Command hint: (based on the file location on your system) on the each worker node. For example, stat -c %a <path><filename> Verify that a file is specified and it exists with permissions are 600 or more restrictive.
	##

	kube_proxy_kubeconfig=$(ps -ef | grep kube-proxy | grep -v grep | grep -o ' --kubeconfig=[^ ]*' | awk -F= '{print $2}')
	if [ -z "$kube_proxy_kubeconfig" ]; then
		a_output+=(" - Check Passed: kube-proxy not running or --kubeconfig not set")
	else
		if [ -f "$kube_proxy_kubeconfig" ]; then
			if stat -c %a "$kube_proxy_kubeconfig" | grep -qE '^[0-6]00$'; then
				a_output+=(" - Check Passed: $kube_proxy_kubeconfig permissions are 600 or more restrictive")
			else
				a_output2+=(" - Check Failed: $kube_proxy_kubeconfig permissions are not 600 or more restrictive")
			fi
		else
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
