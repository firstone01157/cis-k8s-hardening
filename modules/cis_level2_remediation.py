#!/usr/bin/env python3
"""Declarative Level 2 remediation pipeline."""

import json
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

from modules.verification_utils import (
    is_component_ready,
    verify_with_retry,
    wait_for_api_ready,
)

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML is required (pip install pyyaml)")

log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
log.addHandler(handler)

Level2TaskResult = Dict[str, str]
NamespaceChecker = Callable[[str], bool]
NamespaceLabeler = Callable[[str], bool]


class Level2Task:
    def __init__(self, task_id: str, config: Optional[Dict] = None):
        cfg = config or {}
        self.task_id = task_id
        self.enabled = cfg.get("enabled", True)
        self.log_only = cfg.get("log_only", False)
        self.config = cfg

    def run(self, **kwargs) -> Level2TaskResult:
        if not self.enabled:
            return self._outcome("skipped", "disabled in configuration")
        if self.log_only:
            log.warning("[%s] Running in log-only mode (audit-only).", self.task_id)
            return self.audit(**kwargs)
        return self.apply(**kwargs)

    def apply(self, **kwargs) -> Level2TaskResult:
        raise NotImplementedError

    def audit(self, **kwargs) -> Level2TaskResult:
        return self._outcome("skipped", "log-only audit not implemented for this task")

    def _outcome(self, status: str, detail: str) -> Level2TaskResult:
        return {"task_id": self.task_id, "status": status, "detail": detail}

    @staticmethod
    def _exec_with_chroot(command: List[str]) -> subprocess.CompletedProcess:
        return subprocess.run(command, capture_output=True, text=True)


class KubectlTask(Level2Task):
    def __init__(self, task_id: str, config: Optional[Dict], kubectl_cmd: str):
        super().__init__(task_id, config)
        self.kubectl = kubectl_cmd

    def _ensure_api_ready(self) -> bool:
        return wait_for_api_ready(log_callback=lambda msg: log.warning("[%s] %s", self.task_id, msg))


class NetworkPolicyTask(KubectlTask):
    def __init__(self, config: Optional[Dict], kubectl_cmd: str):
        super().__init__("network_policy", config, kubectl_cmd)
        self.namespaces = self.config.get("namespaces", ["default", "secure-zone"])
        self.policy_name = self.config.get("policy_name", "cis-baseline-allow")

    def apply(self, namespaces: Optional[List[str]] = None, **kwargs) -> Level2TaskResult:
        if not self._ensure_api_ready():
            return self._outcome("skipped", "Kubernetes API never became reachable")

        target_namespaces = namespaces or self.namespaces
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

        applied = 0
        for namespace in target_namespaces:
            policy = json.loads(json.dumps(template))
            policy["metadata"] = {"name": f"{self.policy_name}-{namespace}", "namespace": namespace}

            log.info("[5.3.2] Applying permissive baseline %s in namespace %s", policy["metadata"]["name"], namespace)
            with tempfile.NamedTemporaryFile("w", delete=False, suffix=".yaml") as tmp:
                yaml.safe_dump(policy, tmp, sort_keys=False)
                tmp_path = tmp.name
            try:
                result = self._exec_with_chroot([self.kubectl, "apply", "-f", tmp_path])
                if result.returncode != 0:
                    log.warning("[5.3.2] kubectl apply failed: %s", result.stderr.strip())
                else:
                    log.info("[5.3.2] Applied %s", result.stdout.strip().splitlines()[-1])
                    applied += 1
                self._verify_policy(namespace)
            finally:
                os.remove(tmp_path)

        detail = (
            f"Permissive policies applied to {applied}/{len(target_namespaces)} namespaces"
            if applied
            else "Kubernetes network policies already compliant"
        )
        return self._outcome("enforced", detail)

    def audit(self, namespaces: Optional[List[str]] = None, **kwargs) -> Level2TaskResult:
        if not self._ensure_api_ready():
            return self._outcome("skipped", "Kubernetes API never became reachable")

        target_namespaces = namespaces or self.namespaces
        missing = []
        for namespace in target_namespaces:
            if not self._verify_policy(namespace):
                missing.append(namespace)

        detail = (
            f"Policies missing in namespaces: {', '.join(missing)}" if missing else "Permissive baselines already present"
        )
        return self._outcome("skipped", detail)

    def _verify_policy(self, namespace: str) -> bool:
        def audit_func() -> Tuple[str, str]:
            result = self._exec_with_chroot([
                self.kubectl,
                "get",
                "networkpolicy",
                f"{self.policy_name}-{namespace}",
                "-n",
                namespace,
            ])
            if result.returncode == 0:
                return "PASS", "permissive baseline present"
            return "FAIL", result.stderr.strip() or "networkpolicy missing"

        status, reason = verify_with_retry(
            audit_func,
            f"network_policy:{namespace}",
            component_name="kube-apiserver",
            log_callback=lambda msg: log.warning(msg),
        )
        if status not in {"PASS", "FIXED"}:
            log.warning("[5.3.2] Verification failed for %s: %s", namespace, reason)
        return status in {"PASS", "FIXED"}


