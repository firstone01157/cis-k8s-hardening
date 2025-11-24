#!/bin/bash
# CIS Benchmark: 1.1.2
# Title: Ensure that the API server pod specification file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the below command (based on the file location on your system) on the Control Plane node. For example, stat -c %U:%G /etc/kubernetes/manifests/kube-apiserver.yaml Verify that the ownership is set t
	##
	## Command hint: (based on the file location on your system) on the Control Plane node. For example, stat -c %U:%G /etc/kubernetes/manifests/kube-apiserver.yaml Verify that the ownership is set to root:root.
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ -e "/etc/kubernetes/manifests/kube-apiserver.yaml" ]; then
		l_owner=$(stat -c %U:%G /etc/kubernetes/manifests/kube-apiserver.yaml)
		if [ "$l_owner" == "root:root" ]; then
			a_output+=(" - Check Passed: Ownership on /etc/kubernetes/manifests/kube-apiserver.yaml is $l_owner")
		else
			a_output2+=(" - Check Failed: Ownership on /etc/kubernetes/manifests/kube-apiserver.yaml is $l_owner (should be root:root)")
		fi
	else
		a_output+=(" - Check Passed: /etc/kubernetes/manifests/kube-apiserver.yaml not found")
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
