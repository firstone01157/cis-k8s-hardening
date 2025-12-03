#!/bin/bash
# Setup Audit Logging Helper (CIS 1.2.15 - 1.2.19)
# This script prepares the environment for audit logging and generates instructions for modifying the kube-apiserver manifest.
# It does NOT modify the manifest directly.

AUDIT_LOG_DIR="/var/log/kubernetes/audit"
AUDIT_POLICY_FILE="/etc/kubernetes/audit-policy.yaml"
MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"

echo "[-] Setting up Audit Logging..."

# 1. Create Log Directory
echo "[-] Creating audit log directory: $AUDIT_LOG_DIR"
mkdir -p "$AUDIT_LOG_DIR"
chmod 700 "$AUDIT_LOG_DIR"
echo "    [OK] Directory created."

# 2. Generate Audit Policy File (CIS Recommended Profile)
echo "[-] Generating audit policy file: $AUDIT_POLICY_FILE"
cat <<EOF > "$AUDIT_POLICY_FILE"
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # The following requests were manually identified as high-volume and low-risk
  # so drop them.
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: "" # core
        resources: ["endpoints", "services", "services/status"]
  - level: None
    # Ingress controller reads 'configmaps/ingress-uid' through the unsecured port.
    # TODO: this is only needed if you use ingress-nginx.
    users: ["system:unsecured"]
    namespaces: ["ingress-nginx"]
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["configmaps"]
  - level: None
    users: ["kubelet"] # kubelet status updates
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["nodes", "nodes/status"]
  - level: None
    userGroups: ["system:nodes"] # node status updates
    verbs: ["get"]
    resources:
      - group: "" # core
        resources: ["nodes", "nodes/status"]
  - level: None
    users:
      - system:kube-controller-manager
      - system:kube-scheduler
      - system:serviceaccount:kube-system:endpoint-controller
    verbs: ["get", "update"]
    namespaces: ["kube-system"]
    resources:
      - group: "" # core
        resources: ["endpoints"]

  # Don't log these read-only URLs from the kube-apiserver
  - level: None
    nonResourceURLs:
      - /healthz*
      - /version
      - /swagger*

  # Don't log events requests
  - level: None
    resources:
      - group: "" # core
        resources: ["events"]

  # Secrets, ConfigMaps, and TokenReviews can contain sensitive data,
  # so do not log their resource content.
  - level: Metadata
    resources:
      - group: "" # core
        resources: ["secrets", "configmaps"]
      - group: authentication.k8s.io
        resources: ["tokenreviews"]

  # Get/list/watch requests can be high-volume, so log at Metadata level
  - level: Metadata
    omitStages:
      - "RequestReceived"
    verbs: ["get", "list", "watch"]

  # Default level for known APIs
  - level: RequestResponse
    omitStages:
      - "RequestReceived"
    resources:
      - group: "" # core
      - group: "extensions"
      - group: "apps"
      - group: "batch"
      - group: "autoscaling"
      - group: "rbac.authorization.k8s.io"
      - group: "policy"
      - group: "networking.k8s.io"
      - group: "storage.k8s.io"

  # Default level for all other requests.
  - level: Metadata
    omitStages:
      - "RequestReceived"
EOF
chmod 600 "$AUDIT_POLICY_FILE"
echo "    [OK] Policy file created."

# 3. Dry Run - Print sed commands
echo ""
echo "[-] DRY RUN: To enable audit logging, you must update $MANIFEST_FILE."
echo "[-] Below are the sed commands to apply the changes. REVIEW CAREFULLY before running."
echo "===================================================================================="

# Flags
echo "# 1. Add flags to kube-apiserver command:"
echo "sed -i '/- kube-apiserver/a \\    - --audit-policy-file=$AUDIT_POLICY_FILE\\n    - --audit-log-path=$AUDIT_LOG_DIR/audit.log\\n    - --audit-log-maxage=30\\n    - --audit-log-maxbackup=10\\n    - --audit-log-maxsize=100' $MANIFEST_FILE"

echo ""
echo "# 2. Add volumeMounts (assuming 'volumeMounts:' exists, inserting at top of list):"
echo "sed -i '/volumeMounts:/a \\    - mountPath: $AUDIT_POLICY_FILE\\n      name: audit-policy\\n      readOnly: true\\n    - mountPath: $AUDIT_LOG_DIR\\n      name: audit-log\\n      readOnly: false' $MANIFEST_FILE"

echo ""
echo "# 3. Add volumes (assuming 'volumes:' exists, inserting at top of list):"
echo "sed -i '/volumes:/a \\  - hostPath:\\n      path: $AUDIT_POLICY_FILE\\n      type: File\\n    name: audit-policy\\n  - hostPath:\\n      path: $AUDIT_LOG_DIR\\n      type: DirectoryOrCreate\\n    name: audit-log' $MANIFEST_FILE"

echo "===================================================================================="
echo "[-] NOTE: These sed commands assume standard kubeadm indentation (4 spaces for flags/mounts, 2 spaces for volumes)."
echo "[-] If your manifest differs, please edit the file manually."
