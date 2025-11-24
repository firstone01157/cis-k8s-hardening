#!/bin/bash
# CIS Benchmark: 4.2.9
# Title: Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Configure 'tlsCertFile' and 'tlsPrivateKeyFile' in kubelet config.")
	return 0
}

remediate_rule
exit $?
