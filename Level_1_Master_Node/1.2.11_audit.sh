#!/bin/bash
# CIS Benchmark: 1.2.11
# Title: Ensure that the admission control plugin AlwaysPullImages is set (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.11..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	kube_apiserver_cmd=$(ps -ef | grep kube-apiserver | grep -v grep || true)
	if [ -z "${kube_apiserver_cmd}" ]; then
		echo "[INFO] kube-apiserver process not detected"
		a_output2+=(" - Check Failed: kube-apiserver process could not be read")
		echo "[FAIL_REASON] Unable to inspect kube-apiserver command line"
		echo "[FIX_HINT] Ensure kube-apiserver is running before re-running this audit"
	else
		pattern='[[:space:]]--enable-admission-plugins=[^[:space:]]*(,|[[:space:]])AlwaysPullImages(,|[[:space:]]|$)'
		echo "[CMD] Executing: grep -E '${pattern}'"
		if printf '%s' "${kube_apiserver_cmd}" | grep -E -q "${pattern}"; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: AlwaysPullImages is enabled")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: --enable-admission-plugins does not include AlwaysPullImages")
			echo "[FAIL_REASON] Check Failed: AlwaysPullImages is NOT enabled"
			echo "[FIX_HINT] Run remediation script: 1.2.11_remediate.sh"
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