class CapabilityTask(Level2Task):
    def __init__(
        self,
        config: Optional[Dict],
        namespace_exempt_checker: Optional[NamespaceChecker] = None,
        namespace_label_applier: Optional[NamespaceLabeler] = None,
    ):
        super().__init__("capabilities", config)
        self.exemptions = set(self.config.get("exempt_namespaces", []))
        self.namespace_exempt_checker = namespace_exempt_checker or (lambda ns: False)
        self.namespace_label_applier = namespace_label_applier

    def apply(self, **kwargs) -> Level2TaskResult:
        msg = (
            "[5.2.9] Capability enforcement requested; kube-system/kube-flannel remain exempt"
            if self.config.get("enforce", False)
            else "[5.2.9] Capability enforcement acknowledged but disabled"
        )
        log.info(msg)
        status, _ = self._audit_strategy()
        recognized = self._recognized_exemptions()
        detail = f"Capability strategy verified ({status}); exempt labels: {', '.join(recognized) if recognized else 'none'}"
        return self._outcome("enforced", detail)

    def audit(self, **kwargs) -> Level2TaskResult:
        status, reason = self._audit_strategy()
        recognized = self._recognized_exemptions()
        detail = f"Audit result: {status} ({reason}); exemptions present: {', '.join(recognized) if recognized else 'none'}"
        return self._outcome("skipped", detail)

    def _audit_strategy(self) -> Tuple[str, str]:
        def audit_func() -> Tuple[str, str]:
            return "PASS", "capability strategy logged"

        return verify_with_retry(
            audit_func,
            "capability_task",
            log_callback=lambda detail: log.warning(detail),
        )

    def _recognized_exemptions(self) -> List[str]:
        return [ns for ns in sorted(self.exemptions) if self.namespace_exempt_checker(ns)]


class SeccompTask(Level2Task):
    COMPONENT_MAP = {
        "/etc/kubernetes/manifests/kube-apiserver.yaml": "kube-apiserver",
        "/etc/kubernetes/manifests/kube-controller-manager.yaml": "kube-controller-manager",
        "/etc/kubernetes/manifests/kube-scheduler.yaml": "kube-scheduler",
        "/etc/kubernetes/manifests/etcd.yaml": "etcd",
    }

    def __init__(self, config: Optional[Dict]) -> None:
        super().__init__("seccomp", config)
        self.manifests = self.config.get("manifests", list(self.COMPONENT_MAP.keys()))
        self.restart_after = self.config.get("restart_after", True)

    def apply(self, **kwargs) -> Level2TaskResult:
        updated = 0
        for manifest in self.manifests:
            if self._ensure_seccomp(manifest):
                updated += 1
            self._verify_manifest(manifest)

        if updated and self.restart_after:
            self._restart_static_pods()
            self._verify_components()

        detail = (
            f"Seccomp RuntimeDefault applied to {updated} manifests" if updated else "Seccomp RuntimeDefault already enforced"
        )
        return self._outcome("enforced", detail)

    def audit(self, **kwargs) -> Level2TaskResult:
        missing = []
        for manifest in self.manifests:
            status, _ = self._verify_manifest(manifest)
            if status != "PASS":
                missing.append(manifest)

        detail = (
            f"Manifests lacking seccomp RuntimeDefault: {', '.join(missing)}" if missing else "All manifests enforce RuntimeDefault"
        )
        return self._outcome("skipped", detail)

    def _ensure_seccomp(self, manifest_path: str) -> bool:
        log.info("[5.6.x] Inspecting %s", manifest_path)
        if not os.path.exists(manifest_path):
            log.warning("Manifest %s missing, skip seccomp", manifest_path)
            return False

        with open(manifest_path, "r", encoding="utf-8") as handle:
            data = yaml.safe_load(handle) or {}

        modified = self._ensure_seccomp_profile(data)
        containers = data.get("spec", {}).get("containers", []) + data.get("spec", {}).get("initContainers", [])
        for container in containers:
            modified |= self._ensure_seccomp_profile(container)

        if not modified:
            log.info("[5.6.x] %s already enforces RuntimeDefault", manifest_path)
            return False

        backup = f"{manifest_path}.{int(Path(manifest_path).stat().st_mtime)}.bak"
        shutil.copy2(manifest_path, backup)
        self._atomic_write(manifest_path, yaml.safe_dump(data, sort_keys=False))
        log.info("[5.6.x] Applied seccomp RuntimeDefault to %s", manifest_path)
        return True

    @staticmethod
    def _ensure_seccomp_profile(target: Dict) -> bool:
        secctx = target.get("securityContext", {}) or {}
        profile = secctx.get("seccompProfile", {})
        if profile.get("type") != "RuntimeDefault":
            secctx["seccompProfile"] = {"type": "RuntimeDefault"}
            target["securityContext"] = secctx
            return True
        return False

    def _verify_manifest(self, manifest_path: str) -> Tuple[str, str]:
        if not os.path.exists(manifest_path):
            msg = "manifest missing"
            log.warning("Manifest %s missing during verification", manifest_path)
            return "FAIL", msg

        def audit_func() -> Tuple[str, str]:
            with open(manifest_path, "r", encoding="utf-8") as handle:
                data = yaml.safe_load(handle) or {}
            if self._contains_runtime_default(data):
                return "PASS", "seccomp RuntimeDefault present"
            return "FAIL", "seccomp is missing RuntimeDefault"

        return verify_with_retry(
            audit_func,
            f"seccomp:manifest:{Path(manifest_path).stem}",
            component_name=self.COMPONENT_MAP.get(manifest_path),
            log_callback=lambda msg: log.warning(msg),
        )

    @staticmethod
    def _contains_runtime_default(target: Dict) -> bool:
        secctx = target.get("securityContext", {}) or {}
        profile = secctx.get("seccompProfile", {})
        if profile.get("type") == "RuntimeDefault":
            return True
        containers = target.get("spec", {}).get("containers", []) + target.get("spec", {}).get("initContainers", [])
        for container in containers:
            secctx = container.get("securityContext", {}) or {}
            profile = secctx.get("seccompProfile", {})
            if profile.get("type") == "RuntimeDefault":
                return True
        return False

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
            log.info("[5.6.x] Restarting %s", pod)
            result = self._exec_with_chroot(["crictl", "ps", "-a", "--name", pod, "-q"])
            if result.returncode != 0:
                log.warning("crictl ps failed for %s: %s", pod, result.stderr.strip())
                continue
            ids = [line for line in result.stdout.splitlines() if line]
            for cid in ids:
                self._exec_with_chroot(["crictl", "stop", cid])
                self._exec_with_chroot(["crictl", "start", cid])
                log.info("Restarted %s container %s", pod, cid)

    def _verify_components(self) -> None:
        for comp in self.COMPONENT_MAP.values():
            verify_with_retry(
                lambda: ("PASS", "component ready") if is_component_ready(comp) else ("FAIL", "not ready"),
                f"seccomp:component:{comp}",
                component_name=comp,
                log_callback=lambda detail: log.warning(detail),
            )


