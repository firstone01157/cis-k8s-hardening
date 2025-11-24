#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark Script Generator (Upgraded)
Reads CSV file and generates audit and remediation Bash scripts
Includes SMART Remediation Logic and Separated Master Runners.
"""

import os
import re
import csv
import sys
from pathlib import Path

# Configuration
CSV_FILE = "CIS_Kubernetes_Benchmark_V1.12.0_PDF.csv"
BASE_OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

# Bash template for audit scripts
AUDIT_SCRIPT_TEMPLATE = """#!/bin/bash
# CIS Benchmark: {id}
# Title: {title}
# Level: {level}

audit_rule() {{
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this command specifically
	## Description from CSV:
	## {audit_description}
	##
	## Command hint: {audit_command_hint}
	##
	## Placeholder logic (Fail by default until reviewed)
	## Change "1" to "0" once you implement the actual check

	if [ 1 -eq 0 ]; then
		a_output+=(" - Check Passed")
	else
		a_output2+=(" - Check Failed (Logic not yet implemented)")
	fi

	if [ "${{#a_output2[@]}}" -le 0 ]; then
		printf '%s\\n' "" "- Audit Result:" "  [+] PASS" "${{a_output[@]}}"
		return 0
	else
		printf '%s\\n' "" "- Audit Result:" "  [-] FAIL" " - Reason(s) for audit failure:" "${{a_output2[@]}}"
		[ "${{#a_output[@]}}" -gt 0 ] && printf '%s\\n' "- Correctly set:" "${{a_output[@]}}"
		return 1
	fi
}}

audit_rule
exit $?
"""

# Bash template for remediation scripts
REMEDIATION_SCRIPT_TEMPLATE = """#!/bin/bash
# CIS Benchmark: {id}
# Title: {title}
# Level: {level}
# Remediation Script

remediate_rule() {{
	l_output3=""
	l_dl=""
	unset a_output
	unset a_output2

	## TODO: Verify this remediation command specifically
	## Description from CSV:
	## {remediation_description}
	##
	## Command hint: {remediation_command_hint}
	##
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	## Change "1" to "0" once you implement the actual remediation

	if [ 1 -eq 0 ]; then
		a_output+=(" - Remediation applied successfully")
		return 0
	else
		a_output2+=(" - Remediation not applied (Logic not yet implemented)")
		return 1
	fi
}}

