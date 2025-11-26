#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark - Unified Interactive Runner (Enhanced)
Features:
- Smart Kubeconfig Detection
- Auto Backup System
- Oracle-Style Detailed XML/Text Reporting (Folder structure based)
- Robust CSV Generation
- Extracts Title directly from Scripts
- Configurable Rule Exclusions (cis_config.json)
- Component-Based Summary (Etcd, Kubelet, API Server, etc.)
- Snapshot Comparison & Trend Analysis
"""

import os
import sys
import shutil
import subprocess
import json
import csv
import time
import socket
import argparse
import glob
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Configuration ---
BASE_RESULT_DIR = "results"
BACKUP_DIR = "backups"
LOG_DIR = "logs"
HISTORY_DIR = "history"
CONFIG_FILE = "cis_config.json"

# Component Mapping (CIS ID patterns to component names)
COMPONENT_MAP = {
    "Etcd": ["1.1"],
    "API Server": ["1.2"],
    "Controller Manager": ["1.3"],
    "Scheduler": ["1.4"],
    "Kubelet": ["4.1", "4.2"],
    "Pod Security Policy": ["5.1"],
    "Network Policy": ["5.3"],
    "RBAC": ["5.2", "5.4"],
    "Other": []
}

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    ENDC = '\033[0m'

class CISUnifiedRunner:
    def __init__(self, verbose=False):
        self.base_dir = os.path.dirname(os.path.abspath(__file__))
        self.hostname = socket.gethostname()
        self.verbose = verbose
        self.skip_manual = False  # Will be set by user in menu
        self.script_timeout = 60  # Default timeout in seconds
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Load configuration
        self.config = self.load_config()
        self.excluded_rules = self.config.get("excluded_rules", {})
        
        # Setup activity log
        self.log_file = os.path.join(self.base_dir, LOG_DIR, f"activity_{self.timestamp}.log")
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
        
        # Setup Result Directory Structure (Oracle Style)
        # results/YYYY-MM-DD/audit/run_TIMESTAMP/
        date_str = datetime.now().strftime("%Y-%m-%d")
        self.current_report_dir = None # Will be set during scan/fix
        self.date_dir = os.path.join(self.base_dir, BASE_RESULT_DIR, date_str)
        
        self.results = []
        self.stats = {
            "master": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "ignored": 0, "error": 0, "total": 0},
            "worker": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "ignored": 0, "error": 0, "total": 0}
        }
        self.health_status = "UNKNOWN"
        self.stop_requested = False
        self.previous_score = None
        self.setup_dirs()
        self.check_dependencies()
    
    def load_config(self):
        """Load configuration from cis_config.json"""
        config_path = os.path.join(self.base_dir, CONFIG_FILE)
        default_config = {
            "excluded_rules": {},
            "custom_parameters": {},
            "health_check": {},
            "logging": {"enabled": True, "log_dir": "logs"}
        }
        
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    config = json.load(f)
                    # Migrate old 'skip_rules' to new 'excluded_rules' format if needed
                    if "skip_rules" in config and "excluded_rules" not in config:
                        config["excluded_rules"] = {rule: "IGNORED" for rule in config.get("skip_rules", [])}
                    return config
            except Exception as e:
                if self.verbose:
                    print(f"{Colors.YELLOW}[!] Error loading config: {e}. Using defaults.{Colors.ENDC}")
        
        return default_config
    
    def is_rule_excluded(self, rule_id):
        """Check if a rule is in the excluded list"""
        return rule_id in self.excluded_rules
    
    def get_rule_exclusion_reason(self, rule_id):
        """Get the exclusion reason (IGNORED, RISK_ACCEPTED, etc.)"""
        return self.excluded_rules.get(rule_id, "")
    
    def get_component_for_rule(self, rule_id):
        """Map rule ID to component"""
        for component, prefixes in COMPONENT_MAP.items():
            if component == "Other":
                continue
            for prefix in prefixes:
                if rule_id.startswith(prefix):
                    return component
        return "Other"

    def setup_dirs(self):
        for d in [BASE_RESULT_DIR, LOG_DIR, BACKUP_DIR, HISTORY_DIR]:
            os.makedirs(os.path.join(self.base_dir, d), exist_ok=True)

    def show_banner(self):
        """Display project information banner (Oracle-style)"""
        print("\n" + "=" * 72)
        print("|" + " " * 70 + "|")
        print("|" + " " * 15 + "CIS Kubernetes Benchmark v1.12.0" + " " * 22 + "|")
        print("|" + " " * 20 + "Unified Interactive Runner" + " " * 24 + "|")
        print("|" + " " * 70 + "|")
        print("=" * 72)
        print(f"\n  [*] Kubernetes hardening and compliance auditing")
        print(f"  [*] Parallel processing with activity logging")
        print(f"  [*] Comprehensive reporting (HTML, JSON, CSV, TXT)")
        
        # Show verbose mode status if enabled
        if self.verbose:
            print(f"  [*] Verbose Mode: ENABLED (showing detailed output)")
        
        print()

    def log_activity(self, action, details=""):
        """Log activity to activity log file"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {action}"
        if details:
            log_entry += f" - {details}"
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + "\n")
        except Exception as e:
            if self.verbose:
                print(f"{Colors.RED}Logging error: {e}{Colors.ENDC}")

    def check_dependencies(self):
        required_tools = ["kubectl", "jq", "grep", "sed", "awk"]
        missing = []
        for tool in required_tools:
            if shutil.which(tool) is None:
                missing.append(tool)
        if missing:
            print(f"{Colors.RED}[-] Missing dependencies: {', '.join(missing)}{Colors.ENDC}")
            sys.exit(1)

    def get_kubectl_cmd(self):
        possible_configs = [
            os.environ.get('KUBECONFIG'),
            "/etc/kubernetes/admin.conf",
            os.path.join(os.path.expanduser("~"), ".kube/config"),
            f"/home/{os.environ.get('SUDO_USER')}/.kube/config" if os.environ.get("SUDO_USER") else None
        ]
        
        for conf in possible_configs:
            if conf and os.path.exists(conf):
                if self.verbose:
                    print(f"{Colors.BLUE}[DEBUG] Using Kubeconfig: {conf}{Colors.ENDC}")
                return ["kubectl", "--kubeconfig", conf]
        
        return ["kubectl"]

    def check_health(self):
        print(f"{Colors.CYAN}[*] Checking Cluster Health...{Colors.ENDC}")
        kubectl = self.get_kubectl_cmd()
        
        try:
            res_nodes = subprocess.run(kubectl + ["get", "nodes"], capture_output=True, text=True, timeout=10)
            if res_nodes.returncode != 0:
                self.health_status = "CRITICAL (Nodes Unreachable)"
                print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
                return self.health_status

            res_pods = subprocess.run(
                kubectl + ["get", "pods", "-n", "kube-system", "--field-selector", "status.phase!=Running"],
                capture_output=True, text=True, timeout=10
            )
            failed_pods = [line for line in res_pods.stdout.split('\n') if line.strip() and "NAME" not in line]
            
            if failed_pods:
                self.health_status = f"WARNING ({len(failed_pods)} Unhealthy Pods)"
                print(f"{Colors.YELLOW}    -> {self.health_status}{Colors.ENDC}")
            else:
                self.health_status = "OK (Healthy)"
                print(f"{Colors.GREEN}    -> {self.health_status}{Colors.ENDC}")
                
        except Exception as e:
            self.health_status = f"ERROR ({str(e)})"
            print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
        
        return self.health_status

    def extract_metadata_from_script(self, script_path):
        """Extract title directly from script file."""
        title = "Title not found"
        if not script_path or not os.path.exists(script_path): return title

        try:
            with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()[:30]
            for line in lines:
                line = line.strip()
                if not line.startswith("#"): continue
                clean = line.lstrip("#").strip()
                if "Title:" in line:
                    return line.split("Title:", 1)[1].strip()
                prefixes = ["Ensure", "Enable", "Disable", "Configure", "Restrict"]
                if any(clean.startswith(p) for p in prefixes):
                    if 10 < len(clean) < 150: return clean
        except: pass
        return title

    def get_scripts(self, mode, target_level, target_role):
        suffix = "_remediate.sh" if mode == "remediate" else "_audit.sh"
        scripts = []
        levels = ['1', '2'] if target_level == "all" else [target_level]
        roles = ['Master', 'Worker'] if target_role == "all" else [target_role.capitalize()]
        
        for role in roles:
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

    def run_script(self, script, mode):
        if self.stop_requested: return None
        start_time = time.time()
        
        # Check if rule is excluded
        if self.is_rule_excluded(script["id"]):
            exclusion_reason = self.get_rule_exclusion_reason(script["id"])
            return {
                "id": script["id"],
                "role": script["role"],
                "level": script["level"],
                "status": "IGNORED",
                "duration": 0.0,
                "reason": f"Excluded: {exclusion_reason}",
                "output": "",
                "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }
        
        try:
            # Check if this is a manual check from the script title
            is_manual = False
            try:
                with open(script["path"], 'r', encoding='utf-8', errors='ignore') as f:
                    for line in f.readlines()[:10]:
                        if "# Title:" in line and "(Manual)" in line:
                            is_manual = True
                            break
            except:
                pass
            
            # Skip manual checks if user requested
            if is_manual and self.skip_manual and mode == "audit":
                return {
                    "id": script["id"],
                    "role": script["role"],
                    "level": script["level"],
                    "status": "SKIPPED",
                    "duration": 0.0,
                    "reason": "Manual check skipped by user",
                    "output": "",
                    "path": script["path"],
                    "component": self.get_component_for_rule(script["id"])
                }
            
            cmd = ["bash", script["path"]]
            try:
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=self.script_timeout)
            except subprocess.TimeoutExpired:
                return {
                    "id": script["id"], "role": script["role"], "level": script["level"],
                    "status": "ERROR", "reason": f"Script timeout after {self.script_timeout}s", "output": "", "path": script["path"],
                    "component": self.get_component_for_rule(script["id"])
                }
            duration = round(time.time() - start_time, 2)
            
            status = "FAIL"
            reason = ""

            if mode == "remediate":
                status = "FIXED" if res.returncode == 0 else "ERROR"
            else:
                if is_manual:
                    status = "MANUAL"
                elif res.returncode == 0:
                    status = "PASS"
                else:
                    status = "FAIL"
                    lines = [l.strip() for l in res.stdout.split('\n') if l.strip()]
                    for line in lines:
                        if "Check Failed" in line or "Reason" in line:
                            reason = line
                            break
                    if not reason and lines: reason = lines[-1]

            return {
                "id": script["id"],
                "role": script["role"],
                "level": script["level"],
                "status": status,
                "duration": duration,
                "reason": reason,
                "output": res.stdout + res.stderr,
                "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }
        except subprocess.TimeoutExpired as e:
            return {
                "id": script["id"], "role": script["role"], "level": script["level"],
                "status": "ERROR", "reason": f"Timeout after {self.script_timeout}s", "output": "", "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }
        except FileNotFoundError as e:
            return {
                "id": script["id"], "role": script["role"], "level": script["level"],
                "status": "ERROR", "reason": f"Script not found: {script['path']}", "output": "", "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }
        except PermissionError as e:
            return {
                "id": script["id"], "role": script["role"], "level": script["level"],
                "status": "ERROR", "reason": f"Permission denied executing script", "output": "", "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }
        except Exception as e:
            return {
                "id": script["id"], "role": script["role"], "level": script["level"], 
                "status": "ERROR", "reason": f"Unexpected error: {str(e)}", "output": "", "path": script["path"],
                "component": self.get_component_for_rule(script["id"])
            }

    def update_stats(self, result):
        if not result: return
        role = "master" if "master" in result["role"] else "worker"
        status = result["status"].lower()
        if status not in self.stats[role]: 
            if status not in ["skipped", "ignored"]:
                status = "error"
            else:
                return
        self.stats[role][status] += 1
        self.stats[role]["total"] += 1

    def perform_backup(self):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest_dir = os.path.join(self.base_dir, BACKUP_DIR, f"backup_{timestamp}")
        os.makedirs(dest_dir, exist_ok=True)
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}[*] Creating Backup...{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        targets = ["/etc/kubernetes/manifests", "/var/lib/kubelet/config.yaml"]
        for target in targets:
            if os.path.exists(target):
                try:
                    name = os.path.basename(target)
                    if os.path.isdir(target): shutil.copytree(target, os.path.join(dest_dir, name))
                    else: shutil.copy2(target, dest_dir)
                except Exception as e:
                    print(f"{Colors.RED}Backup Error {target}: {e}{Colors.ENDC}")
        print(f"   -> Saved to: {dest_dir}")

    def show_verbose_result(self, res):
        title = self.extract_metadata_from_script(res.get('path'))
        color = Colors.GREEN if res['status'] in ['PASS', 'FIXED'] else (Colors.YELLOW if res['status'] in ['MANUAL', 'SKIPPED'] else Colors.RED)
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"DETAILS - {color}{res['status']}{Colors.ENDC} - {res['id']}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"  Title:         {title}")
        print(f"  Time:          {res['duration']}s")
        if res['reason']: print(f"  {Colors.YELLOW}Reason:        {res['reason']}{Colors.ENDC}")
        
        # Show output for PASS, FAIL, ERROR, SKIPPED (but NOT MANUAL)
        if res['status'] in ['PASS', 'FIXED', 'FAIL', 'ERROR', 'SKIPPED']:
            print(f"\n  {Colors.YELLOW}[i] Raw Output:{Colors.ENDC}")
            output = res['output'].strip()
            if output:
                print('\n'.join(output.split('\n')[-5:]))
            else:
                print("  (no output)")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")

    def _prepare_report_dir(self, mode):
        """Creates specific folder for this run (Oracle Style)"""
        run_folder = f"run_{self.timestamp}"
        self.current_report_dir = os.path.join(self.date_dir, mode, run_folder)
        os.makedirs(self.current_report_dir, exist_ok=True)
        return self.current_report_dir

    def scan(self, target_level, target_role):
        print(f"\n{Colors.CYAN}[*] Starting Audit Scan...{Colors.ENDC}")
        self.log_activity("AUDIT_START", f"Level:{target_level}, Role:{target_role}, Timeout:{self.script_timeout}s, SkipManual:{self.skip_manual}")
        self._prepare_report_dir("audit")
        
        scripts = self.get_scripts("audit", target_level, target_role)
        self.results = []
        
        # Reset stats
        self.stats = {
            "master": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0},
            "worker": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0}
        }

        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {executor.submit(self.run_script, s, "audit"): s for s in scripts}
            try:
                completed = 0
                for future in as_completed(futures):
                    if self.stop_requested: break
                    res = future.result()
                    if res:
                        res['path'] = futures[future]['path']
                        self.results.append(res)
                        self.update_stats(res)
                        completed += 1
                        if self.verbose: self.show_verbose_result(res)
                        else:
                            if res['status'] == "SKIPPED":
                                progress_pct = (completed / len(scripts)) * 100
                                print(f"   [{progress_pct:5.1f}%] [{completed}/{len(scripts)}] {res['id']} -> {Colors.CYAN}SKIPPED{Colors.ENDC}")
                            else:
                                progress_pct = (completed / len(scripts)) * 100
                                color = Colors.GREEN if res['status'] == "PASS" else (Colors.YELLOW if res['status'] == "MANUAL" else Colors.RED)
                                print(f"   [{progress_pct:5.1f}%] [{completed}/{len(scripts)}] {res['id']} -> {color}{res['status']}{Colors.ENDC}")
            except KeyboardInterrupt:
                self.stop_requested = True
                print("\nAborted.")

        print(f"\n{Colors.GREEN}[+] Audit Complete.{Colors.ENDC}")
        self.save_reports("audit")
        self.print_stats_summary()
        
        # Calculate score and show trend analysis
        current_score = self.calculate_score(self.stats)
        previous_snapshot = self.get_previous_snapshot("audit", target_role, target_level)
        if previous_snapshot:
            self.show_trend_analysis(current_score, previous_snapshot)
        
        # Save snapshot for future comparison
        self.save_snapshot("audit", target_role, target_level)
        
        self.log_activity("AUDIT_END", f"Total:{len(self.results)}, Pass:{self.stats['master']['pass']+self.stats['worker']['pass']}, Fail:{self.stats['master']['fail']+self.stats['worker']['fail']}, Manual:{self.stats['master']['manual']+self.stats['worker']['manual']}, Skipped:{self.stats['master']['skipped']+self.stats['worker']['skipped']}, Ignored:{self.stats['master']['ignored']+self.stats['worker']['ignored']}")
        self.show_results_menu("audit")

    def fix(self, target_level, target_role):
        if "CRITICAL" in self.health_status:
            print(f"\n{Colors.RED}[-] Cannot remediate: Cluster Health is CRITICAL.{Colors.ENDC}")
            self.log_activity("FIX_SKIPPED", "Cluster health is CRITICAL")
            return

        self._prepare_report_dir("remediation")
        self.log_activity("FIX_START", f"Level:{target_level}, Role:{target_role}, Timeout:{self.script_timeout}s")
        self.perform_backup()
        print(f"\n{Colors.YELLOW}[*] Starting Remediation...{Colors.ENDC}")
        scripts = self.get_scripts("remediate", target_level, target_role)
        self.results = []
        
        # Reset stats (scan and fix both use the same stats)
        self.stats = {
            "master": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0},
            "worker": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0}
        }

        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {executor.submit(self.run_script, s, "remediate"): s for s in scripts}
            try:
                completed = 0
                for future in as_completed(futures):
                    if self.stop_requested: break
                    res = future.result()
                    if res:
                        res['path'] = futures[future]['path']
                        self.results.append(res)
                        self.update_stats(res)
                        completed += 1
                        color = Colors.GREEN if res['status'] == "FIXED" else Colors.RED
                        progress_pct = (completed / len(scripts)) * 100
                        print(f"   [{progress_pct:5.1f}%] [{completed}/{len(scripts)}] {res['id']} -> {color}{res['status']}{Colors.ENDC}")
            except KeyboardInterrupt:
                self.stop_requested = True
                print("\nAborted.")
            
        print(f"\n{Colors.GREEN}[+] Remediation Complete.{Colors.ENDC}")
        self.save_reports("remediate")
        self.print_stats_summary()
        
        # Calculate score and show trend analysis
        current_score = self.calculate_score(self.stats)
        previous_snapshot = self.get_previous_snapshot("remediate", target_role, target_level)
        if previous_snapshot:
            self.show_trend_analysis(current_score, previous_snapshot)
        
        # Save snapshot for future comparison
        self.save_snapshot("remediate", target_role, target_level)
        
        self.log_activity("FIX_END", f"Total:{len(self.results)}, Fixed:{self.stats['master']['pass']+self.stats['worker']['pass']}, Failed:{self.stats['master']['fail']+self.stats['worker']['fail']}, Error:{self.stats['master']['error']+self.stats['worker']['error']}, Ignored:{self.stats['master']['ignored']+self.stats['worker']['ignored']}")
        self.show_results_menu("remediate")

    def save_snapshot(self, mode, role, level):
        """Save current scan results to history for trend comparison"""
        history_file = os.path.join(self.base_dir, HISTORY_DIR, f"snapshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{mode}_{role}_{level}.json")
        snapshot = {
            "timestamp": datetime.now().isoformat(),
            "mode": mode,
            "role": role,
            "level": level,
            "stats": self.stats,
            "results": self.results
        }
        try:
            with open(history_file, 'w') as f:
                json.dump(snapshot, f, indent=2)
            if self.verbose:
                print(f"{Colors.BLUE}[DEBUG] Snapshot saved: {history_file}{Colors.ENDC}")
        except Exception as e:
            if self.verbose:
                print(f"{Colors.RED}[DEBUG] Error saving snapshot: {e}{Colors.ENDC}")
    
    def get_previous_snapshot(self, mode, role, level):
        """Retrieve the most recent previous snapshot for trend analysis"""
        history_dir = os.path.join(self.base_dir, HISTORY_DIR)
        if not os.path.exists(history_dir):
            return None
        
        pattern = f"snapshot_*_{mode}_{role}_{level}.json"
        snapshots = sorted(glob.glob(os.path.join(history_dir, pattern)), reverse=True)
        
        if snapshots:
            try:
                with open(snapshots[0], 'r') as f:
                    return json.load(f)
            except Exception as e:
                if self.verbose:
                    print(f"{Colors.YELLOW}[!] Error loading previous snapshot: {e}{Colors.ENDC}")
        
        return None
    
    def calculate_score(self, stats):
        """Calculate compliance score (Pass / (Pass + Fail + Manual))"""
        total_master = stats["master"]["pass"] + stats["master"]["fail"] + stats["master"]["manual"]
        total_worker = stats["worker"]["pass"] + stats["worker"]["fail"] + stats["worker"]["manual"]
        total = total_master + total_worker
        
        if total == 0:
            return 0.0
        
        passed = stats["master"]["pass"] + stats["worker"]["pass"]
        return round((passed / total) * 100, 2)
    
    def show_trend_analysis(self, current_score, previous_snapshot):
        """Display trend analysis comparing current and previous scores"""
        if not previous_snapshot:
            return
        
        previous_stats = previous_snapshot.get("stats", {})
        previous_score = self.calculate_score(previous_stats)
        trend = current_score - previous_score
        trend_symbol = "📈" if trend > 0 else ("📉" if trend < 0 else "➡️")
        trend_color = Colors.GREEN if trend > 0 else (Colors.RED if trend < 0 else Colors.YELLOW)
        
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}TREND ANALYSIS (Score Comparison){Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"  Current Score:   {Colors.BOLD}{current_score}%{Colors.ENDC}")
        print(f"  Previous Score:  {Colors.BOLD}{previous_score}%{Colors.ENDC}")
        print(f"  Change:          {trend_color}{trend_symbol} {'+' if trend > 0 else ''}{trend:.2f}%{Colors.ENDC}")
        print(f"  Previous Run:    {previous_snapshot.get('timestamp', 'Unknown')}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")

    def generate_text_report(self, mode):
        """Generates Oracle-Style Summary & Failure Reports with Component Breakdown"""
        summary_file = os.path.join(self.current_report_dir, "summary.txt")
        failed_file = os.path.join(self.current_report_dir, "failed_items.txt")
        component_file = os.path.join(self.current_report_dir, "component_summary.txt")

        passed = [r for r in self.results if r['status'] in ['PASS', 'FIXED']]
        failed = [r for r in self.results if r['status'] in ['FAIL', 'ERROR']]
        manual = [r for r in self.results if r['status'] == 'MANUAL']
        skipped = [r for r in self.results if r['status'] == 'SKIPPED']
        ignored = [r for r in self.results if r['status'] == 'IGNORED']

        # Summary
        with open(summary_file, 'w') as f:
            f.write("="*60 + "\n")
            f.write(f"CIS BENCHMARK SUMMARY - {mode.upper()}\n")
            f.write(f"Date: {datetime.now()}\n")
            f.write("="*60 + "\n\n")
            f.write(f"Total: {len(self.results)}\n")
            f.write(f"Pass:  {len(passed)}\n")
            f.write(f"Fail:  {len(failed)}\n")
            f.write(f"Manual: {len(manual)}\n")
            f.write(f"Skipped: {len(skipped)}\n")
            f.write(f"Ignored: {len(ignored)}\n")
            total_evaluated = len(passed) + len(failed) + len(manual)
            score = (len(passed)/total_evaluated)*100 if total_evaluated else 0
            f.write(f"Score: {score:.2f}%\n")

        # Failed Items + Manual + Skipped
        with open(failed_file, 'w') as f:
            f.write(f"DETAILED RESULTS ({mode.upper()})\n")
            f.write("="*60 + "\n")
            
            if manual or failed:
                f.write(f"\nFAILED & MANUAL ITEMS ({len(failed) + len(manual)} total)\n")
                f.write("-"*60 + "\n")
                for item in failed + manual:
                    title = self.extract_metadata_from_script(item.get('path'))
                    f.write(f"\nCIS ID: {item['id']} [{item['status']}]\n")
                    f.write(f"Title:  {title}\n")
                    f.write(f"Role:   {item['role'].upper()}\n")
                    if item['reason']: f.write(f"Reason: {item['reason']}\n")
                    f.write("-" * 40 + "\n")
            
            if skipped:
                f.write(f"\n\nSKIPPED ITEMS ({len(skipped)} total)\n")
                f.write("-"*60 + "\n")
                for item in skipped:
                    title = self.extract_metadata_from_script(item.get('path'))
                    f.write(f"\nCIS ID: {item['id']} [SKIPPED]\n")
                    f.write(f"Title:  {title}\n")
                    f.write(f"Role:   {item['role'].upper()}\n")
                    f.write(f"Reason: {item['reason']}\n")
                    f.write("-" * 40 + "\n")
            
            if ignored:
                f.write(f"\n\nIGNORED ITEMS ({len(ignored)} total)\n")
                f.write("-"*60 + "\n")
                for item in ignored:
                    title = self.extract_metadata_from_script(item.get('path'))
                    f.write(f"\nCIS ID: {item['id']} [IGNORED]\n")
                    f.write(f"Title:  {title}\n")
                    f.write(f"Role:   {item['role'].upper()}\n")
                    f.write(f"Reason: {item['reason']}\n")
                    f.write("-" * 40 + "\n")

        # Component-Based Summary
        with open(component_file, 'w') as f:
            f.write("="*60 + "\n")
            f.write("COMPONENT-BASED SUMMARY\n")
            f.write(f"Date: {datetime.now()}\n")
            f.write("="*60 + "\n\n")
            
            # Group results by component
            components = {}
            for result in self.results:
                component = result.get('component', 'Other')
                if component not in components:
                    components[component] = {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "ignored": 0, "error": 0, "total": 0}
                
                status = result['status'].lower()
                if status in components[component]:
                    components[component][status] += 1
                components[component]['total'] += 1
            
            # Display component breakdown
            for component in sorted(components.keys()):
                stats = components[component]
                if stats['total'] > 0:
                    success_rate = (stats['pass'] * 100 // stats['total']) if stats['total'] > 0 else 0
                    f.write(f"\n{component}\n")
                    f.write("-" * 40 + "\n")
                    f.write(f"  Pass:    {stats['pass']}\n")
                    f.write(f"  Fail:    {stats['fail']}\n")
                    f.write(f"  Manual:  {stats['manual']}\n")
                    f.write(f"  Skipped: {stats['skipped']}\n")
                    f.write(f"  Ignored: {stats['ignored']}\n")
                    f.write(f"  Error:   {stats['error']}\n")
                    f.write(f"  Total:   {stats['total']}\n")
                    f.write(f"  Success Rate: {success_rate}%\n")

        return summary_file, failed_file, component_file

    def generate_html_report(self, mode):
        """Generates HTML Report"""
        html_file = os.path.join(self.current_report_dir, "report.html")
        
        passed = [r for r in self.results if r['status'] in ['PASS', 'FIXED']]
        failed = [r for r in self.results if r['status'] in ['FAIL', 'ERROR']]
        manual = [r for r in self.results if r['status'] == 'MANUAL']
        skipped = [r for r in self.results if r['status'] == 'SKIPPED']
        
        total_evaluated = len(passed) + len(failed) + len(manual)
        score = (len(passed)/total_evaluated)*100 if total_evaluated else 0
        
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>CIS Kubernetes Benchmark Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }}
        h1 {{ color: #333; text-align: center; }}
        .summary {{ background-color: #f9f9f9; padding: 15px; margin: 20px 0; border-left: 4px solid #007bff; }}
        .stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin: 20px 0; }}
        .stat-box {{ padding: 15px; text-align: center; border-radius: 4px; }}
        .stat-pass {{ background-color: #d4edda; color: #155724; }}
        .stat-fail {{ background-color: #f8d7da; color: #721c24; }}
        .stat-manual {{ background-color: #fff3cd; color: #856404; }}
        .stat-skipped {{ background-color: #d1ecf1; color: #0c5460; }}
        .stat-number {{ font-size: 24px; font-weight: bold; }}
        .stat-label {{ font-size: 12px; margin-top: 5px; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th {{ background-color: #007bff; color: white; padding: 10px; text-align: left; }}
        td {{ padding: 10px; border-bottom: 1px solid #ddd; }}
        tr:hover {{ background-color: #f5f5f5; }}
        .status-pass {{ color: #28a745; font-weight: bold; }}
        .status-fail {{ color: #dc3545; font-weight: bold; }}
        .status-manual {{ color: #ffc107; font-weight: bold; }}
        .status-skipped {{ color: #17a2b8; font-weight: bold; }}
        .score {{ font-size: 32px; font-weight: bold; color: #007bff; }}
        .footer {{ text-align: center; margin-top: 20px; color: #666; font-size: 12px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>CIS Kubernetes Benchmark Report</h1>
        
        <div class="summary">
            <h2>Execution Summary</h2>
            <p><strong>Mode:</strong> {mode.upper()}</p>
            <p><strong>Date:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            <p><strong>Total Checks:</strong> {len(self.results)}</p>
        </div>
        
        <div class="stats">
            <div class="stat-box stat-pass">
                <div class="stat-number">{len(passed)}</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat-box stat-fail">
                <div class="stat-number">{len(failed)}</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-box stat-manual">
                <div class="stat-number">{len(manual)}</div>
                <div class="stat-label">Manual</div>
            </div>
            <div class="stat-box stat-skipped">
                <div class="stat-number">{len(skipped)}</div>
                <div class="stat-label">Skipped</div>
            </div>
        </div>
        
        <div class="summary">
            <h2>Compliance Score</h2>
            <p>
                <span class="score">{score:.1f}%</span>
                <br/><small>(Pass / (Pass + Fail + Manual))</small>
            </p>
        </div>
        
        <h2>Results by Status</h2>
        <table>
            <tr>
                <th>CIS ID</th>
                <th>Title</th>
                <th>Role</th>
                <th>Status</th>
                <th>Duration (s)</th>
            </tr>
"""
        
        # Add all results to table
        for r in sorted(self.results, key=lambda x: x['id']):
            title = self.extract_metadata_from_script(r.get('path'))
            status_class = f"status-{r['status'].lower()}"
            html_content += f"""
            <tr>
                <td>{r['id']}</td>
                <td>{title}</td>
                <td>{r['role'].upper()}</td>
                <td><span class="{status_class}">{r['status']}</span></td>
                <td>{r['duration']}</td>
            </tr>
"""
        
        html_content += """
        </table>
        
        <div class="footer">
            <p>Generated by CIS Kubernetes Benchmark Unified Runner</p>
        </div>
    </div>
</body>
</html>
"""
        
        with open(html_file, 'w') as f:
            f.write(html_content)
        
        return html_file

    def save_reports(self, mode):
        csv_file = os.path.join(self.current_report_dir, "report.csv")
        json_file = os.path.join(self.current_report_dir, "report.json")
        
        # [FIX] Allow extra fields like 'path' and 'component'
        fieldnames = ["id", "role", "level", "status", "duration", "reason", "output", "component"]
        
        try:
            with open(csv_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
                writer.writeheader()
                writer.writerows(self.results)
        except Exception as e:
            print(f"{Colors.RED}CSV Error: {e}{Colors.ENDC}")

        sum_file, fail_file, comp_file = self.generate_text_report(mode)
        html_file = self.generate_html_report(mode)
        
        with open(json_file, 'w') as f:
            json.dump({"stats": self.stats, "details": self.results}, f, indent=2)
        
        print(f"\n   [*] Reports Saved in: {self.current_report_dir}")
        print(f"      - {os.path.basename(sum_file)}")
        print(f"      - {os.path.basename(fail_file)}")
        print(f"      - {os.path.basename(comp_file)}")
        print(f"      - report.csv")
        print(f"      - report.json")
        print(f"      - {os.path.basename(html_file)}")

    def print_stats_summary(self):
        """Display statistics summary (Oracle-style)"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}STATISTICS SUMMARY{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        
        for role in ["master", "worker"]:
            s = self.stats[role]
            if s['total'] > 0:
                success_rate = (s['pass'] * 100 // s['total']) if s['total'] > 0 else 0
                print(f"\n  {Colors.BOLD}{role.upper()}:{Colors.ENDC}")
                print(f"    [+] Pass:    {s['pass']}")
                print(f"    [-] Fail:    {s['fail']}")
                print(f"    [!] Manual:  {s['manual']}")
                print(f"    [>>] Skipped: {s['skipped']}")
                print(f"    [✓] Ignored: {s['ignored']}")
                print(f"    [*] Total:   {s['total']}")
                print(f"    [%] Success: {success_rate}%")
        
        # Show performance report - Top 5 slowest checks
        if self.results:
            print(f"\n{Colors.CYAN}TOP 5 SLOWEST CHECKS:{Colors.ENDC}")
            sorted_results = sorted(self.results, key=lambda x: x['duration'], reverse=True)[:5]
            for i, r in enumerate(sorted_results, 1):
                print(f"  {i}. {r['id']:15} {r['duration']:6.2f}s - {r['status']}")
        
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")

    def show_results_menu(self, mode):
        """Show summary and menu after audit/fix completion"""
        while True:
            print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
            print(f"{Colors.CYAN}RESULTS MENU:{Colors.ENDC}")
            print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
            print(f"\n  1) View summary report")
            print(f"  2) View failed/manual items")
            print(f"  3) View detailed report")
            print(f"  4) Return to main menu")
            print()
            
            choice = input(f"{Colors.BOLD}Choose [1-4]: {Colors.ENDC}").strip()
            
            if choice == '1':
                summary_file = os.path.join(self.current_report_dir, "summary.txt")
                if os.path.exists(summary_file):
                    with open(summary_file, 'r') as f:
                        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
                        print(f.read())
                        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
            elif choice == '2':
                failed_file = os.path.join(self.current_report_dir, "failed_items.txt")
                if os.path.exists(failed_file):
                    with open(failed_file, 'r') as f:
                        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
                        print(f.read())
                        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
            elif choice == '3':
                html_file = os.path.join(self.current_report_dir, "report.html")
                if os.path.exists(html_file):
                    with open(html_file, 'r') as f:
                        content = f.read()
                        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
                        print("HTML Report saved at:")
                        print(f"  {html_file}")
                        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
            elif choice == '4':
                break
            else:
                print(f"{Colors.RED}Invalid choice. Try again.{Colors.ENDC}")

    def show_help(self):
        """Display help information for menu options"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}HELP - Menu Options & Features{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"""
{Colors.BOLD}[1] AUDIT{Colors.ENDC}
    Scan all compliance checks and report results
    
    Options:
      • Kubernetes Role: Choose to audit Master, Worker, or both nodes
      • CIS Level: Select Level 1 (Essential), Level 2 (Scored), or both
      • Verbose output: Show detailed information for each check
      • Skip manual checks: Skip checks requiring manual verification (faster)
      • Script timeout: Max seconds to wait per check (increase if system is slow)

    Output:
      • Summary report with pass/fail/manual/skip counts
      • Failed items list with reasons
      • HTML and JSON reports for detailed review

{Colors.BOLD}[2] REMEDIATION{Colors.ENDC}
    Apply fixes to non-compliant items (MODIFIES CLUSTER)
    
    Options:
      • Role & Level: Same as audit
      • Timeout: Max seconds per remediation script
      
    Process:
      1. Automatic backup created before changes
      2. Scripts run in parallel (8 concurrent max)
      3. Results saved to report files

{Colors.BOLD}[3] BOTH{Colors.ENDC}
    Run audit first, then remediation if confirmed
    
    Process:
      1. Audit scan completes
      2. User reviews audit results
      3. Option to proceed with remediation

{Colors.BOLD}[4] HEALTH CHECK{Colors.ENDC}
    Check Kubernetes cluster status
    
    Displays:
      • Node status (Ready/NotReady)
      • Pod status in kube-system namespace
      • Overall cluster health status

{Colors.BOLD}[5] HELP{Colors.ENDC}
    Display this help information

{Colors.BOLD}[0] EXIT{Colors.ENDC}
    Exit the application

{Colors.CYAN}{'='*70}{Colors.ENDC}
{Colors.BOLD}IMPORTANT NOTES:{Colors.ENDC}
  • Remediation scripts require cluster-admin privileges
  • Always backup critical configurations before remediation
  • Review audit results before applying fixes
  • Some checks may require manual verification

{Colors.CYAN}{'='*70}{Colors.ENDC}
""")

    def show_menu(self):
        """Display main menu with options and get user selection"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}SELECT MODE:{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"\n  {Colors.BOLD}1) Audit only{Colors.ENDC}")
        print("     Run compliance audit (non-destructive)")
        print(f"\n  {Colors.BOLD}2) Remediation only{Colors.ENDC}")
        print("     Apply fixes to non-compliant items (DESTRUCTIVE)")
        print(f"\n  {Colors.BOLD}3) Both (Audit first, then Remediation){Colors.ENDC}")
        print("     Run audit then fix if confirmed")
        print(f"\n  {Colors.BOLD}4) Health Check{Colors.ENDC}")
        print("     Check cluster health status")
        print(f"\n  {Colors.BOLD}5) Help{Colors.ENDC}")
        print("     Display help and documentation")
        print(f"\n  {Colors.BOLD}0) Exit{Colors.ENDC}")
        print("     Exit application")
        print()
        
        while True:
            choice = input(f"{Colors.BOLD}Choose [0-5]: {Colors.ENDC}").strip()
            if choice in ['0', '1', '2', '3', '4', '5']:
                return choice
            print(f"{Colors.RED}Invalid choice. Try again.{Colors.ENDC}")

    def get_audit_options(self):
        """Get audit-specific options from user"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.CYAN}AUDIT CONFIGURATION:{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
        
        print("  Kubernetes Role:")
        print("    1) Master nodes only")
        print("    2) Worker nodes only")
        print("    3) Both Master and Worker")
        while True:
            role_choice = input("\n  Select role [3]: ").strip() or "3"
            if role_choice == "1":
                role = "master"
                break
            elif role_choice == "2":
                role = "worker"
                break
            elif role_choice == "3":
                role = "all"
                break
            print(f"  {Colors.RED}Invalid choice. Try again.{Colors.ENDC}")
        
        print(f"\n  CIS Level:")
        print("    1) Level 1 (Essential)")
        print("    2) Level 2 (Scored)")
        print("    3) All Levels")
        while True:
            level_choice = input("\n  Select level [3]: ").strip() or "3"
            if level_choice == "1":
                level = "1"
                break
            elif level_choice == "2":
                level = "2"
                break
            elif level_choice == "3":
                level = "all"
                break
            print(f"  {Colors.RED}Invalid choice. Try again.{Colors.ENDC}")
        
        # Use verbose setting from command line argument (self.verbose)
        # Hardcoded values (no user input needed)
        skip_manual = False
        timeout = 60
        
        return level, role, self.verbose, skip_manual, timeout

    def get_remediation_options(self):
        """Get remediation-specific options from user"""
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
        print(f"{Colors.YELLOW}[!] WARNING: REMEDIATION WILL MODIFY YOUR CLUSTER!{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}\n")
        
        print("  Kubernetes Role:")
        print("    1) Master nodes only")
        print("    2) Worker nodes only")
        print("    3) Both Master and Worker")
        while True:
            role_choice = input("\n  Select role [3]: ").strip() or "3"
            if role_choice == "1":
                role = "master"
                break
            elif role_choice == "2":
                role = "worker"
                break
            elif role_choice == "3":
                role = "all"
                break
            print(f"  {Colors.RED}Invalid choice. Try again.{Colors.ENDC}")
        
        print(f"\n  CIS Level:")
        print("    1) Level 1 (Essential)")
        print("    2) Level 2 (Scored)")
        print("    3) All Levels")
        while True:
            level_choice = input("\n  Select level [3]: ").strip() or "3"
            if level_choice == "1":
                level = "1"
                break
            elif level_choice == "2":
                level = "2"
                break
            elif level_choice == "3":
                level = "all"
                break
            print(f"  {Colors.RED}Invalid choice. Try again.{Colors.ENDC}")
        
        # Hardcoded timeout value (no user input needed)
        timeout = 60
        
        return level, role, timeout

    def confirm_action(self, message):
        """Ask user for confirmation"""
        while True:
            response = input(f"\n{message} [y/n]: ").strip().lower()
            if response in ['y', 'yes']:
                return True
            elif response in ['n', 'no']:
                return False
            print(f"{Colors.RED}Invalid choice. Please enter 'y' or 'n'.{Colors.ENDC}")

    def main_loop(self):
        self.show_banner()
        self.check_health()
        
        while True:
            choice = self.show_menu()
            
            if choice == '1':  # Audit
                level, role, verbose, skip_manual, timeout = self.get_audit_options()
                self.verbose = verbose
                self.skip_manual = skip_manual
                self.script_timeout = timeout
                self.log_activity("MENU_SELECT", f"AUDIT (Level:{level}, Role:{role})")
                self.scan(level, role)
                
            elif choice == '2':  # Remediation
                level, role, timeout = self.get_remediation_options()
                self.script_timeout = timeout
                
                if self.confirm_action(f"{Colors.RED}Confirm remediation on {role} nodes with Level {level}?{Colors.ENDC}"):
                    self.log_activity("MENU_SELECT", f"FIX (Level:{level}, Role:{role})")
                    self.perform_backup()
                    self.fix(level, role)
                else:
                    self.log_activity("MENU_SELECT", "FIX CANCELLED")
                    
            elif choice == '3':  # Both
                level, role, verbose, skip_manual, timeout = self.get_audit_options()
                self.verbose = verbose
                self.skip_manual = skip_manual
                self.script_timeout = timeout
                self.log_activity("MENU_SELECT", f"BOTH (Level:{level}, Role:{role})")
                self.scan(level, role)
                
                if self.confirm_action(f"{Colors.RED}Proceed to remediation?{Colors.ENDC}"):
                    self.perform_backup()
                    self.fix(level, role)
                else:
                    self.log_activity("MENU_SELECT", "FIX CANCELLED AFTER AUDIT")
                    
            elif choice == '4':  # Health Check
                self.log_activity("MENU_SELECT", "HEALTH_CHECK")
                self.check_health()
                
            elif choice == '5':  # Help
                self.log_activity("MENU_SELECT", "HELP")
                self.show_help()
                
            elif choice == '0':  # Exit
                self.log_activity("MENU_SELECT", "EXIT")
                print(f"\n{Colors.CYAN}Goodbye!{Colors.ENDC}\n")
                sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()
    runner = CISUnifiedRunner(verbose=args.verbose)
    runner.main_loop()