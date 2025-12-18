#!/bin/bash
# CIS Benchmark: 1.2.28
# Title: Ensure that the --api-server-count argument is set as appropriate
# Level: Level 2 - Master Node
# Remediation Script

remediate_rule() {
	echo "[INFO] CIS 1.2.28 - API server count should match cluster configuration"
	echo ""
	echo "[INFO] This check requires MANUAL configuration. Here's what to do:"
	echo ""
	echo "1. Determine the correct number of API servers in your cluster:"
	echo "   kubectl get pods -n kube-system | grep kube-apiserver | wc -l"
	echo ""
	echo "2. Or count master nodes:"
	echo "   kubectl get nodes -l node-role.kubernetes.io/master | wc -l"
	echo ""
	echo "3. Edit the kube-apiserver static pod manifest:"
	echo "   sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml"
	echo ""
	echo "4. Add the flag to the 'command:' section with your cluster's API server count:"
	echo "   - --api-server-count=<NUMBER_OF_API_SERVERS>"
	echo ""
	echo "   Example (for 3-node cluster):"
	echo "   - --api-server-count=3"
	echo ""
	echo "5. Save the file. kubelet will automatically restart the API server."
	echo ""
	echo "6. Verify the configuration is active:"
	echo "   kubectl logs -n kube-system kube-apiserver-<node-name> 2>/dev/null | grep 'api-server-count' || echo 'Check pod status'"
	echo ""
	echo "[MANUAL] Please configure the API server count and return to this check after the API server restarts."
	
	return 3
}

remediate_rule
exit $?
