#!/bin/bash
# CIS Benchmark: 1.2.4
# Title: Ensure that the --kubelet-client-certificate and --kubelet-client-key arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q \"\\s--kubelet-client-certificate(=|\\s|$)\" && \\"
	if ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--kubelet-client-certificate(=|\s|$)" && \
	   ps -ef | grep kube-apiserver | grep -v grep | grep -E -q "\s--kubelet-client-key(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --kubelet-client-certificate and --kubelet-client-key are set")
	elif [ -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ] && \
	     grep -q -- "--kubelet-client-certificate" "/etc/kubernetes/manifests/kube-apiserver.yaml" && \
	     grep -q -- "--kubelet-client-key" "/etc/kubernetes/manifests/kube-apiserver.yaml"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --kubelet-client-certificate and --kubelet-client-key are set in manifest")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --kubelet-client-certificate and/or --kubelet-client-key are NOT set")
		echo "[FAIL_REASON] Check Failed: --kubelet-client-certificate and/or --kubelet-client-key are NOT set"
		echo "[FIX_HINT] Run remediation script: 1.2.4_remediate.sh"
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
