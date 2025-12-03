#!/bin/bash
# CIS Master Runner: REMEDIATION
# WARNING: This script WILL apply changes to your system!

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo -e "${RED}    WARNING: REMEDIATION MODE    ${NC}"
echo "    Are you sure you want to proceed?"
echo "    This will apply fixes to your system."
echo "=========================================="
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Iterate through all Level directories
for level_dir in "$SCRIPT_DIR"/Level_*/; do
    if [ -d "$level_dir" ]; then
        dir_name=$(basename "$level_dir")
        echo -e "${YELLOW}Fixing in: $dir_name${NC}"
        
        # Find only *_remediate.sh files
        for script in "$level_dir"/*_remediate.sh; do
            if [ -f "$script" ]; then
                script_name=$(basename "$script")
                echo "Running fix: $script_name"
                
                # Run the remediation script
                bash "$script"
            fi
        done
    fi
done

echo ""
echo "=========================================="
echo -e "${GREEN}[+] Remediation Run Complete${NC}"
echo "=========================================="
echo "Please run './master_audit_only.sh' again to verify fixes."
echo ""