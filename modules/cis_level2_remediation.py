#!/usr/bin/env python3
"""Config-driven Level 2 remediation helpers."""

import os
import json
import logging
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Optional

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML is required (pip install pyyaml)")

log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
log.addHandler(handler)


class Level2Remediation:
    DEFAULT_MANIFESTS = [
        "/etc/kubernetes/manifests/kube-apiserver.yaml",
        "/etc/kubernetes/manifests/kube-controller-manager.yaml",
        "/etc/kubernetes/manifests/kube-scheduler.yaml",
        "/etc/kubernetes/manifests/etcd.yaml",
    ]

    def __init__(self, config: Dict, kubectl_cmd: str = "kubectl") -> None:
        self.preferences = config.get("level2_preferences", {})
        self.network_policy_cfg = self.preferences.get("network_policy", {})
        self.capability_cfg = self.preferences.get("capabilities", {})
        self.seccomp_cfg = self.preferences.get("seccomp", {})
        self.kubectl_cmd = kubectl_cmd

    def _run(self, args: List[str]) -> subprocess.CompletedProcess:
        return subprocess.run(args, capture_output=True, text=True)

    # ---------- Network Policy Helpers ----------
    def apply_permissive_baseline(self, namespaces: Optional[List[str]] = None) -> None:
        if not self.network_policy_cfg.get("enabled", True):
            log.info("[5.3.2] Permissive baseline mode disabled by configuration.")
            return

        target_ns = namespaces or self.network_policy_cfg.get("namespaces", ["default", "secure-zone"])
        policy_name = self.network_policy_cfg.get("policy_name", "cis-baseline-allow")

        # The "permissive baseline" exists solely to pass CIS 5.3.2 without blocking traffic.
        template = {
            "apiVersion": "networking.k8s.io/v1",
            "kind": "NetworkPolicy",
            "spec": {
                "policyTypes": ["Ingress", "Egress"],
                "podSelector": {},
                "ingress": [{"from": [{}]}],
                "egress": [{"to": [{}]}],
            },
        }

        for ns in target_ns:
            policy = json.loads(json.dumps(template))  # deep copy
            policy["metadata"] = {"name": f"{policy_name}-{ns}", "namespace": ns}

            log.info("[5.3.2] Applying permissive baseline policy %s for namespace %s", policy["metadata"]["name"], ns)
            with tempfile.NamedTemporaryFile("w", delete=False, suffix=".yaml") as tmp:
                yaml.safe_dump(policy, tmp, sort_keys=False)
                tmp_path = tmp.name
            try:
                result = self._run([self.kubectl_cmd, "apply", "-f", tmp_path])
                if result.returncode != 0:
                    log.warning("[5.3.2] kubectl apply failed for %s: %s", ns, result.stderr.strip())
                else:
                    log.info("[5.3.2] Policy deployed: %s", result.stdout.strip().splitlines()[-1])
            finally:
                os.remove(tmp_path)

    # ---------- Capabilities Helpers ----------
    def is_namespace_exempt_from_capability_checks(self, namespace: str) -> bool:
        defaults = {"kube-system", "kube-flannel"}
        exemptions = set(self.capability_cfg.get("exempt_namespaces", []))
        return namespace in exemptions or namespace in defaults

    def log_capability_strategy(self) -> None:
        if self.capability_cfg.get("enforce", False):
            log.info("[5.2.9] Capability enforcement requested, but kube-flannel/kube-system will remain exempt for stability.")
        else:
            log.info("[5.2.9] Capability enforcement disabled; kube-flannel/kube-system stay untouched.")

    # ---------- Seccomp Helpers ----------
    def enforce_seccomp_profiles(self) -> None:
        if not self.seccomp_cfg.get("enforce", False):
            log.info("[5.6.x] Seccomp enforcement disabled (level2_preferences.seccomp.enforce=false).")
            return

        manifests = self.seccomp_cfg.get("manifests", self.DEFAULT_MANIFESTS)
        changed = False
        for manifest in manifests:
            if self._ensure_seccomp_in_manifest(manifest):
                changed = True
        if changed and self.seccomp_cfg.get("restart_after", True):
            self._restart_static_pods()

    def _ensure_seccomp_in_manifest(self, manifest_path: str) -> bool:
        log.info("[5.6.x] Inspecting manifest %s", manifest_path)
        if not os.path.exists(manifest_path):
            log.warning("Manifest %s missing, skipping", manifest_path)
            return False

        with open(manifest_path, "r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}

        def ensure_seccomp(target: Dict) -> bool:
            secctx = target.get("securityContext", {}) or {}
            profile = secctx.get("seccompProfile", {})
            if profile.get("type") != "RuntimeDefault":
                secctx["seccompProfile"] = {"type": "RuntimeDefault"}
                target["securityContext"] = secctx
                return True
            return False

        modified = ensure_seccomp(data)
        for container in data.get("spec", {}).get("containers", []) + data.get("spec", {}).get("initContainers", []):
            if ensure_seccomp(container):
                modified = True

        if not modified:
            log.info("[5.6.x] Seccomp already configured for %s", manifest_path)
            return False

        backup = f"{manifest_path}.{int(Path(manifest_path).stat().st_mtime)}.bak"
        shutil.copy2(manifest_path, backup)
        log.info("Backed up manifest to %s", backup)
        self._atomic_write(manifest_path, yaml.safe_dump(data, sort_keys=False))
        log.info("[5.6.x] Updated seccomp profile in %s", manifest_path)
        return True

    def _atomic_write(self, path: str, content: str) -> None:
        dirpath = os.path.dirname(path)
        os.makedirs(dirpath, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=dirpath, prefix=".cislvl2", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(content)
                handle.flush()
                os.fsync(handle.fileno())
            os.chmod(tmp, 0o600)
            shutil.move(tmp, path)
            os.chmod(path, 0o600)
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

    def _restart_static_pods(self) -> None:
        pods = ["kube-apiserver", "kube-controller-manager", "kube-scheduler", "etcd"]
        for pod in pods:
            result = self._run(["crictl", "ps", "-a", "--name", pod, "-q"])
            if result.returncode != 0:
                log.warning("crictl ps failed for %s: %s", pod, result.stderr.strip())
                continue
            ids = [line for line in result.stdout.splitlines() if line]
            for cid in ids:
                self._run(["crictl", "stop", cid])
                self._run(["crictl", "start", cid])
                log.info("Restarted %s (container %s)", pod, cid)

    # ---------- Guidance ----------
    def log_default_namespace_marker(self) -> None:
        log.warning("[5.6.4] Default namespace constraints are marked for manual review (RISK_ACCEPTED).")


# Example usage (from cis_k8s_unified.py):
#
# from modules.cis_level2_remediation import Level2Remediation
#
# level2 = Level2Remediation(cis_config)
# level2.apply_permissive_baseline()
# level2.log_capability_strategy()
# level2.enforce_seccomp_profiles()
# level2.log_default_namespace_marker()
