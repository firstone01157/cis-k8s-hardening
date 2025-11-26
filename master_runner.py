#!/usr/bin/env python3
import os
import argparse
import subprocess
import sys
import json
import datetime
import time
import shutil

# --- Configuration & Constants ---
CONFIG_FILE = "cis_config.json"
LOG_DIR = "logs"

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'

# --- Helper Functions ---

def load_config():
    """Loads configuration from JSON file."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(base_dir, CONFIG_FILE)
    
    default_config = {
        "skip_rules": [],
        "health_check": {
            "check_services": ["kubelet", "containerd"],
            "check_ports": [6443]
        },
        "logging": {"enabled": True, "log_dir": "logs"}
    }

    if not os.path.exists(config_path):
        return default_config

    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"{Colors.RED}Error loading config: {e}{Colors.ENDC}")
        return default_config

def setup_logging(config):
    """Sets up logging directory."""
    if config.get("logging", {}).get("enabled", True):
        log_dir = config.get("logging", {}).get("log_dir", "logs")
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        return log_dir
    return None

def log_message(log_file, message):
    """Writes a message to the log file."""
    if log_file:
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a") as f:
            f.write(f"[{timestamp}] {message}\n")

def check_service_status(service_name):
    """Checks if a systemd service is active."""
    try:
        res = subprocess.run(["systemctl", "is-active", service_name], capture_output=True, text=True)
        return res.returncode == 0
    except FileNotFoundError:
        return False

def check_port_open(port):
    """Checks if a local port is listening (using ss or netstat)."""
    # Try ss first
    try:
        res = subprocess.run(["ss", "-tuln"], capture_output=True, text=True)
        if f":{port}" in res.stdout:
            return True
    except FileNotFoundError:
        pass
    return False

def run_health_check(config):
    """Runs system health checks."""
    print(f"\n{Colors.HEADER}--- System Health Check ---{Colors.ENDC}")
    all_healthy = True
    
    # Check Services
    services = config.get("health_check", {}).get("check_services", [])
    for svc in services:
        if check_service_status(svc):
            print(f"  [Service] {svc}: {Colors.GREEN}Active{Colors.ENDC}")
        else:
            print(f"  [Service] {svc}: {Colors.RED}Inactive/Missing{Colors.ENDC}")
            all_healthy = False

    # Check Ports
    ports = config.get("health_check", {}).get("check_ports", [])
    for port in ports:
        if check_port_open(port):
            print(f"  [Port] {port}: {Colors.GREEN}Listening{Colors.ENDC}")
        else:
            print(f"  [Port] {port}: {Colors.YELLOW}Not Found (Warning){Colors.ENDC}")
            # Port check failure might not be critical if running on a different node type

    # Check Kubernetes API (Simple curl)
    api_url = config.get("health_check", {}).get("api_health_url", "https://localhost:6443/healthz")
    try:
        subprocess.run(["curl", "-k", "-s", "--fail", api_url], check=True, stdout=subprocess.DEVNULL)
        print(f"  [API] {api_url}: {Colors.GREEN}OK{Colors.ENDC}")
    except Exception:
        print(f"  [API] {api_url}: {Colors.RED}Unreachable{Colors.ENDC}")
        all_healthy = False

    return all_healthy

def run_script_safely(script_path, is_remediation=False, log_file=None):
    """Runs a bash script and captures output."""
    try:
        cmd = ["bash", script_path]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        output_log = f"Script: {os.path.basename(script_path)}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}\nReturn Code: {result.returncode}\n"
        log_message(log_file, output_log)

        if is_remediation:
            if result.stderr:
                print(f"    {Colors.YELLOW}Warning/Error output:{Colors.ENDC}")
                for line in result.stderr.split('\n'):
                    if line: print(f"    {line}")
            for line in result.stdout.split('\n'):
                if line: print(f"    {line}")
            return "DONE", ""

        status = "PASS" if result.returncode == 0 else "FAIL"
        reason = ""
        if status == "FAIL":
            for line in result.stdout.split('\n'):
                if "Reason(s)" in line or "Check Failed" in line:
                    reason = line.strip()
                    break
        return status, reason

    except subprocess.TimeoutExpired:
        log_message(log_file, f"Script {os.path.basename(script_path)} TIMED OUT")
        return "TIMEOUT", "Script took too long"
    except Exception as e:
        log_message(log_file, f"Script {os.path.basename(script_path)} ERROR: {str(e)}")
        return "ERROR", str(e)

def get_target_directories(base_dir, level='all', role='all'):
    levels = ['1', '2'] if level == 'all' else [level]
    roles = ['Master', 'Worker'] if role == 'all' else [role.capitalize()]
    target_dirs = []
    
    for lvl in levels:
        for r in roles:
            dir_name = f"Level_{lvl}_{r}_Node"
            full_path = os.path.join(base_dir, dir_name)
            if os.path.isdir(full_path):
                target_dirs.append(full_path)
    return target_dirs

def execute_runner(config, mode="audit", level="all", role="all", specific_rule=None):
    """Main execution engine."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    log_dir = setup_logging(config)
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    log_filename = f"cis_run_{mode}_{timestamp}.log"
    log_file = os.path.join(log_dir, log_filename) if log_dir else None
    
    print(f"\n{Colors.CYAN}Starting {mode.upper()} run... Logs: {log_file if log_file else 'Disabled'}{Colors.ENDC}")
    log_message(log_file, f"--- Started {mode.upper()} Run ---")

    target_dirs = get_target_directories(base_dir, level, role)
    skip_rules = config.get("skip_rules", [])

    total_pass = 0
    total_fail = 0
    total_skipped = 0

    for directory in target_dirs:
        print(f"\n{Colors.BLUE}[Folder] {os.path.basename(directory)}{Colors.ENDC}")
        
        script_suffix = "_remediate.sh" if mode == "remediate" else "_audit.sh"
        scripts = sorted([f for f in os.listdir(directory) if f.endswith(script_suffix)])
        
        if not scripts:
            print("  (No scripts found)")
            continue

        for script in scripts:
            # Extract Rule ID (e.g., 1.1.1 from 1.1.1_audit.sh)
            rule_id = script.replace("_audit.sh", "").replace("_remediate.sh", "")
            
            # Filter by specific rule if requested
            if specific_rule and rule_id != specific_rule:
                continue

            # Check Skip List
            if rule_id in skip_rules:
                print(f"  {Colors.YELLOW}[SKIP]{Colors.ENDC} {script} (Configured in JSON)")
                log_message(log_file, f"Skipped {script}")
                total_skipped += 1
                continue

            script_path = os.path.join(directory, script)
            
            if mode == "remediate":
                print(f"  Running fix: {script}...")
                status, msg = run_script_safely(script_path, is_remediation=True, log_file=log_file)
                if status == "ERROR":
                    print(f"  {Colors.RED}[CRASH] Could not run {script}: {msg}{Colors.ENDC}")
            else:
                status, reason = run_script_safely(script_path, log_file=log_file)
                if status == "PASS":
                    print(f"  {Colors.GREEN}[PASS]{Colors.ENDC} {script}")
                    total_pass += 1
                elif status == "FAIL":
                    print(f"  {Colors.RED}[FAIL]{Colors.ENDC} {script}")
                    if reason: print(f"    -> {reason}")
                    total_fail += 1
                else:
                    print(f"  {Colors.RED}[ERROR]{Colors.ENDC} {script} -> {reason}")
                    total_fail += 1

    print(f"\n{Colors.HEADER}--- Summary ---{Colors.ENDC}")
    if mode == "audit":
        print(f"Pass: {Colors.GREEN}{total_pass}{Colors.ENDC}")
        print(f"Fail: {Colors.RED}{total_fail}{Colors.ENDC}")
    print(f"Skipped: {Colors.YELLOW}{total_skipped}{Colors.ENDC}")
    print(f"Logs saved to: {log_file}")

