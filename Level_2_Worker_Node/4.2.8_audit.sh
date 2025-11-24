#!/bin/bash
# CIS Benchmark: 4.2.8
# Title: Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)
# Level: • Level 2 - Worker Node

audit_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	# Check if eventRecordQPS is set in Kubelet config or arguments
	config_file="/var/lib/kubelet/config.yaml"
	
	if [ -f "$config_file" ]; then
		if grep -q "eventRecordQPS" "$config_file"; then
			val=$(grep "eventRecordQPS" "$config_file" | awk '{print $2}')
			a_output+=(" - Check Passed: eventRecordQPS is set to $val in $config_file")
		else
			# Check process arguments if not in config
			if ps -ef | grep kubelet | grep -v grep | grep -q "\--event-qps"; then
				val=$(ps -ef | grep kubelet | grep -v grep | grep -oP '(?<=--event-qps=)[^ ]+')
				a_output+=(" - Check Passed: eventRecordQPS is set to $val via command line argument")
			else
				a_output2+=(" - Check Failed: eventRecordQPS is NOT set in $config_file or command line arguments (Default is 5)")
			fi
		fi
	else
		a_output2+=(" - Check Failed: Kubelet config file $config_file not found")
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