remediate_rule
exit $?
"""

def extract_command_from_text(text):
	"""
	Extract command from descriptive text using regex patterns.
	Looks for common patterns like "Run the command", "Run the below command", etc.
	"""
	if not text:
		return ""
	
	patterns = [
		r'(?:Run|Execute|Use) (?:the )?(?:below )?command[s]?:?\s+(?:For example,\s+)?(`[^`]+`|[^\n]+)',
		r'(?:For example,\s+)?(`[^`]+`)',
		r'(?:Example:?\s+)?(`[^`]+`)',
	]
	
	for pattern in patterns:
		match = re.search(pattern, text, re.IGNORECASE)
		if match:
			cmd = match.group(1)
			# Remove backticks if present
			cmd = cmd.strip('`').strip()
			if cmd:
				return cmd
	
	# If no specific pattern matched, return first line (often contains the command)
	first_line = text.split('\n')[0].strip()
	if first_line and len(first_line) > 10:
		return first_line
	
	return ""

def clean_level_string(level_str):
	"""
	Convert level string to directory name format.
	Example: "Level 1 - Master Node" -> "Level_1_Master_Node"
	"""
	if not level_str:
		return "Unknown"
	
	# Remove asterisks and extra spaces
	level_str = level_str.replace("•", "").strip()
	# Replace spaces and hyphens with underscores
	level_str = re.sub(r'[\s\-]+', '_', level_str)
	# Remove any duplicate underscores
	level_str = re.sub(r'_+', '_', level_str)
	# Remove trailing/leading underscores
	level_str = level_str.strip('_')
	
	return level_str

def read_csv(csv_file):
	"""
	Read CSV file and return list of dictionaries.
	Handles pipe-delimited CSV with header rows.
	"""
	rows = []
	
	try:
		with open(csv_file, 'r', encoding='utf-8') as f:
			# Skip initial header rows until we find the column headers
			header_found = False
			for i, line in enumerate(f):
				if 'Compliance Status|Number' in line:
					# Reset file pointer and start reading from here
					f.seek(0)
					# Skip lines before the actual header
					for _ in range(i):
						f.readline()
					
					# Use pipe delimiter
					csv_reader = csv.DictReader(f, delimiter='|')
					for row in csv_reader:
						# Skip empty rows and rows without a Number
						if not row.get('Number') or not row['Number'].strip():
							continue
						rows.append(row)
					header_found = True
					break
		
		if not header_found or not rows:
			print("[-] Could not find CSV header or data rows")
			sys.exit(1)
		
		print(f"[+] Successfully read {len(rows)} rows from {csv_file}")
		return rows
	except FileNotFoundError:
		print(f"[-] Error: CSV file '{csv_file}' not found")
		sys.exit(1)
	except Exception as e:
		print(f"[-] Error reading CSV: {e}")
		sys.exit(1)

def create_audit_script(cis_id, title, level, audit_desc, audit_cmd):
	"""
	Generate audit script content.
	"""
	# Extract command hint
	cmd_hint = extract_command_from_text(audit_cmd)
	
	# Clean up description for comments
	audit_desc_clean = audit_desc.replace('\n', ' ')[:200] if audit_desc else "N/A"
	
	content = AUDIT_SCRIPT_TEMPLATE.format(
		id=cis_id,
		title=title,
		level=level,
		audit_description=audit_desc_clean,
		audit_command_hint=cmd_hint
	)
	
	return content

def create_remediation_script(cis_id, title, level, remediation_desc, remediation_cmd):
	"""
	Generate remediation script content with SMART extraction logic.
	"""
	# 1. Extract command hint using generic method
	cmd_hint = extract_command_from_text(remediation_cmd)
	remediation_desc_clean = remediation_desc.replace('\n', ' ')[:200] if remediation_desc else "N/A"

	# 2. SMART AUTO-GENERATION LOGIC
	auto_logic = ""
	
	# Pattern 1: Permission Fix (chmod)
	# Ex: chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml
	match_chmod = re.search(r'chmod\s+(\d+)\s+([^\s]+)', cmd_hint)
	if match_chmod:
		perm = match_chmod.group(1)
		target_file = match_chmod.group(2)
		auto_logic = f"""
	# Auto-generated logic for chmod
	l_file="{target_file}"
	if [ -e "$l_file" ]; then
		echo "Applying: chmod {perm} $l_file"
		chmod {perm} "$l_file"
	else
		echo "File $l_file not found, skipping."
	fi
	"""

	# Pattern 2: Ownership Fix (chown)
	# Ex: chown root:root /etc/kubernetes/manifests/kube-apiserver.yaml
	match_chown = re.search(r'chown\s+([^\s]+)\s+([^\s]+)', cmd_hint)
	if match_chown:
		owner = match_chown.group(1)
		target_file = match_chown.group(2)
		auto_logic = f"""
	# Auto-generated logic for chown
	l_file="{target_file}"
	if [ -e "$l_file" ]; then
		echo "Applying: chown {owner} $l_file"
		chown {owner} "$l_file"
	else
		echo "File $l_file not found, skipping."
	fi
	"""

	# Pattern 3: API/Config Flag Fix (sed) - simple cases
	if "--" in cmd_hint and "=" in cmd_hint and not auto_logic:
		auto_logic = f"""
	# Detected flag configuration: {cmd_hint}
	# TODO: Implement safe YAML/File editing logic here.
	# Suggestion: sed -i 's/--flag=old/--flag=new/g' file
	echo "Manual intervention required for flag configuration."
	"""

	# If no pattern matched, use the default placeholder
	if not auto_logic:
		auto_logic = """
	## Safety Check: Verify if remediation is needed before applying
	## Placeholder logic (No-op by default until reviewed)
	if [ 1 -eq 0 ]; then
		a_output+=(" - Remediation applied successfully")
		return 0
	else
		a_output2+=(" - Remediation not applied (Logic not yet implemented)")
		return 1
	fi
	"""
	else:
		# If auto logic was generated, update return logic to verification suggestion
		auto_logic += """
	# Re-Audit after fix (Simple check)
	a_output+=(" - Remediation logic executed (Verify manually or run audit script)")
	return 0
	"""

	content = REMEDIATION_SCRIPT_TEMPLATE.replace(
		"if [ 1 -eq 0 ]; then", 
		f"# SMART LOGIC START\\n{auto_logic}\\n# SMART LOGIC END\\n    if [ 0 -eq 1 ]; then"
	).format(
		id=cis_id,
		title=title,
		level=level,
		remediation_description=remediation_desc_clean,
		remediation_command_hint=cmd_hint
	)
	
	return content

def generate_separated_masters(created_dirs):
	"""
	Generate two separate master scripts:
	1. master_audit_only.sh
	2. master_remediate_only.sh
	"""
	
	# --- 1. Master AUDIT Only ---
	audit_master_content = """#!/bin/bash
# CIS Master Runner: AUDIT ONLY
# This script will ONLY run checks. It will NOT make changes.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

echo "=========================================="
echo "    CIS BENCHMARK: AUDIT MODE ONLY"
echo "=========================================="

# Iterate strictly through Audit scripts
for level_dir in "$SCRIPT_DIR"/Level_*/; do
	if [ -d "$level_dir" ]; then
		dir_name=$(basename "$level_dir")
		echo ""
		echo "${YELLOW}[Folder] $dir_name${NC}"
		
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
echo "Pass: ${GREEN}$TOTAL_PASS${NC}"
echo "Fail: ${RED}$TOTAL_FAIL${NC}"
echo "=========================================="
"""

	# --- 2. Master REMEDIATION ---
	remediate_master_content = """#!/bin/bash
# CIS Master Runner: REMEDIATION
# WARNING: This script WILL apply changes to your system!

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

