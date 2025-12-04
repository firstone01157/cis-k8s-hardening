#!/bin/bash
# Quick Reference Commands for Manual Exit Code Update

# =============================================================================
# OPTION 1: Full Automated Update (RECOMMENDED) - Interactive with verification
# =============================================================================
echo "OPTION 1: Automated Safe Update"
echo "Command: bash batch_update_manual_exit_codes.sh"
echo ""

# =============================================================================
# OPTION 2: Quick One-Liner - Updates all without prompts
# =============================================================================
echo "OPTION 2: Quick One-Liner (No Prompts)"
echo "Command:"
cat << 'ONELINER'
cd /home/first/Project/cis-k8s-hardening && find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then if grep -q "^exit 0$" "$f"; then echo "[UPDATE] $f" && sed -i 's/^exit 0$/exit 3/' "$f"; fi; fi; done
ONELINER
echo ""

# =============================================================================
# OPTION 3: Preview Only - See changes without executing
# =============================================================================
echo "OPTION 3: Preview Only"
echo "Command:"
cat << 'PREVIEW'
cd /home/first/Project/cis-k8s-hardening && find . -name "*.sh" -type f ! -path "*/backups/*" | while read -r f; do if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then if grep -q "^exit 0$" "$f"; then echo "[WOULD UPDATE] $f"; head -5 "$f" | grep "# Title:"; fi; fi; done
PREVIEW
echo ""

# =============================================================================
# VERIFICATION COMMAND - Check what was updated
# =============================================================================
echo "VERIFICATION: Count scripts by exit code"
echo "Command:"
cat << 'VERIFY'
cd /home/first/Project/cis-k8s-hardening && echo "Exit Code 3 (Manual):" && find . -name "*.sh" ! -path "*/backups/*" -exec grep -l "^exit 3$" {} \; | wc -l && echo "Exit Code 0 (Standard):" && find . -name "*.sh" ! -path "*/backups/*" -exec grep -l "^exit 0$" {} \; | wc -l
VERIFY
echo ""

# =============================================================================
# DETAILED VERIFICATION - See each script's exit code
# =============================================================================
echo "DETAILED VERIFICATION: See each script's exit code"
echo "Command:"
cat << 'DETAIL'
cd /home/first/Project/cis-k8s-hardening && find . -name "*.sh" ! -path "*/backups/*" | while read -r f; do if head -20 "$f" | grep -q "# Title:.*\(Manual\)"; then printf "%-60s %s\n" "$f:" "$(tail -1 "$f")"; fi; done | sort
DETAIL
