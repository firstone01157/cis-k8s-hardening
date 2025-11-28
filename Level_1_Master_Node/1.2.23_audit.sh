#!/bin/bash
# CIS Benchmark: 1.2.23
# Title: Ensure that the --etcd-certfile and --etcd-keyfile arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.23..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--etcd-certfile(=|\\s|$)\" && \\"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--etcd-certfile(=|\s|$)" && \
       ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--etcd-keyfile(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --etcd-certfile and --etcd-keyfile are set")
	elif [ -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ] && \
	     grep -q -- "--etcd-certfile" "/etc/kubernetes/manifests/kube-apiserver.yaml" && \
	     grep -q -- "--etcd-keyfile" "/etc/kubernetes/manifests/kube-apiserver.yaml"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --etcd-certfile and --etcd-keyfile are set in manifest")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --etcd-certfile and/or --etcd-keyfile are not set")
		echo "[FAIL_REASON] Check Failed: --etcd-certfile and/or --etcd-keyfile are not set"
		echo "[FIX_HINT] Run remediation script: 1.2.23_remediate.sh"
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
