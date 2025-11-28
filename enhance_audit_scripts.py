import os
import re

TARGET_DIRS = [
    "Level_1_Master_Node",
    "Level_1_Worker_Node",
    "Level_2_Master_Node",
    "Level_2_Worker_Node"
]

def process_file(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    filename = os.path.basename(filepath)
    cis_id = filename.split('_')[0]
    
    # Check for manual status
    content = "".join(lines)
    is_manual = "(Manual)" in content
    # Check for commands in the whole file to determine if it's strictly manual
    # We check for the presence of any of these commands
    has_commands = any(cmd in content for cmd in ["kubectl", "grep", "stat", "ps", "ls"])
    is_strictly_manual = is_manual and not has_commands
    
    new_lines = []
    
    # First, filter out existing generated logs to ensure idempotency
    clean_lines = []
    for line in lines:
        if any(tag in line for tag in ['[INFO]', '[CMD]', '[MANUAL_CHECK]']):
            continue
        clean_lines.append(line)
    
    lines = clean_lines

    for i, line in enumerate(lines):
        # Inject Start Log
        if "audit_rule() {" in line:
            new_lines.append(line)
            # Default indentation to tab, but could be spaces. 
            # We'll just use a tab as it's common in these scripts.
            new_lines.append(f'\techo "[INFO] Starting check for {cis_id}..."\n')
            
            if is_strictly_manual:
                 new_lines.append(f'\techo "[MANUAL_CHECK] This is a manual check. Please verify as per description."\n')
            continue

        # Inject Command Log
        # Improved regex to catch commands at start, inside if, inside $() assignment, or after pipe
        # We look for the command as a distinct word
        match = re.search(r'(?:^|\s|\||\()(kubectl|grep|stat|ps|ls)\b', line)
        if match:
            # We want to log the whole line as the command being executed
            # But we need to be careful not to log echo statements that mention the command
            if "echo" in line and "[CMD]" not in line:
                 # Skip if it's likely an echo statement (heuristic)
                 if re.search(r'echo.*["\'].*(' + match.group(1) + r').*["\']', line):
                     new_lines.append(line)
                     continue

            # Avoid double injection if running multiple times
            if i > 0 and "[CMD] Executing:" in lines[i-1]:
                 new_lines.append(line)
                 continue
            
            # Get indentation from the original line
            indent_match = re.match(r'^(\s*)', line)
            indent = indent_match.group(1) if indent_match else ""
            
            stripped_line = line.strip()
            escaped_line = stripped_line.replace('\\', '\\\\').replace('"', '\\"').replace("'", "\\'")
            new_lines.append(f'{indent}echo "[CMD] Executing: {escaped_line}"\n')
            new_lines.append(line)
            continue
            
        # Inject Found/Not Found Log
        # We look for a_output+= or a_output2+=
        if 'a_output+=("' in line:
             indent = line[:line.find("a_output")]
             # Check if it's a PASS
             new_lines.append(f'{indent}echo "[INFO] Check Passed"\n')
             new_lines.append(line)
             continue
        
        if 'a_output2+=("' in line:
             indent = line[:line.find("a_output2")]
             # Check if it's a FAIL
             new_lines.append(f'{indent}echo "[INFO] Check Failed"\n')
             new_lines.append(line)
             continue

        new_lines.append(line)
        
    with open(filepath, 'w') as f:
        f.writelines(new_lines)

def main():
    count = 0
    cwd = os.getcwd()
    print(f"Scanning directories in {cwd}...")
    
    for d in TARGET_DIRS:
        dir_path = os.path.join(cwd, d)
        if not os.path.exists(dir_path):
            print(f"Directory not found: {d}")
            continue
            
        print(f"Processing {d}...")
        for root, dirs, files in os.walk(dir_path):
            for file in files:
                if file.endswith("_audit.sh"):
                    process_file(os.path.join(root, file))
                    count += 1
    print(f"Modified {count} files.")

if __name__ == "__main__":
    main()
