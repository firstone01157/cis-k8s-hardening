#!/bin/bash
# CIS Benchmark: 1.2.6
# Title: Ensure that the --authorization-mode argument is not set to AlwaysAllow (Automated)
# Level: • Level 1 - Master Node

audit_rule() {
	echo "[INFO] Starting check for 1.2.6 (Dual-Layer Verification)..."
	
	MANIFEST_FILE="/etc/kubernetes/manifests/kube-apiserver.yaml"
	PROCESS_NAME="kube-apiserver"
	# For 1.2.6, we want to ensure AlwaysAllow is NOT present
	BAD_PATTERN="--authorization-mode=.*AlwaysAllow"
	
	RUNTIME_SECURE=0
	FILE_SECURE=0

	# Layer 1: Runtime Check (Check if AlwaysAllow is NOT in the running process)
	if ps -ef | grep "$PROCESS_NAME" | grep -v grep | grep -E -q -- "$BAD_PATTERN"; then
		RUNTIME_SECURE=0 # Found AlwaysAllow -> Insecure
	else
		RUNTIME_SECURE=1 # Not found -> Secure
	fi

	# Layer 2: Persistence Check (Check if AlwaysAllow is NOT in the manifest file)
	if [ -f "$MANIFEST_FILE" ]; then
		if grep -E -q -- "$BAD_PATTERN" "$MANIFEST_FILE"; then
			FILE_SECURE=0 # Found AlwaysAllow -> Insecure
		else
			FILE_SECURE=1 # Not found -> Secure
		fi
	else
		echo "[WARN] Manifest file $MANIFEST_FILE not found"
		FILE_SECURE=0
	fi

	# Dual-Layer Evaluation Logic
	if [ $RUNTIME_SECURE -eq 1 ] && [ $FILE_SECURE -eq 1 ]; then
		echo "[INFO] Check Passed: Both Runtime and Config File are secure."
		printf '%s\n' "" "- Audit Result:" "  [+] PASS" " - Runtime: OK (AlwaysAllow not found)" " - Persistence: OK (AlwaysAllow not found in manifest)"
		return 0
	elif [ $RUNTIME_SECURE -eq 1 ] && [ $FILE_SECURE -eq 0 ]; then
		echo "[INFO] Check Failed: Config not persistent - Time bomb detected"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Config not persistent - Time bomb detected" " - Runtime: OK" " - Persistence: FAIL (AlwaysAllow found in $MANIFEST_FILE)"
		echo "[FAIL_REASON] Config not persistent: The running process is secure, but the manifest file contains insecure settings that will apply on next restart."
		return 1
	elif [ $RUNTIME_SECURE -eq 0 ] && [ $FILE_SECURE -eq 1 ]; then
		echo "[INFO] Check Failed: Config not applied - Restart required"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Config not applied - Restart required" " - Runtime: FAIL (AlwaysAllow found in process)" " - Persistence: OK"
		echo "[FAIL_REASON] Config not applied: The manifest file is secure, but the running process is still using insecure settings. A restart is required."
		return 1
	else
		echo "[INFO] Check Failed: Both Runtime and Config File are insecure"
		printf '%s\n' "" "- Audit Result:" "  [-] FAIL" " - Reason: Both Runtime and Config File are insecure" " - Runtime: FAIL" " - Persistence: FAIL"
		echo "[FAIL_REASON] Total Failure: Both the running process and the manifest file are insecure."
		echo "[FIX_HINT] Run remediation script: 1.2.6_remediate.sh"
		return 1
	fi
}

audit_rule
exit $?
