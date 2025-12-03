#!/bin/bash
# CIS Kubernetes Benchmark Master Runner
# Executes all audit scripts across all levels

set -e

echo "=========================================="
echo "CIS Kubernetes Benchmark Audit Runner"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

run_audit_in_directory() {
	local dir="$1"
	local dir_name=$(basename "$dir")
	
	echo "${YELLOW}[*] Processing Level: $dir_name${NC}"
	
	# Find all audit scripts in this directory
	for audit_script in "$dir"/*_audit.sh; do
		if [ -f "$audit_script" ]; then
			script_name=$(basename "$audit_script")
			echo ""
			echo "${YELLOW}[*] Running: $script_name${NC}"
			
			# Run the audit script and capture exit code
			if bash "$audit_script"; then
				((TOTAL_PASS++))
			else
				((TOTAL_FAIL++))
			fi
		fi
	done
}

# Iterate through all level directories
for level_dir in "$SCRIPT_DIR"/Level_*/; do
	if [ -d "$level_dir" ]; then
		run_audit_in_directory "$level_dir"
	fi
done

echo ""
echo "=========================================="
echo "${GREEN}[+] Audit Complete${NC}"
echo "=========================================="
echo "Total Passed: ${GREEN}$TOTAL_PASS${NC}"
echo "Total Failed: ${RED}$TOTAL_FAIL${NC}"
echo ""
