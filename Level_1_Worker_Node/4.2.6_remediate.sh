#!/bin/bash
# CIS Benchmark: 4.2.6
# Title: Ensure that the --make-iptables-util-chains argument is set to true (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Set 'makeIPTablesUtilChains: true' in kubelet config.")
	a_output+=(" - WARNING: Ensure kernel parameters are tuned BEFORE applying this. Failure to do so may cause Kubelet boot loop.")
	return 0
}

remediate_rule
exit $?