echo "=========================================="
echo "${RED}    WARNING: REMEDIATION MODE    ${NC}"
echo "    Are you sure you want to proceed?"
echo "=========================================="
read -p "Type 'yes' to continue: " confirm
if [ "$confirm" != "yes" ]; then
	echo "Aborted."
	exit 1
fi

for level_dir in "$SCRIPT_DIR"/Level_*/; do
	if [ -d "$level_dir" ]; then
		dir_name=$(basename "$level_dir")
		echo "${YELLOW}Fixing in: $dir_name${NC}"
		
		# Find only *_remediate.sh files
		for script in "$level_dir"/*_remediate.sh; do
			if [ -f "$script" ]; then
				echo "Running fix: $(basename "$script")"
				bash "$script"
			fi
		done
	fi
done
"""

	# Write Audit Master
	audit_path = os.path.join(BASE_OUTPUT_DIR, "master_audit_only.sh")
	try:
		with open(audit_path, 'w', encoding='utf-8') as f:
			f.write(audit_master_content)
		try:
			os.chmod(audit_path, 0o755)
		except:
			pass
		print(f"[+] Created: {audit_path}")
	except Exception as e:
		print(f"[-] Error writing audit master: {e}")

	# Write Remediation Master
	remed_path = os.path.join(BASE_OUTPUT_DIR, "master_remediate_only.sh")
	try:
		with open(remed_path, 'w', encoding='utf-8') as f:
			f.write(remediate_master_content)
		try:
			os.chmod(remed_path, 0o755)
		except:
			pass
		print(f"[+] Created: {remed_path}")
	except Exception as e:
		print(f"[-] Error writing remediation master: {e}")

def generate_scripts(csv_file):
	"""
	Main function to read CSV and generate all scripts.
	"""
	print("[*] CIS Kubernetes Benchmark Script Generator")
	print(f"[*] Reading CSV: {csv_file}")
	
	rows = read_csv(csv_file)
	
	if not rows:
		print("[-] No data rows found in CSV")
		sys.exit(1)
	
	# Track created directories and files
	created_dirs = set()
	created_files = []
	
	for row in rows:
		cis_id = row.get('Number', '').strip()
		title = row.get('Title', 'Unknown').strip()
		# Use 'Profile Applicability' or 'Level' depending on CSV structure
		# Based on user's uploaded file logic:
		profile_applicability = row.get('Profile Applicability', '').strip()
		level = profile_applicability if profile_applicability else 'Unknown'
		
		audit = row.get('Audit', '').strip()
		remediation = row.get('Remediation', '').strip()
		
		if not cis_id:
			continue
		
		# Clean up level string and create directory
		level_dir = clean_level_string(level)
		output_dir = os.path.join(BASE_OUTPUT_DIR, level_dir)
		
		# Create directory if not exists
		if output_dir not in created_dirs:
			try:
				os.makedirs(output_dir, exist_ok=True)
				created_dirs.add(output_dir)
				print(f"[+] Created directory: {output_dir}")
			except Exception as e:
				print(f"[-] Error creating directory {output_dir}: {e}")
				continue
		
		# Generate audit script
		audit_content = create_audit_script(cis_id, title, level, audit, audit)
		audit_file = os.path.join(output_dir, f"{cis_id}_audit.sh")
		
		try:
			with open(audit_file, 'w', encoding='utf-8') as f:
				f.write(audit_content)
			try:
				os.chmod(audit_file, 0o755)
			except:
				pass
			created_files.append(audit_file)
			print(f"[+] Created: {audit_file}")
		except Exception as e:
			print(f"[-] Error writing audit script {audit_file}: {e}")
		
		# Generate remediation script
		remediation_content = create_remediation_script(cis_id, title, level, remediation, remediation)
		remediation_file = os.path.join(output_dir, f"{cis_id}_remediate.sh")
		
		try:
			with open(remediation_file, 'w', encoding='utf-8') as f:
				f.write(remediation_content)
			try:
				os.chmod(remediation_file, 0o755)
			except:
				pass
			created_files.append(remediation_file)
			print(f"[+] Created: {remediation_file}")
		except Exception as e:
			print(f"[-] Error writing remediation script {remediation_file}: {e}")
	
	# Generate master runner script (Separated)
	generate_separated_masters(created_dirs)
	
	print(f"\\n[+] Summary:")
	print(f"    - Directories created: {len(created_dirs)}")
	print(f"    - Files created: {len(created_files)}")
	print(f"[+] Script generation completed successfully!")

def main():
	"""
	Entry point.
	"""
	csv_path = os.path.join(BASE_OUTPUT_DIR, CSV_FILE)
	
	if not os.path.exists(csv_path):
		print(f"[-] CSV file not found at: {csv_path}")
		# Fallback check
		if os.path.exists("CIS_Kubernetes_Benchmark_V1.12.0_PDF.xlsx - Recommendations.csv"):
			csv_path = "CIS_Kubernetes_Benchmark_V1.12.0_PDF.xlsx - Recommendations.csv"
			print(f"[*] Found alternate CSV: {csv_path}")
		else:
			print(f"[*] Looking for file: {CSV_FILE}")
			sys.exit(1)
	
	generate_scripts(csv_path)

if __name__ == "__main__":
	main()