#!/bin/bash
# CIS Benchmark: 4.2.7
# Title: Ensure that the --hostname-override argument is not set (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Remove '--hostname-override' from kubelet startup flags in systemd unit.")
	return 0
}

remediate_rule
exit $?
