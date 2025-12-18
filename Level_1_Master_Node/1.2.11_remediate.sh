#!/bin/bash
# CIS Benchmark: 1.2.11
# Title: Ensure that the --enable-admission-plugins argument is set appropriately
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	echo "[INFO] CIS 1.2.11 - Admission plugins must be configured based on cluster needs"
	echo ""
	echo "[INFO] This check requires MANUAL configuration. Here's what to do:"
	echo ""
	echo "1. Edit the kube-apiserver static pod manifest:"
	echo "   sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml"
	echo ""
	echo "2. Find the 'command:' section and ensure '--enable-admission-plugins' is set with:"
	echo "   - pod-security-policy  (controls pod security policies)"
	echo "   - node-restriction    (limits kubelet API access)"
	echo "   - alwayspullimages    (ensure image pull policy)"
	echo "   - defaultstorageclass (manages storage classes)"
	echo ""
	echo "3. Example line to add:"
	echo "   - --enable-admission-plugins=pod-security-policy,node-restriction,alwayspullimages,defaultstorageclass"
	echo ""
	echo "4. Save the file. kubelet will automatically detect the change and restart the pod."
	echo ""
	echo "5. Verify with:"
	echo "   kubectl describe pod -n kube-system kube-apiserver-<node-name> | grep -A5 'enable-admission-plugins'"
	echo ""
	echo "[MANUAL] Please configure admission plugins and return to this check after the API server restarts."
	
	# This requires manual intervention - return 3
	return 3
}

remediate_rule
exit $?
