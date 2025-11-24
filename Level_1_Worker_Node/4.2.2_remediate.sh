#!/bin/bash
# CIS Benchmark: 4.2.2
# Title: Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	a_output+=(" - Remediation: Manual intervention required. Ensure '--authorization-mode' is set to 'Webhook' or 'Node,RBAC' and NOT 'AlwaysAllow'. Check /var/lib/kubelet/config.yaml or systemd unit.")
	return 0
}

remediate_rule
exit $?
