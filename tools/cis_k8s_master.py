#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark Runner (UX Fixed)
- Interactive Mode is now DEFAULT even with -v arguments.
- Removed annoying screen clearing.
- CLI mode only triggers if --audit or --remediate is explicitly set.
"""

import os
import sys
import argparse
import subprocess
import json
import csv
import time
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Configuration ---
CONFIG_FILE = "cis_config.json"
REPORT_DIR = "reports"
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

class CISKubernetesRunner:
    def __init__(self, verbose=1, quiet=False, parallel=True):
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.verbose = verbose
        self.quiet = quiet
        self.parallel = parallel
        self.config = self.load_config()
        self.setup_dirs()
        
        # Statistics
        self.stats = {
            "pass": 0,
            "fail": 0,
            "error": 0,
            "skipped": 0,
            "total": 0
        }
        self.results_data = []

    def load_config(self):
        config_path = os.path.join(self.base_dir, CONFIG_FILE)
        default_config = {"skip_rules": []}
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    return json.load(f)
            except:
                pass
        return default_config

    def setup_dirs(self):
        for d in [REPORT_DIR, LOG_DIR]:
            path = os.path.join(self.base_dir, d)
            if not os.path.exists(path):
                os.makedirs(path)

    def get_target_scripts(self, level, role, mode):
        levels = ['1', '2'] if level == 'all' else [str(level)]
        roles = ['Master', 'Worker'] if role == 'all' else [role.capitalize()]
        suffix = "_remediate.sh" if mode == "remediate" else "_audit.sh"
        
        target_files = []
        for l in levels:
            for r in roles:
                dir_name = f"Level_{l}_{r}_Node"
                dir_path = os.path.join(self.base_dir, dir_name)
                if os.path.isdir(dir_path):
                    for f in sorted(os.listdir(dir_path)):
                        if f.endswith(suffix):
                            rule_id = f.replace(suffix, "")
                            if rule_id in self.config.get("skip_rules", []):
                                self.stats["skipped"] += 1
                                continue
                            target_files.append({
                                "path": os.path.join(dir_path, f),
                                "name": f,
                                "id": rule_id,
                                "level": l,
                                "role": r
                            })
        return target_files

    def run_single_script(self, script_info, mode):
        path = script_info["path"]
        rule_id = script_info["id"]
        
        start_time = time.time()
        try:
            result = subprocess.run(
                ["bash", path], 
                capture_output=True, 
                text=True, 
                timeout=45
            )
            duration = round(time.time() - start_time, 2)
            
            status = "UNKNOWN"
            reason = ""
            
            if mode == "remediate":
                status = "APPLIED" if result.returncode == 0 else "ERROR"
                reason = "Remediation executed"
            else:
                status = "PASS" if result.returncode == 0 else "FAIL"
                if status == "FAIL":
                    for line in result.stdout.split('\n'):
                        if "Reason(s)" in line or "Check Failed" in line:
                            reason = line.strip()
                            break
            
            return {
                "id": rule_id,
                "level": script_info["level"],
                "role": script_info["role"],
                "status": status,
                "duration": duration,
                "reason": reason,
                "raw_output": result.stdout + "\n" + result.stderr
            }

        except subprocess.TimeoutExpired:
            return {"id": rule_id, "status": "TIMEOUT", "reason": "Timed out", "raw_output": ""}
        except Exception as e:
            return {"id": rule_id, "status": "ERROR", "reason": str(e), "raw_output": ""}

    def print_result(self, data):
        if self.quiet: return

        color = Colors.GREEN if data["status"] == "PASS" else Colors.RED
        if data["status"] == "APPLIED": color = Colors.CYAN
        
        icon = "✅" if data["status"] == "PASS" else "❌"
        if data["status"] == "APPLIED": icon = "🛠️"

        print(f"{icon} {data['id']:<10} {color}{data['status']:<8}{Colors.ENDC} ({data['role']})", end="")
        
        if self.verbose >= 1 and data["status"] == "FAIL":
            print(f" -> {data['reason'][:60]}...", end="")
        
        print()

        # Verbose Level 2: Show full output for everything
        # Verbose Level 1: Show output only for FAIL (Optional, currently implemented logic is just reason)
        if self.verbose >= 2:
            print(f"{Colors.YELLOW}   Output:{Colors.ENDC}")
            # Indent output for readability
            formatted_output = "\n".join(["     " + line for line in data["raw_output"].splitlines()])
            print(formatted_output)

    def generate_report(self, mode):
        if not self.results_data: return None
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"cis_{mode}_report_{timestamp}.csv"
        filepath = os.path.join(self.base_dir, REPORT_DIR, filename)
        keys = ["id", "level", "role", "status", "duration", "reason"]
        with open(filepath, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=keys)
            writer.writeheader()
            for res in self.results_data:
                row = {k: res.get(k, "") for k in keys}
                writer.writerow(row)
        return filepath

    def run(self, level="all", role="all", mode="audit"):
        print(f"\n{Colors.HEADER}=== Starting CIS {mode.upper()} (Level: {level}, Role: {role}) ==={Colors.ENDC}")
        scripts = self.get_target_scripts(level, role, mode)
        self.stats["total"] = len(scripts)
        print(f"[*] Found {len(scripts)} scripts to execute.\n")

        is_parallel = self.parallel and (mode == "audit")
        
        # Reset stats for new run
        self.results_data = []
        self.stats = {"pass": 0, "fail": 0, "error": 0, "skipped": self.stats["skipped"], "total": len(scripts)}

        if is_parallel:
            with ThreadPoolExecutor(max_workers=10) as executor:
                futures = {executor.submit(self.run_single_script, s, mode): s for s in scripts}
                for future in as_completed(futures):
                    data = future.result()
                    self.results_data.append(data)
                    key = data["status"].lower()
                    if key not in self.stats: key = "error"
                    self.stats[key] += 1
                    self.print_result(data)
        else:
            for s in scripts:
                data = self.run_single_script(s, mode)
                self.results_data.append(data)
                key = data["status"].lower()
                if key not in self.stats: key = "error"
                self.stats[key] += 1
                self.print_result(data)

        print(f"\n{Colors.HEADER}=== Execution Summary ==={Colors.ENDC}")
        if mode == "audit":
            print(f"Pass:  {Colors.GREEN}{self.stats['pass']}{Colors.ENDC}")
            print(f"Fail:  {Colors.RED}{self.stats['fail']}{Colors.ENDC}")
        print(f"Total: {self.stats['total']}")
        
        report_path = self.generate_report(mode)
        if report_path:
            print(f"\n{Colors.CYAN}[*] Report generated: {report_path}{Colors.ENDC}")

# --- Interactive Menu ---

def interactive_mode(default_verbose=1):
    # No clear_screen() here to preserve previous output
    print(f"\n{Colors.HEADER}=== CIS Kubernetes Benchmark ==={Colors.ENDC}")
    print(f"Current Verbosity: Level {default_verbose}")
    print("1. Run Audit (Full Scan)")
    print("2. Run Remediation (Full Fix)")
    print("3. Custom Scan (Select Level/Role)")
    print("4. Generate Reports Only")
    print("0. Exit")
    print("===========================================")
    
    while True:
        try:
            choice = input(f"{Colors.BOLD}Select option: {Colors.ENDC}")
        except KeyboardInterrupt:
            print("\nGoodbye!")
            sys.exit(0)
        
        runner = CISKubernetesRunner(verbose=default_verbose) 
        
        if choice == '1':
            runner.run(mode="audit")
        elif choice == '2':
            confirm = input(f"{Colors.RED}WARNING: This will apply fixes. Continue? (yes/no): {Colors.ENDC}")
            if confirm.lower() == "yes":
                runner.run(mode="remediate")
        elif choice == '3':
            lvl = input("Level (1/2/all) [all]: ") or "all"
            role = input("Role (master/worker/all) [all]: ") or "all"
            mode = input("Mode (audit/remediate) [audit]: ") or "audit"
            runner.run(level=lvl, role=role, mode=mode)
        elif choice == '4':
            print("Reports are auto-generated after every run.")
        elif choice == '0':
            sys.exit(0)
        else:
            print("Invalid option.")
        
        # Only print menu separator, don't clear screen
        print("\n" + "-"*30 + "\n")
        # Re-print menu for convenience
        print("1. Run Audit | 2. Run Fix | 3. Custom | 0. Exit")

# --- CLI Entry Point ---

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CIS Kubernetes Benchmark Runner")
    parser.add_argument("--audit", action="store_true", help="Run full audit non-interactively")
    parser.add_argument("--remediate", action="store_true", help="Run full remediation non-interactively")
    parser.add_argument("--level", default="all", help="Target level (1/2/all)")
    parser.add_argument("--role", default="all", help="Target role (master/worker/all)")
    parser.add_argument("-v", "--verbose", action="count", default=1, help="Increase verbosity (e.g., -vv)")
    parser.add_argument("--no-parallel", action="store_true", help="Disable parallel execution")
    
    args = parser.parse_args()

    # Logic เปลี่ยนใหม่: ถ้าไม่มี flag --audit หรือ --remediate ให้เข้า Interactive เสมอ
    # แม้ว่าจะมี -v มาด้วยก็ตาม
    if not (args.audit or args.remediate):
        interactive_mode(default_verbose=args.verbose)
    else:
        # CLI Mode
        mode = "remediate" if args.remediate else "audit"
        if mode == "remediate":
            confirm = input("Running REMEDIATION via CLI. Are you sure? (yes/no): ")
            if confirm.lower() != "yes":
                sys.exit("Aborted.")

        runner = CISKubernetesRunner(verbose=args.verbose, parallel=not args.no_parallel)
        runner.run(level=args.level, role=args.role, mode=mode)