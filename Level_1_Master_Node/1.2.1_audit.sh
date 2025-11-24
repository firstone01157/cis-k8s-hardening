#!/bin/bash
# CIS Benchmark: 1.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --anonymous-auth argument is set to false. Alternative Audit kubectl get pod -nkube-system -lcomponent
	##
	## Command hint: Run the following command on the Control Plane node: ps -ef | grep kube-apiserver Verify that the --anonymous-auth argument is set to false. Alternative Audit kubectl get pod -nkube-system -lcomponent=kube-apiserver -o=jsonpath='{range .items[*]}{.spec.containers[*].command} {"\n"}{end}' | grep '\--anonymous- auth' | grep -i false If the exit code is '1', then the control isn't present / failed
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kube-apiserver | grep -v grep | grep -q -- "--anonymous-auth=false"; then
		a_output+=(" - Check Passed: --anonymous-auth is set to false")
	else
		a_output2+=(" - Check Failed: --anonymous-auth is not set to false")
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
