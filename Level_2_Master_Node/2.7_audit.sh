#!/bin/bash
# CIS Benchmark: 2.7
# Title: Ensure that a unique Certificate Authority is used for etcd (Manual)
# Level: • Level 2 - Master Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	etcd_ca=$(ps -ef | grep etcd | grep -v grep | grep -oP '(?<=--trusted-ca-file=)[^ ]+')
	apiserver_ca=$(ps -ef | grep kube-apiserver | grep -v grep | grep -oP '(?<=--client-ca-file=)[^ ]+')

	if [ -n "$etcd_ca" ] && [ -n "$apiserver_ca" ]; then
		if [ "$etcd_ca" != "$apiserver_ca" ]; then
			a_output+=(" - Check Passed: Etcd is using a different CA ($etcd_ca) than API Server ($apiserver_ca)")
		else
			a_output2+=(" - Check Failed: Etcd is using the same CA as API Server ($etcd_ca)")
		fi
	else
		a_output2+=(" - Check Failed: Could not determine CA files. Etcd CA: '$etcd_ca', API Server CA: '$apiserver_ca'")
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
