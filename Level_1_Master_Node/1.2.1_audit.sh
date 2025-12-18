#!/bin/bash
# CIS Benchmark: 1.2.1
# Title: Ensure that the --anonymous-auth argument is set to false (Manual)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.1 (Dual-Layer Verification)..."
	
	MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
	PROCESS_NAME="kube-apiserver"
	# For 1.2.1, we want to ensure --anonymous-auth=false is present
	EXPECTED_PATTERN="--anonymous-auth=false"
	
	RUNTIME_MATCH=0
	FILE_MATCH=0

	# Layer 1: Runtime Check
	if ps -ef | grep "$PROCESS_NAME" | grep -v grep | grep -E -q -- "$EXPECTED_PATTERN(\s|$)"; then
		RUNTIME_MATCH=1
	else
		RUNTIME_MATCH=0
	fi

	# Layer 2: Persistence Check
	if [ -f "$MANIFEST_FILE" ]; then
		if grep -E -q -- "$EXPECTED_PATTERN" "$MANIFEST_FILE"; then
			FILE_MATCH=1
		else
			FILE_MATCH=0
		fi
	else
		echo "[WARN] Manifest file $MANIFEST_FILE not found"
		FILE_MATCH=0
	fi

	# Dual-Layer Evaluation Logic
	if [ $RUNTIME_MATCH -eq 1 ] && [ $FILE_MATCH -eq 1 ]; then
		echo "[INFO] Check Passed: Both Runtime and Config File are correctly set."
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" " - Runtime: OK ($EXPECTED_PATTERN found)" " - Persistence: OK ($EXPECTED_PATTERN found in manifest)"
		return 0
	elif [ $RUNTIME_MATCH -eq 1 ] && [ $FILE_MATCH -eq 0 ]; then
		echo "[INFO] Check Failed: Config not persistent - Time bomb detected"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Config not persistent - Time bomb detected" " - Runtime: OK" " - Persistence: FAIL ($EXPECTED_PATTERN NOT found in $MANIFEST_FILE)"
		echo "[FAIL_REASON] Config not persistent: The running process is correct, but the manifest file is missing the setting. It will revert on next restart."
		return 1
	elif [ $RUNTIME_MATCH -eq 0 ] && [ $FILE_MATCH -eq 1 ]; then
		echo "[INFO] Check Failed: Config not applied - Restart required"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Config not applied - Restart required" " - Runtime: FAIL ($EXPECTED_PATTERN NOT found in process)" " - Persistence: OK"
		echo "[FAIL_REASON] Config not applied: The manifest file is correct, but the running process has not picked up the changes yet. A restart is required."
		return 1
	else
		echo "[INFO] Check Failed: Both Runtime and Config File are incorrect"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Both Runtime and Config File are incorrect" " - Runtime: FAIL" " - Persistence: FAIL"
		echo "[FAIL_REASON] Total Failure: Both the running process and the manifest file are missing the required setting."
		echo "[FIX_HINT] Run remediation script: 1.2.1_remediate.sh"
		return 1
	fi
}

audit_rule
exit $?
