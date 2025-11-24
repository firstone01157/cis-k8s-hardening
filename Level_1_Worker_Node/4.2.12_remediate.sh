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

	a_output+=(" - Remediation: Manual intervention required. Configure 'tlsCipherSuites' in kubelet config with strong ciphers.")
	return 0
}

remediate_rule
exit $?
