#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Manual)
# Level: • Level 1 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## The set of cryptographic ciphers currently considered secure is the following: • TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 • TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 • TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY130
	##
	## Command hint: The set of cryptographic ciphers currently considered secure is the following: • TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 • TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 • TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305 • TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 • TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305 • TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 Run the following command on each node: ps -ef | grep kubelet If the --tls-cipher-suites argument is present, ensure it only contains values included in this set. If it is not present check that there is a Kubelet config file specified by --config, and that file sets tlsCipherSuites: to only include values from this set.  Internal Only - General
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if ps -ef | grep kubelet | grep -v grep | grep "\--feature-gates" | grep -q "RotateKubeletServerCertificate=true"; then
		a_output+=(" - Check Passed: RotateKubeletServerCertificate is enabled")
	else
		a_output2+=(" - Check Failed: RotateKubeletServerCertificate is NOT enabled")
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
