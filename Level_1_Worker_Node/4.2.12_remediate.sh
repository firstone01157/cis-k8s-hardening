#!/bin/bash
# CIS Benchmark: 4.2.12
# Title: Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## If using a Kubelet config file, edit the file to set tlsCipherSuites: to TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM _SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE
	##
	## Command hint: If using a Kubelet config file, edit the file to set tlsCipherSuites: to TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM _SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_ 256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WI TH_AES_256_GCM_SHA384 or to a subset of these values. If using executable arguments, edit the kubelet service file /etc/kubernetes/kubelet.conf on each worker node and set the --tls-cipher- suites parameter as follows, or to a subset of these values. --tls-cipher- suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM _SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM _SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_ECDSA_WITH_AES_256_GCM _SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256 Based on your system, restart the kubelet service. For example: systemctl daemon-reload systemctl restart kubelet.service
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	a_output+=(" - Remediation: Manual intervention required. Enable 'RotateKubeletServerCertificate' feature gate.")
	return 0
}

remediate_rule
exit $?
