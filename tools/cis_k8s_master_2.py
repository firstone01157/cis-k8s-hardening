#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark - ULTIMATE DASHBOARD
Features: Baseline Comparison, Level Selection, Smart Guidance, JSON Export
"""

import os
import sys
import argparse
import subprocess
import json
import csv
import time
import socket
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Configuration ---
CONFIG_FILE = "cis_config.json"
BASELINE_FILE = "cis_baseline.json"
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

class CISRunner:
    def __init__(self):
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.hostname = socket.gethostname()
        self.results = []
        self.stats = {
            "master": {"pass": 0, "fail": 0, "total": 0}, 
            "worker": {"pass": 0, "fail": 0, "total": 0}
        }
        self.baseline = self.load_baseline()
        self.target_level = "all" # Default
        self.setup_dirs()

    def setup_dirs(self):
        for d in [REPORT_DIR, LOG_DIR]:
            os.makedirs(os.path.join(self.base_dir, d), exist_ok=True)

    def load_baseline(self):
        path = os.path.join(self.base_dir, BASELINE_FILE)
        if os.path.exists(path):
            try:
                with open(path, 'r') as f: return json.load(f)
            except: pass
        return None

    def save_baseline(self):
        # Save current stats as baseline if not exists or user requests
        path = os.path.join(self.base_dir, BASELINE_FILE)
        with open(path, 'w') as f:
            json.dump(self.stats, f)
        self.baseline = self.stats.copy()

    def get_scripts(self, mode="audit"):
        suffix = "_remediate.sh" if mode == "remediate" else "_audit.sh"
        scripts = []
        
        levels = ['1', '2'] if self.target_level == "all" else [self.target_level]
        
        for role in ["Master", "Worker"]:
            for level in levels:
                dir_path = os.path.join(self.base_dir, f"Level_{level}_{role}_Node")
                if os.path.isdir(dir_path):
                    for f in sorted(os.listdir(dir_path)):
                        if f.endswith(suffix):
                            scripts.append({
                                "path": os.path.join(dir_path, f),
                                "id": f.replace(suffix, ""),
                                "role": role.lower(),
                                "name": f,
                                "level": level
                            })
        return scripts

    def get_guidance(self, script_id, role):
        # Try to find the audit script to extract description
        # Search in both levels since ID is unique
        for lvl in ['1', '2']:
            fname = f"{script_id}_audit.sh"
            r_cap = role.capitalize()
            path = os.path.join(self.base_dir, f"Level_{lvl}_{r_cap}_Node", fname)
            
            if os.path.exists(path):
                desc = []
                hint = []
                with open(path, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    capture_desc = False
                    capture_hint = False
                    for line in lines:
                        if "## Description" in line: capture_desc = True; continue
                        if "## Command hint" in line: capture_desc = False; capture_hint = True; continue
                        if "##" in line and capture_desc: desc.append(line.replace("##", "").strip())
                        if "##" in line and capture_hint: hint.append(line.replace("##", "").strip())
                        if not line.startswith("##") and (capture_desc or capture_hint): break
                
                return "\n".join(desc), "\n".join(hint)
        return "No description found.", "No hint found."

    def run_script(self, script, mode):
        try:
            cmd = ["bash", script["path"]]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            status = "PASS" if res.returncode == 0 else "FAIL"
            if mode == "remediate":
                status = "FIXED" if res.returncode == 0 else "ERROR"
            
            return {
                "id": script["id"],
                "role": script["role"],
                "level": script["level"],
                "status": status,
                "output": res.stdout + res.stderr
            }
        except:
            return {"id": script["id"], "role": script["role"], "status": "ERROR", "output": "Timeout/Error"}

    def scan(self):
        print(f"\n{Colors.CYAN}🔄 Scanning... Target: Level {self.target_level} ({self.hostname}){Colors.ENDC}")
        scripts = self.get_scripts("audit")
        self.results = []
        self.stats = {
            "master": {"pass": 0, "fail": 0, "total": 0}, 
            "worker": {"pass": 0, "fail": 0, "total": 0}
        }

        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = {executor.submit(self.run_script, s, "audit"): s for s in scripts}
            for future in as_completed(futures):
                res = future.result()
                self.results.append(res)
                # Update stats
                role_key = "master" if "master" in res["role"] else "worker"
                stat_key = "pass" if res["status"] == "PASS" else "fail"
                self.stats[role_key][stat_key] += 1
                self.stats[role_key]["total"] += 1
        
        # Save reports
        self.save_csv_report("audit")
        self.save_json_report("audit") # For multi-node aggregation
        
        # If no baseline, save this as baseline
        if self.baseline is None:
            self.save_baseline()

    def fix(self):
        print(f"\n{Colors.YELLOW}🛠️  Applying fixes... (Level {self.target_level}){Colors.ENDC}")
        scripts = self.get_scripts("remediate")
        count = 0
        for s in scripts:
            print(f"\r   Processing {s['id']}...", end="")
            self.run_script(s, "remediate")
            count += 1
        print(f"\r{Colors.GREEN}   ✅ Execution complete.{Colors.ENDC} Re-scanning now...")
        self.scan()

    def save_csv_report(self, mode):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = os.path.join(self.base_dir, REPORT_DIR, f"cis_{mode}_{self.hostname}_{timestamp}.csv")
        with open(filename, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "role", "level", "status", "output"])
            writer.writeheader()
            writer.writerows(self.results)

    def save_json_report(self, mode):
        # JSON is better for programmatic aggregation (1000 nodes)
        filename = os.path.join(self.base_dir, REPORT_DIR, f"cis_latest_{self.hostname}.json")
        data = {
            "hostname": self.hostname,
            "timestamp": datetime.now().isoformat(),
            "level_target": self.target_level,
            "stats": self.stats,
            "details": self.results
        }
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)

    def draw_bar(self, role):
        stats = self.stats[role]
        passed = stats['pass']
        total = stats['total']
        
        if total == 0: return f"[{Colors.YELLOW}??{Colors.ENDC}] No Data"
        
        percent = (passed / total) * 100
        bar_len = 20
        filled = int(bar_len * percent / 100)
        bar = "█" * filled + "░" * (bar_len - filled)
        color = Colors.GREEN if percent > 80 else (Colors.YELLOW if percent > 50 else Colors.RED)
        
        # Baseline Comparison logic
        diff_text = ""
        if self.baseline:
            base_pass = self.baseline[role]['pass']
            base_total = self.baseline[role]['total']
            if base_total > 0:
                base_pct = (base_pass / base_total) * 100
                diff = percent - base_pct
                if diff > 0: diff_text = f"{Colors.GREEN}▲{diff:.1f}%{Colors.ENDC}"
                elif diff < 0: diff_text = f"{Colors.RED}▼{abs(diff):.1f}%{Colors.ENDC}"
                else: diff_text = f"{Colors.BLUE}={Colors.ENDC}"
        
        return f"{color}[{bar}] {int(percent)}%{Colors.ENDC} ({passed}/{total}) {diff_text}"

    def show_dashboard(self):
        os.system('cls' if os.name == 'nt' else 'clear')
        print(f"\n{Colors.HEADER}================================================================{Colors.ENDC}")
        print(f"{Colors.BOLD}   🛡️  CIS KUBERNETES HARDENING DASHBOARD {Colors.ENDC}")
        print(f"   Host: {Colors.CYAN}{self.hostname}{Colors.ENDC} | Target Level: {Colors.YELLOW}{self.target_level.upper()}{Colors.ENDC}")
        print(f"{Colors.HEADER}================================================================{Colors.ENDC}")
        
        print(f"\n   {Colors.BOLD}📊 STATUS OVERVIEW{Colors.ENDC}")
        print(f"   ------------------------------------------------------------")
        print(f"   MASTER NODE  : {self.draw_bar('master')}")
        print(f"   WORKER NODE  : {self.draw_bar('worker')}")
        print(f"   ------------------------------------------------------------")
        
        print(f"\n   {Colors.BOLD}🚀 ACTIONS{Colors.ENDC}")
        print(f"   [{Colors.CYAN}1{Colors.ENDC}] 🔍 Scan (Audit)")
        print(f"   [{Colors.YELLOW}2{Colors.ENDC}] 🛠️  Fix (Remediate)")
        print(f"   [{Colors.BLUE}3{Colors.ENDC}] 🎯 Change Level (1/2/All)")
        print(f"   [{Colors.GREEN}4{Colors.ENDC}] 💡 Guidance (Show Failed Items)")
        print(f"   [{Colors.RED}0{Colors.ENDC}] 🚪 Exit")
        print(f"\n{Colors.HEADER}================================================================{Colors.ENDC}")

    def show_guidance(self):
        print(f"\n{Colors.RED}❌ FAILED ITEMS:{Colors.ENDC}")
        failed_list = [r for r in self.results if r['status'] == "FAIL"]
        
        if not failed_list:
            print("   No failed items! Great job.")
            input("\nPress Enter...")
            return

        # Group by ID to avoid duplicates
        seen = set()
        for r in sorted(failed_list, key=lambda x: x['id']):
            if r['id'] not in seen:
                print(f"   - {Colors.BOLD}{r['id']}{Colors.ENDC} ({r['role']})")
                seen.add(r['id'])
        
        print("\n   Type an ID (e.g. 1.1.12) to see remediation guide, or Enter to return.")
        choice = input("   > ").strip()
        
        if choice:
            # Find item
            item = next((x for x in failed_list if x['id'] == choice), None)
            if item:
                desc, hint = self.get_guidance(item['id'], item['role'])
                print(f"\n{Colors.CYAN}--- GUIDANCE: {item['id']} ---{Colors.ENDC}")
                print(f"{Colors.BOLD}Description:{Colors.ENDC}\n{desc}")
                print(f"\n{Colors.BOLD}How to fix (Hint):{Colors.ENDC}\n{hint}")
                print(f"\n{Colors.YELLOW}Note: If auto-fix failed, you must perform this manually.{Colors.ENDC}")
                input("\nPress Enter...")
            else:
                print("   ID not found in failed list.")
                time.sleep(1)

def main():
    runner = CISRunner()
    runner.scan() # Initial Scan
    
    while True:
        runner.show_dashboard()
        try:
            choice = input("   Select option: ")
            
            if choice == '1':
                runner.scan()
            elif choice == '2':
                confirm = input(f"\n   {Colors.RED}Are you sure you want to apply fixes? (yes/no): {Colors.ENDC}")
                if confirm.lower() == "yes":
                    runner.fix()
            elif choice == '3':
                new_lvl = input("\n   Select Level (1 / 2 / all): ").strip()
                if new_lvl in ['1', '2', 'all']:
                    runner.target_level = new_lvl
                    runner.scan() # Rescan with new level
            elif choice == '4':
                runner.show_guidance()
            elif choice == '0':
                # Update baseline before exit? Optional.
                # runner.save_baseline() 
                print("Bye!")
                sys.exit(0)
        except KeyboardInterrupt:
            print("\nBye!")
            sys.exit(0)

if __name__ == "__main__":
    main()