# --- Interactive Menu ---

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def print_menu():
    print(f"\n{Colors.HEADER}=== CIS Kubernetes Benchmark Runner ==={Colors.ENDC}")
    print("1. Run Full Audit (All Levels, All Roles)")
    print("2. Run Full Remediation (All Levels, All Roles)")
    print("3. Run Specific Level/Role")
    print("4. Run Single Rule ID")
    print("5. System Health Check")
    print("6. View Configuration")
    print("0. Exit")
    print("=======================================")

def interactive_mode():
    config = load_config()
    
    while True:
        print_menu()
        choice = input(f"{Colors.BOLD}Select option: {Colors.ENDC}")

        if choice == '1':
            execute_runner(config, mode="audit")
        elif choice == '2':
            confirm = input(f"{Colors.RED}WARNING: This will apply fixes. Type 'yes' to continue: {Colors.ENDC}")
            if confirm == "yes":
                execute_runner(config, mode="remediate")
            else:
                print("Cancelled.")
        elif choice == '3':
            lvl = input("Enter Level (1/2/all): ").strip() or "all"
            role = input("Enter Role (master/worker/all): ").strip() or "all"
            mode = input("Mode (audit/remediate): ").strip() or "audit"
            execute_runner(config, mode=mode, level=lvl, role=role)
        elif choice == '4':
            rule = input("Enter Rule ID (e.g., 1.1.1): ").strip()
            mode = input("Mode (audit/remediate): ").strip() or "audit"
            execute_runner(config, mode=mode, specific_rule=rule)
        elif choice == '5':
            run_health_check(config)
        elif choice == '6':
            print(json.dumps(config, indent=4))
            input("Press Enter to continue...")
        elif choice == '0':
            print("Goodbye!")
            sys.exit(0)
        else:
            print("Invalid option.")
        
        input(f"\n{Colors.CYAN}Press Enter to return to menu...{Colors.ENDC}")
        clear_screen()

def main():
    parser = argparse.ArgumentParser(description="CIS Runner Interactive")
    parser.add_argument("--interactive", action="store_true", help="Run in interactive mode")
    parser.add_argument("--audit", action="store_true", help="Run full audit non-interactively")
    
    args = parser.parse_args()

    # Default to interactive if no args provided
    if len(sys.argv) == 1 or args.interactive:
        interactive_mode()
    elif args.audit:
        config = load_config()
        execute_runner(config, mode="audit")
    else:
        parser.print_help()

if __name__ == "__main__":
    main()