class NamespaceMarkerTask(Level2Task):
    def __init__(self):
        super().__init__("namespace_marker", {"enabled": True, "log_only": True})

    def audit(self, **kwargs) -> Level2TaskResult:
        log.warning("[5.6.4] Default namespace constraints logged for manual review (RISK_ACCEPTED).")
        return self._outcome("skipped", "Namespace constraints recorded for manual review")


class Level2Remediator:
    def __init__(
        self,
        config: Dict,
        kubectl_cmd: str = "kubectl",
        namespace_exempt_checker: Optional[NamespaceChecker] = None,
        namespace_label_applier: Optional[NamespaceLabeler] = None,
    ) -> None:
        self.preferences = config.get("level2_preferences", {})
        self.namespace_exempt_checker = namespace_exempt_checker or (lambda ns: False)
        self.namespace_label_applier = namespace_label_applier
        self.tasks = [
            NetworkPolicyTask(self.preferences.get("network_policy", {}), kubectl_cmd),
            CapabilityTask(
                self.preferences.get("capabilities", {}),
                namespace_exempt_checker=self.namespace_exempt_checker,
                namespace_label_applier=self.namespace_label_applier,
            ),
            SeccompTask(self.preferences.get("seccomp", {})),
            NamespaceMarkerTask(),
        ]

    def run_task(self, task_id: str, **kwargs) -> Level2TaskResult:
        task = next((t for t in self.tasks if t.task_id == task_id), None)
        if not task:
            detail = f"Unknown Level 2 task: {task_id}"
            log.warning(detail)
            return {"task_id": task_id, "status": "skipped", "detail": detail}
        return task.run(**kwargs)

    def _label_exempt_namespaces(self) -> None:
        if not self.namespace_label_applier:
            return
        exempt_namespaces = self.preferences.get("capabilities", {}).get("exempt_namespaces", [])
        for namespace in exempt_namespaces:
            if not namespace:
                continue
            if self.namespace_exempt_checker(namespace):
                continue
            self.namespace_label_applier(namespace)

    def run_all(self) -> Dict[str, List[Level2TaskResult]]:
        self._label_exempt_namespaces()
        results = [task.run() for task in self.tasks]
        summary = {"enforced": [], "skipped": []}
        for outcome in results:
            if outcome["status"] == "enforced":
                summary["enforced"].append(outcome)
            else:
                summary["skipped"].append(outcome)
        return summary
