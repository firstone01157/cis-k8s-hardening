#!/bin/bash
# CIS Benchmark: 1.1.19
# Title: Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)
# Level: • Level 1 - Master Node
# Remediation Script

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_dir="/etc/kubernetes/pki"
	if [ -d "$l_dir" ]; then
		# Check if any file/dir is NOT root:root
		if find "$l_dir" -not -user root -o -not -group root | grep -q .; then
			chown -R root:root "$l_dir"
			
			# Verify again
			if find "$l_dir" -not -user root -o -not -group root | grep -q .; then
				a_output2+=(" - Remediation failed: Could not change ownership on some files in $l_dir")
				return 1
			else
				a_output+=(" - Remediation applied: Ownership on $l_dir recursively changed to root:root")
				return 0
			fi
		else
			a_output+=(" - Remediation not needed: Ownership on $l_dir is correct")
			return 0
		fi
	else
		a_output+=(" - Remediation not needed: $l_dir not found")
		return 0
	fi
}

remediate_rule
exit $?
