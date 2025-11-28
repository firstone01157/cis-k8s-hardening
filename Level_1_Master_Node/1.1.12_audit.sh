#!/bin/bash
# CIS Benchmark: 1.1.12
# Title: Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.1.12..."
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/var/lib/etcd"
	if [ -d "$l_dir" ]; then
		echo "[CMD] Executing: l_owner=$(stat -c %U:%G \"$l_dir\")"
		l_owner=$(stat -c %U:%G "$l_dir")
		if [ "$l_owner" == "etcd:etcd" ] || [ "$l_owner" == "root:root" ]; then
			echo "[INFO] Check Passed"
			a_output+=(" - Check Passed: Ownership on $l_dir is $l_owner")
		else
			echo "[INFO] Check Failed"
			a_output2+=(" - Check Failed: Ownership on $l_dir is $l_owner (should be etcd:etcd or root:root)")
			echo "[FAIL_REASON] Check Failed: Ownership on $l_dir is $l_owner (should be etcd:etcd or root:root)"
			echo "[FIX_HINT] Run remediation script: 1.1.12_remediate.sh"
		fi
	else
		echo "[INFO] Check Passed"
		a_output+=(" - Check Passed: $l_dir directory not found")
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
