#!/usr/bin/env python3
"""Mark selected CIS checks as audit-only (skip remediation) in cis_config.json."""

import json
from pathlib import Path
from typing import Dict, Iterable


CONFIG_PATH = Path(__file__).resolve().parents[1] / "cis_config.json"

# TODO: Replace with your actual Ghost checks list.
GHOST_CHECK_IDS = [
    "5.2.2",
    "1.1.12",
]


def _update_check(checks: Dict[str, Dict], check_id: str) -> bool:
    cfg = checks.get(check_id)
    if not isinstance(cfg, dict):
        return False
    cfg["enabled"] = False
    cfg["remediation"] = "manual"
    return True


def _update_level_checks(level_checks: Dict[str, Dict], ghost_ids: Iterable[str]) -> int:
    updated = 0
    for check_id in ghost_ids:
        if _update_check(level_checks, check_id):
            updated += 1
    return updated


def main() -> None:
    if not CONFIG_PATH.exists():
        raise SystemExit(f"Config not found: {CONFIG_PATH}")

    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    remediation = data.get("remediation_config", {})
    checks = remediation.get("checks", {})
    if not isinstance(checks, dict):
        raise SystemExit("remediation_config.checks must be a dict")

    total_updated = 0
    for level_key in ("L1", "L2"):
        level_checks = checks.get(level_key, {})
        if isinstance(level_checks, dict):
            total_updated += _update_level_checks(level_checks, GHOST_CHECK_IDS)

    if total_updated == 0:
        print("No matching checks updated. Verify GHOST_CHECK_IDS.")
    else:
        with CONFIG_PATH.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=4, ensure_ascii=False)
        print(f"Updated {total_updated} checks in {CONFIG_PATH}.")


if __name__ == "__main__":
    main()
