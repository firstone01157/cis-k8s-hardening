#!/bin/bash
# CIS Benchmark: 2.4
# Title: Ensure that the --peer-cert-file and --peer-key-file arguments are set as appropriate (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 2.4..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	echo "[CMD] Executing: if ps -ef | grep etcd | grep -v grep | grep -E -q \"\\s--peer-cert-file(=|\\s|$)\" && \\"
	if ps -ef | grep etcd | grep -v grep | grep -E -q "\s--peer-cert-file(=|\s|$)" && \
	   echo "[CMD] Executing: ps -ef | grep etcd | grep -v grep | grep -E -q \"\\s--peer-key-file(=|\\s|$)\"; then"
	   ps -ef | grep etcd | grep -v grep | grep -E -q "\s--peer-key-file(=|\s|$)"; then
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: --peer-cert-file and --peer-key-file are set")
	else
		echo "[INFO] Check Failed"
		a_output2+=(" - Check Failed: --peer-cert-file and/or --peer-key-file are not set")
		echo "[FAIL_REASON] Check Failed: --peer-cert-file and/or --peer-key-file are not set"
		echo "[FIX_HINT] Run remediation script: 2.4_remediate.sh"
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
