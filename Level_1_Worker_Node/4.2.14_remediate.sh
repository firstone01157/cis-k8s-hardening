#!/bin/bash
# CIS Benchmark: 4.2.14
# Title: Ensure that the --seccomp-default parameter is set to true (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## Description from CSV:
	## Set the parameter, either via the --seccomp-default command line parameter or the seccompDefault configuration file setting.
	##
	## Command hint: Set the parameter, either via the --seccomp-default command line parameter or the seccompDefault configuration file setting.
	##
	## Safety Check: Verify if remediation is needed before applying

	a_output+=(" - Remediation: Manual intervention required. Set '--seccomp-default=true' in kubelet config or startup flags.")
	return 0
}

remediate_rule
exit $?
