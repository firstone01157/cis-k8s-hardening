# CIS Kubernetes Benchmark v1.12.0 Implementation

This repository contains Bash scripts for auditing and remediating a Kubernetes cluster against the **CIS Kubernetes Benchmark v1.12.0**.

## Project Structure

The scripts are organized by Node Type and Level:

*   **`Level_1_Master_Node/`**: Standard security checks for Master Nodes.
*   **`Level_2_Master_Node/`**: Enhanced security checks for Master Nodes (defense-in-depth).
*   **`Level_1_Worker_Node/`**: Standard security checks for Worker Nodes.
*   **`Level_2_Worker_Node/`**: Enhanced security checks for Worker Nodes.

Each check consists of two scripts:
*   `X.X.X_audit.sh`: Checks if the configuration meets the benchmark. Returns exit code 0 (Pass) or 1 (Fail).
*   `X.X.X_remediate.sh`: Attempts to fix the configuration to meet the benchmark.

## Prerequisites

*   **OS:** Linux (tested on Ubuntu/Debian based systems)
*   **Shell:** Bash
*   **Tools:**
    *   `kubectl` (configured with admin access)
    *   `jq` (for parsing JSON output)
    *   `systemctl` (for service management)
*   **Privileges:** Root or `sudo` access is required for most scripts (file permissions, service config).

## Usage

### 1. Running Audits

You can run individual audit scripts:

```bash
./Level_1_Master_Node/1.1.1_audit.sh
```

Or run **ALL** audit scripts using the master runner:

```bash
./master_run_all.sh
```

### 2. Running Remediation

**⚠️ WARNING:** Remediation scripts modify system configurations.
*   **Review the script first.**
*   **Test in a non-production environment.**
*   Some changes require a service restart (e.g., Kubelet, Etcd) to take effect. The scripts generally do **not** restart services automatically to prevent outages.

To remediate a specific check:

```bash
./Level_1_Master_Node/1.1.1_remediate.sh
```

## Important Notes

*   **Manual Intervention:** Some checks cannot be safely automated (e.g., changing `--pod-network-cidr`). In these cases, the remediation script will print instructions for manual changes.
*   **Service Restarts:** After modifying configuration files (e.g., `/etc/kubernetes/manifests/kube-apiserver.yaml` or `/var/lib/kubelet/config.yaml`), you must often restart the service or let the Kubelet pick up the changes.
    *   Static pods (apiserver, etcd, etc.) usually restart automatically when the manifest changes.
    *   Kubelet usually requires `systemctl daemon-reload && systemctl restart kubelet`.

## Disclaimer

These scripts are provided "as is" without warranty of any kind. The user assumes all risk associated with their use.
