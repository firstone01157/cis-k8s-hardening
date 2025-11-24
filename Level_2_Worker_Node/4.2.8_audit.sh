#!/bin/bash
# CIS Benchmark: 4.2.8
# Title: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)
# Level: • Level 2 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## Run the following command on each node: sudo grep "eventRecordQPS" /etc/systemd/system/kubelet.service.d/10- kubeadm.conf or If using command line arguments, kubelet service file is located /etc/syste
	##
	## Command hint: Run the following command on each node: sudo grep "eventRecordQPS" /etc/systemd/system/kubelet.service.d/10- kubeadm.conf or If using command line arguments, kubelet service file is located /etc/systemd/system/kubelet.service.d/10-kubelet-args.conf sudo grep "eventRecordQPS" /etc/systemd/system/kubelet.service.d/10-kubelet- args.conf Review the value set for the argument and determine whether this has been set to an appropriate level for the cluster. If the argument does not exist, check that there is a Kubelet config file specified by -- config and review the value in this location. If using command line arguments
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ 1 -eq 0 ]; then
		a_output+=(" - Check Passed")
	else
		a_output2+=(" - Check Failed (Logic not yet implemented)")
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
