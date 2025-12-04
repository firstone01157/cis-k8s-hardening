#!/bin/bash
################################################################################
# Batch Update Manual Check Exit Codes (exit 0 -> exit 3)
# Purpose: Update all scripts with "(Manual)" in their title to use exit code 3
# Safety: Creates backups and allows rollback
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups/manual_exit_code_update_$(date +%Y%m%d_%H%M%S)"
TEMP_FILE="/tmp/manual_scripts_$$.txt"
CHANGES_LOG="${SCRIPT_DIR}/batch_update_changes_$(date +%Y%m%d_%H%M%S).log"

# Counters
TOTAL_SCRIPTS=0
UPDATED_SCRIPTS=0
FAILED_SCRIPTS=0
ALREADY_EXIT3=0

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Batch Update: Manual Check Exit Codes (exit 0 → exit 3)      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"

################################################################################
# STEP 1: Find all scripts with "(Manual)" in their title
################################################################################
echo -e "${BLUE}[STEP 1] Scanning for scripts with '(Manual)' in their title...${NC}"

mapfile -t manual_scripts < <(
    find "${SCRIPT_DIR}" -name "*.sh" -type f ! -path "*/backups/*" ! -name "batch_update*" | while read -r script; do
        if head -20 "$script" | grep -q "# Title:.*\(Manual\)"; then
            echo "$script"
        fi
    done
)

TOTAL_SCRIPTS=${#manual_scripts[@]}

if [ $TOTAL_SCRIPTS -eq 0 ]; then
    echo -e "${YELLOW}[!] No scripts with '(Manual)' found.${NC}"
    rm -f "$TEMP_FILE"
    exit 0
fi

echo -e "${GREEN}[✓] Found ${TOTAL_SCRIPTS} scripts${NC}\n"

################################################################################
# STEP 2: Create backup directory
################################################################################
echo -e "${BLUE}[STEP 2] Creating backups...${NC}"
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}[✓] Backup directory: ${BACKUP_DIR}${NC}\n"

################################################################################
# STEP 3: Preview changes and collect stats
################################################################################
echo -e "${BLUE}[STEP 3] Analyzing scripts for changes...${NC}\n"
echo "Script Analysis Report:" > "$CHANGES_LOG"
echo "======================" >> "$CHANGES_LOG"
echo "" >> "$CHANGES_LOG"

for script in "${manual_scripts[@]}"; do
    relative_path="${script#${SCRIPT_DIR}/}"
    
    # Extract title
    title=$(head -20 "$script" | grep "# Title:" | head -1 | sed 's/.*# Title: //' | sed 's/ (Manual).*//')
    
    # Backup the file
    cp "$script" "${BACKUP_DIR}/$(basename "$script")"
    
    # Check current exit code
    if grep -q "^exit 0$" "$script"; then
        echo -e "  ${YELLOW}[TO UPDATE]${NC} $relative_path"
        echo "    Title: $title"
        echo "    Current: exit 0 → Will change to: exit 3"
        ((UPDATED_SCRIPTS++))
        
        echo "" >> "$CHANGES_LOG"
        echo "FILE: $relative_path" >> "$CHANGES_LOG"
        echo "TITLE: $title" >> "$CHANGES_LOG"
        echo "CHANGE: exit 0 → exit 3" >> "$CHANGES_LOG"
        
    elif grep -q "^exit 3$" "$script"; then
        echo -e "  ${GREEN}[ALREADY EXIT 3]${NC} $relative_path"
        echo "    Title: $title"
        ((ALREADY_EXIT3++))
        
    else
        echo -e "  ${RED}[NO STANDARD EXIT]${NC} $relative_path"
        echo "    Title: $title"
        echo "    Current exit code: $(tail -1 "$script")"
        ((FAILED_SCRIPTS++))
    fi
done

echo ""
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "Summary:"
echo -e "  Total Scripts:       ${TOTAL_SCRIPTS}"
echo -e "  ${YELLOW}To Update:${NC}           ${UPDATED_SCRIPTS}"
echo -e "  ${GREEN}Already Exit 3:${NC}      ${ALREADY_EXIT3}"
echo -e "  ${RED}No Standard Exit:${NC}    ${FAILED_SCRIPTS}"
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}\n"

################################################################################
# STEP 4: User confirmation
################################################################################
if [ $UPDATED_SCRIPTS -eq 0 ]; then
    echo -e "${GREEN}[!] No scripts need updating. Exit codes are already correct.${NC}"
    rm -f "$TEMP_FILE"
    exit 0
fi

echo -e "${YELLOW}[!] IMPORTANT: Review the changes above carefully!${NC}"
echo -e "    Backups have been created in: ${BACKUP_DIR}\n"

read -p "Continue with the update? [y/n]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}[✗] Update cancelled. Backups retained in ${BACKUP_DIR}${NC}"
    rm -f "$TEMP_FILE"
    exit 0
fi

echo ""

################################################################################
# STEP 5: Perform updates
################################################################################
echo -e "${BLUE}[STEP 4] Executing updates...${NC}\n"

update_count=0
for script in "${manual_scripts[@]}"; do
    relative_path="${script#${SCRIPT_DIR}/}"
    
    if grep -q "^exit 0$" "$script"; then
        # Use sed to replace the final "exit 0" with "exit 3"
        # This is safe because we only target the exact line "exit 0" at EOF
        if sed -i.bak 's/^exit 0$/exit 3/' "$script"; then
            ((update_count++))
            echo -e "  ${GREEN}[✓]${NC} Updated: $relative_path"
            
            # Verify the change
            if grep -q "^exit 3$" "$script"; then
                echo -e "       ${CYAN}Verified: exit code changed to 3${NC}"
            else
                echo -e "       ${RED}ERROR: Verification failed!${NC}"
                # Restore from backup
                cp "${BACKUP_DIR}/$(basename "$script")" "$script"
                echo -e "       ${YELLOW}Restored from backup${NC}"
                ((update_count--))
                ((FAILED_SCRIPTS++))
            fi
        else
            echo -e "  ${RED}[✗]${NC} Failed: $relative_path"
            ((FAILED_SCRIPTS++))
        fi
        
        # Clean up sed backup files
        rm -f "${script}.bak"
    fi
done

echo ""

################################################################################
# STEP 6: Summary
################################################################################
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                        OPERATION COMPLETE                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"

if [ $update_count -gt 0 ]; then
    echo -e "${GREEN}[✓] Successfully updated ${update_count} script(s)${NC}"
    echo -e "    Exit codes changed: exit 0 → exit 3\n"
fi

if [ $FAILED_SCRIPTS -gt 0 ]; then
    echo -e "${RED}[✗] Failed to update ${FAILED_SCRIPTS} script(s)${NC}"
    echo -e "    Check the errors above for details\n"
fi

if [ $ALREADY_EXIT3 -gt 0 ]; then
    echo -e "${GREEN}[✓] ${ALREADY_EXIT3} script(s) already had exit code 3${NC}\n"
fi

echo -e "${YELLOW}Backups preserved in:${NC} ${BACKUP_DIR}"
echo -e "${YELLOW}Changes logged in:${NC}    ${CHANGES_LOG}\n"

################################################################################
# STEP 7: Rollback instructions
################################################################################
if [ $update_count -gt 0 ]; then
    echo -e "${CYAN}To rollback these changes, run:${NC}"
    echo -e "  ${BLUE}cp \"${BACKUP_DIR}\"/* \"${SCRIPT_DIR}/\"${NC}\n"
fi

# Cleanup
rm -f "$TEMP_FILE"

exit 0
