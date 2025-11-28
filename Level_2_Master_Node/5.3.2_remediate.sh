#!/bin/bash
# CIS Benchmark: 5.3.2
# Title: Ensure that all Namespaces have Network Policies defined
# Level: Level 1 - Master Node
# Remediation Script (Draft Mode)

remediate_rule() {
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	l_artifact_dir="./remediation_artifacts"
	mkdir -p "$l_artifact_dir"
	l_artifact_file="$l_artifact_dir/default-deny-policy.yaml"

	cat <<EOF > "$l_artifact_file"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF

	a_output+=(" - Remediation artifact generated at $l_artifact_file. Review and apply manually.")
	return 0
}

remediate_rule
exit $?
