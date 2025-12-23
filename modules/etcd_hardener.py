#!/usr/bin/env python3
"""Etcd hardening helper that safely enforces CIS flags."""

from __future__ import annotations

import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - runtime dependency
    yaml = None

MANIFEST_PATH = Path("/etc/kubernetes/manifests/etcd.yaml")
BACKUP_PATH = Path("/tmp/etcd.yaml.bak")
HEALTH_CHECK_TIMEOUT = 60
FLAGS = {
    "--cert-file": "/etc/kubernetes/pki/etcd/server.crt",
    "--key-file": "/etc/kubernetes/pki/etcd/server.key",
    "--peer-cert-file": "/etc/kubernetes/pki/etcd/peer.crt",
    "--peer-key-file": "/etc/kubernetes/pki/etcd/peer.key",
    "--trusted-ca-file": "/etc/kubernetes/pki/etcd/ca.crt",
    "--peer-trusted-ca-file": "/etc/kubernetes/pki/etcd/ca.crt",
    "--client-cert-auth": "true",
    "--peer-client-cert-auth": "true",
    "--auto-tls": "false",
    "--peer-auto-tls": "false",
}
CERT_FILES = {
    "/etc/kubernetes/pki/etcd/server.crt",
    "/etc/kubernetes/pki/etcd/server.key",
    "/etc/kubernetes/pki/etcd/peer.crt",
    "/etc/kubernetes/pki/etcd/peer.key",
    "/etc/kubernetes/pki/etcd/ca.crt",
}


def check_certificates() -> None:
    missing = [path for path in CERT_FILES if not os.path.exists(path)]
    if missing:
        print("[ERROR] Missing certificates. Aborting.")
        for path in missing:
            print(f"  - {path}")
        sys.exit(1)


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        print(f"[ERROR] Etcd manifest not found: {MANIFEST_PATH}")
        sys.exit(1)

    if yaml is None:
        print("[ERROR] PyYAML is required for rendering the manifest.")
        sys.exit(1)

    with MANIFEST_PATH.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh) or {}


def write_manifest(data: dict) -> None:
    if yaml is None:
        print("[ERROR] PyYAML is required for rendering the manifest.")
        sys.exit(1)

    with MANIFEST_PATH.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(
            data,
            fh,
            default_flow_style=False,
            sort_keys=False,
            indent=2,
        )


def backup_manifest() -> None:
    shutil.copy2(MANIFEST_PATH, BACKUP_PATH)


def restore_manifest() -> None:
    if BACKUP_PATH.exists():
        shutil.copy2(BACKUP_PATH, MANIFEST_PATH)


def restart_etcd() -> None:
    subprocess.run(
        "crictl pods --name etcd -q | xargs -r crictl stopp",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    subprocess.run(
        "crictl pods --name etcd -q | xargs -r crictl rmp",
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def enforce_flags(data: dict) -> None:
    spec = data.setdefault("spec", {})
    containers = spec.setdefault("containers", [])

    if not containers:
        print("[ERROR] Etcd manifest does not declare any containers.")
        sys.exit(1)

    command = containers[0].setdefault("command", [])

    def matches(flag: str, token: str) -> bool:
        return token == flag or token.startswith(f"{flag}=")

    filtered = [token for token in command if not any(matches(flag, token) for flag in FLAGS)]
    containers[0]["command"] = filtered + [f"{flag}={value}" for flag, value in FLAGS.items()]


def is_port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.5):
            return True
    except (OSError, socket.timeout):
        return False


def wait_for_health(timeout: int) -> bool:
    start = time.monotonic()
    while time.monotonic() - start < timeout:
        if is_port_open(2379):
            return True
        time.sleep(1)
    return False


def main() -> None:
    check_certificates()
    backup_manifest()
    manifest = load_manifest()
    enforce_flags(manifest)
    write_manifest(manifest)

    restart_etcd()

    if wait_for_health(HEALTH_CHECK_TIMEOUT):
        print("[SUCCESS] Etcd hardened and healthy.")
        sys.exit(0)

    print("[CRITICAL] Etcd failed to start! Rolling back...")
    restore_manifest()
    restart_etcd()
    sys.exit(1)


if __name__ == "__main__":
    main()
