import os
import re
import sys

# Configuration
BASE_DIR = os.getcwd()
TARGET_DIRS = [d for d in os.listdir(BASE_DIR) if d.startswith("Level_") and os.path.isdir(d)]

# Regex Patterns
CMD_PATTERN = re.compile(r'^\s*(kubectl|grep|stat|ps|ls|cat|systemctl)\s+')
FAIL_PATTERN = re.compile(r'(\s*)a_output2\+=\(" - (.*?)"\)')
FIX_HINT_TEMPLATE = 'echo "[FIX_HINT] Run the corresponding remediation script (Level_X/.../ID_remediate.sh) or check the CIS benchmark guide."'

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    new_lines = []
    modified = False
    
    # Extract ID for fix hint
    filename = os.path.basename(file_path)
    script_id = filename.split('_')[0] if '_' in filename else "UNKNOWN"
    
    for i, line in enumerate(lines):
        # 1. Inject [CMD]
        # Check if line is a command we want to log
        # Avoid injecting if already present or if inside a condition that makes it tricky (though simple injection usually works)
        # Also avoid injecting if it's part of a variable assignment like var=$(cmd) - simpler to skip those for now to avoid syntax errors
        # We focus on standalone commands
        
        cmd_match = CMD_PATTERN.match(line)
        if cmd_match and "echo \"[CMD]" not in line and "$(" not in line and "`" not in line:
            # Get indentation
            indent = line[:line.find(cmd_match.group(1))]
            # Clean up command for display (escape quotes)
            cmd_str = line.strip().replace('"', '\\"')
            # Insert echo before
            new_lines.append(f'{indent}echo "[CMD] {cmd_str}"\n')
            new_lines.append(line)
            modified = True
        
        # 2. Inject [FAIL_REASON] and [FIX_HINT]
        elif FAIL_PATTERN.search(line):
            match = FAIL_PATTERN.search(line)
            indent = match.group(1)
            reason = match.group(2)
            
            # Keep the original line to maintain logic
            new_lines.append(line)
            
            # Add structured output
            # We use the captured reason
            clean_reason = reason.replace('"', '\\"')
            new_lines.append(f'{indent}echo "[FAIL_REASON] {clean_reason}"\n')
            
            # Add fix hint
            # Try to be smart about the hint path
            # We can't easily know the exact remediate path without searching, so we'll use a generic placeholder or try to construct it
            # Actually, the python runner will generate the "Try Fix" command, so here we can just give a generic hint or specific if possible.
            # The user asked for: echo "[FIX_HINT] Edit /var/lib/kubelet/config.yaml ..."
            # Since we can't easily parse the specific fix from bash, we'll output a generic hint that points to the remediation script.
            
            # Construct remediation script name
            remediate_script = filename.replace("audit", "remediate")
            # We don't know the full path here easily without more logic, but we can just say "Run remediation script"
            
            new_lines.append(f'{indent}echo "[FIX_HINT] Run remediation script: {remediate_script}"\n')
            modified = True
            
        else:
            new_lines.append(line)

    if modified:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"Updated: {file_path}")
    else:
        # print(f"Skipped (No changes needed): {file_path}")
        pass

def main():
    print("Starting Bulk Update of Audit Scripts...")
    count = 0
    for d in TARGET_DIRS:
        dir_path = os.path.join(BASE_DIR, d)
        for root, _, files in os.walk(dir_path):
            for file in files:
                if file.endswith("_audit.sh"):
                    process_file(os.path.join(root, file))
                    count += 1
    print(f"Finished processing {count} scripts.")

if __name__ == "__main__":
    main()
