"""Helper utilities to standardize verification loops and container state checks."""
from __future__ import annotations

import subprocess
import time
from typing import Callable, Optional, Set, Tuple

AuditCallback = Callable[[], Tuple[str, str]]


def is_component_ready(component_name: str) -> bool:
    """Return True if the named component has any running containers."""
    try:
        result = subprocess.run(
            ["crictl", "ps", "--name", component_name, "-q", "--state", "Running"],
            capture_output=True,
            text=True,
            check=False,
        )
        return bool(result.stdout.strip())
    except FileNotFoundError:
        # crictl might not exist on all systems; treat missing binary as not ready
        return False


def get_component_pids(component_name: str) -> Set[str]:
    """Return PIDs matching the component name so callers can detect restarts."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", component_name],
            capture_output=True,
            text=True,
            check=False,
        )
        return {line.strip() for line in result.stdout.splitlines() if line.strip()}
    except FileNotFoundError:
        return set()


def verify_with_retry(
    audit_function: AuditCallback,
    check_id: str,
    component_name: Optional[str] = None,
    timeout: int = 60,
    max_retries: int = 10,
    sleep_interval: int = 2,
    log_callback: Optional[Callable[[str], None]] = None,
) -> Tuple[str, str]:
    """Run the provided audit function until it passes or the retry cap is reached."""
    start_time = time.time()
    attempt = 0

    while attempt < max_retries and time.time() - start_time < timeout:
        attempt += 1
        if component_name and not is_component_ready(component_name):
            if log_callback:
                log_callback(
                    f"{check_id}: {component_name} not Ready yet (attempt {attempt}/{max_retries})."
                )
            time.sleep(sleep_interval)
            continue

        try:
            status, reason = audit_function()
        except subprocess.TimeoutExpired:
            if log_callback:
                log_callback(
                    f"{check_id}: audit timed out on attempt {attempt}/{max_retries}."
                )
            time.sleep(sleep_interval)
            continue
        except Exception as exc:  # pragma: no cover - defensive
            if log_callback:
                log_callback(f"{check_id}: verification failed with error: {exc}")
            return "ERROR", str(exc)

        if status in {"PASS", "FIXED"}:
            return status, reason

        if log_callback:
            log_callback(
                f"{check_id} still not compliant ({status}). Retrying (attempt {attempt}/{max_retries})..."
            )
        time.sleep(sleep_interval)

    if attempt >= max_retries:
        warning = f"[!] Verification failed for {check_id} after maximum retries. Possible template mismatch."
        if log_callback:
            log_callback(warning)
        return "FAIL", warning

    warning = f"[!] Remediation Failed (Timeout) for {check_id}."
    if log_callback:
        log_callback(warning)
    return "FAIL", "Remediation failed (timeout)"


def wait_for_api_ready(
    timeout: int = 60,
    interval: int = 2,
    log_callback: Optional[Callable[[str], None]] = None,
) -> bool:
    """Wait for kubectl (or curl) against the API server before running commands."""

    def _run_curl(url: str, insecure: bool = False) -> Tuple[bool, str]:
        cmd = ["curl", "-sSf", "--max-time", "3"]
        if insecure:
            cmd.append("--insecure")
        cmd.append(url)
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            raise
        stderr = (result.stderr or "").lower()
        return result.returncode == 0, stderr

    start = time.time()
    while time.time() - start < timeout:
        try:
            accessible, stderr = _run_curl("http://127.0.0.1:8080/livez")
        except FileNotFoundError:
            if log_callback:
                log_callback("curl binary is missing; cannot verify API readiness.")
            return False

        if accessible:
            if log_callback:
                log_callback("[INFO] API accessible via insecure port 8080")
            return True

        if "connection refused" in stderr:
            try:
                secure_accessible, _ = _run_curl(
                    "https://127.0.0.1:6443/livez", insecure=True
                )
            except FileNotFoundError:
                if log_callback:
                    log_callback("curl binary is missing; cannot verify API readiness.")
                return False
            if secure_accessible:
                if log_callback:
                    log_callback("[INFO] API accessible via secure port 6443")
                return True
            if log_callback:
                log_callback(
                    "Waiting for Kubernetes API to become reachable (both ports failed)."
                )
            time.sleep(interval)
            continue

        if log_callback:
            log_callback("Waiting for Kubernetes API to become reachable (insecure port returned error).")
        time.sleep(interval)

    if log_callback:
        log_callback("Timed out waiting for Kubernetes API readiness.")
    return False
