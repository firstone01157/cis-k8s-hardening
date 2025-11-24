#!/bin/bash
# CIS Benchmark: 4.1.8
# Title: Ensure that the client certificate authorities file ownership is set to root:root (Manual)
# Level: • Level 1 - Worker Node
# Remediation Script

		return 0
	fi
}

remediate_rule
exit $?
