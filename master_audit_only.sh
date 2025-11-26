#!/bin/bash
# CIS Master Runner: AUDIT ONLY
# This script will ONLY run checks. It will NOT make changes.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "    CIS BENCHMARK: AUDIT MODE ONLY"
echo "=========================================="

# Iterate through all Level directories
for level_dir in "$SCRIPT_DIR"/Level_*/; do
    if [ -d "$level_dir" ]; then
        dir_name=$(basename "$level_dir")
        echo ""
        echo -e "${YELLOW}[Folder] $dir_name${NC}"
        
        # Find only *_audit.sh files
        for script in "$level_dir"/*_audit.sh; do
            if [ -f "$script" ]; then
                script_name=$(basename "$script")
                echo -n "Checking $script_name ... "
                
                # Execute Audit
                if bash "$script" > /dev/null 2>&1; then
                    echo -e "${GREEN}PASS${NC}"
                    ((TOTAL_PASS++))
                else
                    echo -e "${RED}FAIL${NC}"
                    ((TOTAL_FAIL++))
                fi
            fi
        done
    fi
done

echo ""
echo "=========================================="
echo "SUMMARY: AUDIT ONLY"
echo -e "Pass: ${GREEN}$TOTAL_PASS${NC}"
echo -e "Fail: ${RED}$TOTAL_FAIL${NC}"
echo "=========================================="