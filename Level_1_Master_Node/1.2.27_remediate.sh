#!/bin/bash
# CIS Benchmark: 1.2.27
# Title: Ensure that the --encryption-provider-config argument is set as appropriate
# Level: Level 1 - Master Node
# Remediation Script

remediate_rule() {
	echo "[INFO] CIS 1.2.27 - API server encryption must be configured"
	echo ""
	echo "[INFO] This check requires MANUAL configuration. Here's what to do:"
	echo ""
	echo "1. Create an encryption configuration file at /etc/kubernetes/enc/encryption-config.yaml:"
	echo "   mkdir -p /etc/kubernetes/enc"
	echo "   cat > /etc/kubernetes/enc/encryption-config.yaml << 'EOF'"
	echo "apiVersion: apiserver.config.k8s.io/v1"
	echo "kind: EncryptionConfiguration"
	echo "resources:"
	echo "  - resources:"
	echo "      - secrets"
	echo "      - configmaps"
	echo "    providers:"
	echo "      - aescbc:"
	echo "          keys:"
	echo "            - name: key1"
	echo "              secret: <base64-encoded-random-32-bytes>"
	echo "      - identity: {}"
	echo "EOF"
	echo ""
	echo "2. Edit the kube-apiserver static pod manifest:"
	echo "   sudo nano /etc/kubernetes/manifests/kube-apiserver.yaml"
	echo ""
	echo "3. Add the flag to the 'command:' section:"
	echo "   - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml"
	echo ""
	echo "4. Add volume mount in the 'volumeMounts:' section:"
	echo "   - name: encryption"
	echo "     mountPath: /etc/kubernetes/enc"
	echo "     readOnly: true"
	echo ""
	echo "5. Add volume in the 'volumes:' section:"
	echo "   - name: encryption"
	echo "     hostPath:"
	echo "       path: /etc/kubernetes/enc"
	echo "       type: DirectoryOrCreate"
	echo ""
	echo "6. Save the file. kubelet will automatically restart the API server."
	echo ""
	echo "[MANUAL] Please configure etcd encryption and return to this check after the API server restarts."
	
	return 3
}

remediate_rule
exit $?
