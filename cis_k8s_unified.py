#!/usr/bin/env python3
"""
CIS Kubernetes Benchmark - Unified Interactive Runner (Enhanced & Optimized)
คู่มือระบบตรวจสอบ CIS Kubernetes - ตัวรันโปรแกรมแบบรวมและโต้ตอบ (เพิ่มประสิทธิภาพ)

Features / ฟีเจอร์:
- Smart Kubeconfig Detection / การตรวจจับ Kubeconfig อัจฉริยะ
- Auto Backup System / ระบบสำรองข้อมูลอัตโนมัติ
- Oracle-Style Detailed XML/Text Reporting / รายงานแบบ Oracle
- Robust CSV Generation / สร้าง CSV ที่เชื่อถือได้
- Component-Based Summary / สรุปตามส่วนประกอบ
"""

import os
import sys
import shutil
import subprocess
import json
import csv
import time
import argparse
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import glob
import socket

# --- Constants / ค่าคงที่ ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, "cis_config.json")
LOG_FILE = os.path.join(BASE_DIR, "cis_runner.log")
REPORT_DIR = os.path.join(BASE_DIR, "reports")
BACKUP_DIR = os.path.join(BASE_DIR, "backups")
HISTORY_DIR = os.path.join(BASE_DIR, "history")

# Max workers for parallel execution / จำนวนผู้ปฏิบัติงานสูงสุดสำหรับการทำงานแบบขนาน
MAX_WORKERS = 8
SCRIPT_TIMEOUT = 60  # seconds / วินาที
REQUIRED_TOOLS = ["kubectl", "jq", "grep", "sed", "awk"]  # Required dependencies / การพึ่งพาที่จำเป็น


class Colors:
    """Terminal color codes / รหัสสีของเทอร์มินัล"""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    WHITE = '\033[97m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class CISUnifiedRunner:
    """
    Main CIS Kubernetes Benchmark Runner
    ตัวรันหลักของ CIS Kubernetes Benchmark
    """
    
    def __init__(self, verbose=0):
        """Initialize runner with configuration / เริ่มต้นตัวรันพร้อมการตั้งค่า"""
        self.base_dir = BASE_DIR
        self.config_file = CONFIG_FILE
        self.log_file = LOG_FILE
        self.report_dir = REPORT_DIR
        self.backup_dir = BACKUP_DIR
        self.history_dir = HISTORY_DIR
        
        # Execution settings / การตั้งค่าการดำเนิน
        self.verbose = verbose
        self.skip_manual = False
        self.script_timeout = SCRIPT_TIMEOUT
        
        # Results tracking / การติดตามผลลัพธ์
        self.results = []
        self.stats = {}
        self.stop_requested = False
        self.health_status = "UNKNOWN"
        
        # Timestamp and directories / แสตมป์เวลาและไดเรกทอรี
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.date_dir = os.path.join(self.report_dir, datetime.now().strftime("%Y-%m-%d"))
        self.current_report_dir = None
        
        # Create required directories / สร้างไดเรกทอรีที่จำเป็น
        for directory in [self.report_dir, self.backup_dir, self.history_dir, self.date_dir]:
            os.makedirs(directory, exist_ok=True)
        
        self.load_config()
        self.check_dependencies()

    def show_banner(self):
        """Display application banner / แสดงแบนเนอร์แอปพลิเคชัน"""
        banner = f"""
{Colors.CYAN}{'='*70}
  CIS Kubernetes Benchmark - Unified Interactive Runner
  ตัวรันเครื่องมือตรวจสอบ CIS Kubernetes แบบรวมและโต้ตอบ
  Version: 1.0 (Optimized)
  Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
{'='*70}{Colors.ENDC}
"""
        print(banner)

    def load_config(self):
        """Load configuration from JSON file / โหลดการตั้งค่าจากไฟล์ JSON"""
        self.excluded_rules = {}
        self.component_mapping = {}
        self.remediation_config = {}
        self.remediation_global_config = {}
        self.remediation_checks_config = {}
        self.remediation_env_vars = {}
        
        # Initialize API timeout settings with defaults
        self.api_check_interval = 5  # seconds
        self.api_max_retries = 60    # 60 * 5 = 300 seconds total (5 minutes)
        self.wait_for_api_enabled = True
        
        if not os.path.exists(self.config_file):
            print(f"{Colors.YELLOW}[!] Config not found. Using defaults.{Colors.ENDC}")
            return
        
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
                self.excluded_rules = config.get("excluded_rules", {})
                self.component_mapping = config.get("component_mapping", {})
                
                # Load remediation configuration / โหลดการตั้งค่าการแก้ไข
                self.remediation_config = config.get("remediation_config", {})
                self.remediation_global_config = self.remediation_config.get("global", {})
                self.remediation_checks_config = self.remediation_config.get("checks", {})
                self.remediation_env_vars = self.remediation_config.get("environment_overrides", {})
                
                # Load API timeout settings from global config
                self.wait_for_api_enabled = self.remediation_global_config.get("wait_for_api", True)
                self.api_check_interval = self.remediation_global_config.get("api_check_interval", 5)
                self.api_max_retries = self.remediation_global_config.get("api_max_retries", 60)
                
                if self.verbose >= 1:
                    print(f"{Colors.BLUE}[DEBUG] Loaded remediation config for {len(self.remediation_checks_config)} checks{Colors.ENDC}")
                    print(f"{Colors.BLUE}[DEBUG] API timeout settings: interval={self.api_check_interval}s, max_retries={self.api_max_retries}{Colors.ENDC}")
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}[!] Config parse error: {e}{Colors.ENDC}")
        except Exception as e:
            print(f"{Colors.RED}[!] Config load error: {e}{Colors.ENDC}")

    def is_rule_excluded(self, rule_id):
        """Check if rule is excluded / ตรวจสอบว่ากฎถูกยกเว้นหรือไม่"""
        return rule_id in self.excluded_rules

    def get_component_for_rule(self, rule_id):
        """Get component category for a rule / ได้รับหมวดหมู่ส่วนประกอบสำหรับกฎ"""
        for component, rules in self.component_mapping.items():
            if rule_id in rules:
                return component
        return "Other"

    def get_remediation_config_for_check(self, check_id):
        """Get remediation configuration for a specific check / ได้รับการตั้งค่าการแก้ไขสำหรับการตรวจสอบเฉพาะ"""
        if check_id in self.remediation_checks_config:
            return self.remediation_checks_config[check_id]
        return {}

    def log_activity(self, action, details=None):
        """Log activities to file / บันทึกกิจกรรมลงไฟล์"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {action}"
        if details:
            log_entry += f" - {details}"
        
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + "\n")
        except Exception as e:
            if self.verbose >= 2:
                print(f"{Colors.RED}[DEBUG] Logging error: {e}{Colors.ENDC}")

    def check_dependencies(self):
        """Verify required tools are installed / ตรวจสอบว่าเครื่องมือที่จำเป็นได้ถูกติดตั้ง"""
        missing = [tool for tool in REQUIRED_TOOLS if shutil.which(tool) is None]
        
        if missing:
            print(f"{Colors.RED}[-] Missing: {', '.join(missing)}{Colors.ENDC}")
            sys.exit(1)

    def detect_node_role(self):
        """Detect current node role by inspecting labels / ตรวจจับบทบาทโหนดจากป้ายกำกับ"""
        hostname = socket.gethostname()
        kubectl = self.get_kubectl_cmd()

        try:
            result = subprocess.run(
                kubectl + ["get", "node", hostname, "--no-headers", "-o", "jsonpath={.metadata.labels}"],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode != 0:
                return None

            labels = result.stdout.lower()
            if not labels:
                return None

            if "control-plane" in labels or "master" in labels:
                return "master"
            return "worker"
        except Exception:
            return None

    def get_kubectl_cmd(self):
        """
        Detect kubeconfig and return kubectl command
        ตรวจจับ kubeconfig และส่งกลับคำสั่ง kubectl
        """
        kubeconfig_paths = [
            os.environ.get('KUBECONFIG'),
            "/etc/kubernetes/admin.conf",
            os.path.expanduser("~/.kube/config"),
            f"/home/{os.environ.get('SUDO_USER', '')}/.kube/config"
        ]
        
        for config_path in kubeconfig_paths:
            if config_path and os.path.exists(config_path):
                if self.verbose >= 2:
                    print(f"{Colors.BLUE}[DEBUG] Using Kubeconfig: {config_path}{Colors.ENDC}")
                return ["kubectl", "--kubeconfig", config_path]
        
        return ["kubectl"]

    def check_health(self):
        """
        Check Kubernetes cluster health
        ตรวจสอบสุขภาพของคลัสเตอร์ Kubernetes
        """
        print(f"{Colors.CYAN}[*] Checking Cluster Health...{Colors.ENDC}")
        admin_conf = "/etc/kubernetes/admin.conf"

        if os.path.exists(admin_conf):
            kubectl = self.get_kubectl_cmd()

            try:
                # Check nodes / ตรวจสอบโหนด
                nodes_result = subprocess.run(
                    kubectl + ["get", "nodes"],
                    capture_output=True, text=True, timeout=10
                )
            
                if nodes_result.returncode != 0:
                    self.health_status = "CRITICAL (Nodes Unreachable)"
                    print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
                    return self.health_status
                
                # Check pod status / ตรวจสอบสถานะพอด
                pods_result = subprocess.run(
                    kubectl + ["get", "pods", "-n", "kube-system", 
                              "--field-selector", "status.phase!=Running"],
                    capture_output=True, text=True, timeout=10
                )
                
                unhealthy_pods = [
                    line for line in pods_result.stdout.split('\n')
                    if line.strip() and "NAME" not in line
                ]
                
                if unhealthy_pods:
                    self.health_status = f"WARNING ({len(unhealthy_pods)} Unhealthy Pods)"
                    print(f"{Colors.YELLOW}    -> {self.health_status}{Colors.ENDC}")
                else:
                    self.health_status = "OK (Healthy)"
                    print(f"{Colors.GREEN}    -> {self.health_status}{Colors.ENDC}")
                
            except subprocess.TimeoutExpired:
                self.health_status = "ERROR (Timeout)"
                print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
            except Exception as e:
                self.health_status = f"ERROR ({str(e)})"
                print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
        else:
            try:
                kubelet = subprocess.run(
                    ["systemctl", "is-active", "kubelet"],
                    capture_output=True, text=True, timeout=10
                )
                if kubelet.returncode == 0 and kubelet.stdout.strip() == "active":
                    self.health_status = "OK (Worker Kubelet Running)"
                    print(f"{Colors.GREEN}    -> {self.health_status}{Colors.ENDC}")
                else:
                    self.health_status = "CRITICAL (Kubelet Down)"
                    print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
            except subprocess.TimeoutExpired:
                self.health_status = "ERROR (Timeout)"
                print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")
            except Exception as e:
                self.health_status = f"ERROR ({str(e)})"
                print(f"{Colors.RED}    -> {self.health_status}{Colors.ENDC}")

        return self.health_status

    def wait_for_healthy_cluster(self):
        """
        Wait for cluster to be healthy after API server restart
        Uses configuration from cis_config.json for timeout settings
        
        Master Node: Checks kubectl get nodes (API server availability)
        Worker Node: Checks systemctl is-active kubelet (kubelet service health)
        
        Returns True if cluster/node is healthy within timeout, False otherwise
        """
        if not self.wait_for_api_enabled:
            if self.verbose >= 1:
                print(f"{Colors.CYAN}[*] API health check disabled in config.{Colors.ENDC}")
            return True
        
        admin_conf = "/etc/kubernetes/admin.conf"
        total_timeout = self.api_check_interval * self.api_max_retries
        
        # --- WORKER NODE LOGIC ---
        # If admin.conf doesn't exist, this is a Worker Node
        if not os.path.exists(admin_conf):
            print(f"{Colors.YELLOW}[*] Worker Node detected. Checking kubelet health...{Colors.ENDC}")
            
            try:
                kubelet_result = subprocess.run(
                    ["systemctl", "is-active", "kubelet"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                kubelet_status = kubelet_result.stdout.strip()
                
                # If kubelet is active, Worker Node is healthy
                if kubelet_result.returncode == 0 and kubelet_status == "active":
                    self.health_status = "OK (Worker Kubelet Running)"
                    print(f"{Colors.GREEN}    [OK] Worker kubelet is active.{Colors.ENDC}")
                    return True
                else:
                    # kubelet is inactive or failed
                    self.health_status = "CRITICAL (Kubelet Not Active)"
                    print(f"{Colors.RED}    [FAIL] Worker kubelet is {kubelet_status or 'not responding'}.{Colors.ENDC}")
                    return False
            
            except subprocess.TimeoutExpired:
                self.health_status = "CRITICAL (Kubelet Check Timeout)"
                print(f"{Colors.RED}    [FAIL] Kubelet health check timed out.{Colors.ENDC}")
                return False
            except Exception as e:
                self.health_status = f"CRITICAL (Kubelet Check Error: {str(e)})"
                print(f"{Colors.RED}    [FAIL] Error checking kubelet: {str(e)}{Colors.ENDC}")
                return False
        
        # --- MASTER NODE LOGIC ---
        # If admin.conf exists, this is a Master Node
        print(f"{Colors.YELLOW}[*] Master Node detected. Waiting for cluster health (Timeout: {total_timeout}s, Interval: {self.api_check_interval}s)...{Colors.ENDC}")
        
        kubectl = self.get_kubectl_cmd()
        count = 0
        
        while count < self.api_max_retries:
            try:
                # Simple nodes check - indicates API server is responsive
                nodes_result = subprocess.run(
                    kubectl + ["get", "nodes"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if nodes_result.returncode == 0:
                    elapsed = count * self.api_check_interval
                    print(f"{Colors.GREEN}    [OK] Cluster is online. (Attempt {count+1}/{self.api_max_retries}, {elapsed}s){Colors.ENDC}")
                    self.health_status = "OK (Healthy)"
                    return True
                
            except subprocess.TimeoutExpired:
                pass
            except Exception:
                pass
            
            elapsed = count * self.api_check_interval
            print(f"{Colors.YELLOW}    [WAIT] Cluster not ready... (Attempt {count+1}/{self.api_max_retries}, {elapsed}s){Colors.ENDC}")
            time.sleep(self.api_check_interval)
            count += 1

        print(f"{Colors.RED}    [FAIL] Cluster did not recover within {total_timeout} seconds.{Colors.ENDC}")
        self.health_status = "CRITICAL (Recovery Timeout)"
        return False

    def extract_metadata_from_script(self, script_path):
        """
        Extract title from script file header
        แยกชื่อเรื่องจากส่วนหัวไฟล์สคริปต์
        """
        if not script_path or not os.path.exists(script_path):
            return "Title not found"
        
        try:
            with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                # Read first 30 lines / อ่านบรรทัดแรก 30 บรรทัด
                lines = f.readlines()[:30]
            
            for line in lines:
                line = line.strip()
                if not line.startswith("#"):
                    continue
                
                # Look for "Title:" tag / มองหาแท็ก "Title:"
                if "Title:" in line:
                    return line.split("Title:", 1)[1].strip()
                
                # Look for common patterns / มองหารูปแบบทั่วไป
                clean = line.lstrip("#").strip()
                prefixes = ["Ensure", "Enable", "Disable", "Configure", "Restrict"]
                if any(clean.startswith(p) for p in prefixes):
                    if 10 < len(clean) < 150:
                        return clean
        except Exception:
            pass
        
        return "Title not found"

    def get_scripts(self, mode, target_level, target_role):
        """
        Get list of audit/remediation scripts
        ได้รับรายชื่อสคริปต์ตรวจสอบ/การแก้ไข
        """
        suffix = "_remediate.sh" if mode == "remediate" else "_audit.sh"
        scripts = []
        
        # Determine levels to scan / กำหนดระดับที่จะสแกน
        levels = ['1', '2'] if target_level == "all" else [target_level]
        roles = ['Master', 'Worker'] if target_role == "all" else [target_role.capitalize()]
        
        for role in roles:
            for level in levels:
                dir_path = os.path.join(self.base_dir, f"Level_{level}_{role}_Node")
                
                if not os.path.isdir(dir_path):
                    continue
                
                for filename in sorted(os.listdir(dir_path)):
                    if not filename.endswith(suffix):
                        continue
                    
                    scripts.append({
                        "path": os.path.join(dir_path, filename),
                        "id": filename.replace(suffix, ""),
                        "role": role.lower(),
                        "name": filename,
                        "level": level
                    })
        
        return scripts

    def run_script(self, script, mode):
        """
        Execute audit/remediation script with error handling
        ดำเนินการสคริปต์ตรวจสอบ/การแก้ไขพร้อมการจัดการข้อผิดพลาด
        """
        if self.stop_requested:
            return None
        
        start_time = time.time()
        script_id = script["id"]
        
        # Check if rule is excluded / ตรวจสอบว่ากฎถูกยกเว้นหรือไม่
        if self.is_rule_excluded(script_id):
            return self._create_result(
                script, "IGNORED",
                f"Excluded: {self.excluded_rules.get(script_id, 'No reason')}",
                time.time() - start_time
            )
        
        try:
            # Check remediation config for skipping / ตรวจสอบการตั้งค่าการแก้ไขเพื่อข้ามไป
            if mode == "remediate":
                remediation_cfg = self.get_remediation_config_for_check(script_id)
                if remediation_cfg.get("skip", False) or not remediation_cfg.get("enabled", True):
                    return self._create_result(
                        script, "SKIPPED",
                        f"Skipped by remediation config",
                        time.time() - start_time
                    )
            
            # Check if manual check / ตรวจสอบว่าเป็นการตรวจสอบด้วยตนเองหรือไม่
            is_manual = self._is_manual_check(script["path"])
            
            if is_manual and self.skip_manual and mode == "audit":
                return self._create_result(
                    script, "SKIPPED",
                    "Manual check skipped by user",
                    time.time() - start_time
                )
            
            # For remediation scripts, wait for cluster to be healthy
            # This handles cases where a previous remediation restarted the API server
            if mode == "remediate":
                if not self.wait_for_healthy_cluster():
                    # EMERGENCY STOP: Cluster failure detected during remediation
                    # Continuing would cause cascading failures
                    error_msg = (
                        f"\n{Colors.RED}{'='*70}\n"
                        f"[CRITICAL] EMERGENCY STOP: Cluster Unavailable\n"
                        f"{'='*70}\n"
                        f"Status: {self.health_status}\n"
                        f"Failed Check: {script_id}\n"
                        f"Time to Failure: {round(time.time() - start_time, 2)}s\n\n"
                        f"Remediation loop aborted to prevent cascading failures.\n"
                        f"Manual intervention required:\n"
                        f"  1. Verify cluster health: kubectl get nodes\n"
                        f"  2. Check API server status: kubectl get pods -n kube-system\n"
                        f"  3. Review logs: journalctl -u kubelet -n 100\n"
                        f"  4. Restore from backup if needed: /var/backups/cis-remediation/\n"
                        f"{'='*70}{Colors.ENDC}\n"
                    )
                    print(error_msg)
                    self.log_activity("REMEDIATION_EMERGENCY_STOP", f"Cluster unavailable at check {script_id}")
                    sys.exit(1)
            
            # Prepare environment variables for remediation scripts / เตรียมตัวแปรสภาพแวดล้อมสำหรับสคริปต์การแก้ไข
            env = os.environ.copy()
            
            if mode == "remediate":
                # Add global remediation config / เพิ่มการตั้งค่าการแก้ไขแบบโลก
                env.update({
                    "BACKUP_ENABLED": str(self.remediation_global_config.get("backup_enabled", True)).lower(),
                    "BACKUP_DIR": self.remediation_global_config.get("backup_dir", "/var/backups/cis-remediation"),
                    "DRY_RUN": str(self.remediation_global_config.get("dry_run", False)).lower(),
                    "WAIT_FOR_API": str(self.wait_for_api_enabled).lower(),
                    "API_CHECK_INTERVAL": str(self.api_check_interval),
                    "API_MAX_RETRIES": str(self.api_max_retries)
                })
                
                # Add check-specific remediation config / เพิ่มการตั้งค่าการแก้ไขเฉพาะการตรวจสอบ
                remediation_cfg = self.get_remediation_config_for_check(script_id)
                if remediation_cfg:
                    # Convert config to environment variables (uppercase, prefixed with CONFIG_) / แปลงการตั้งค่าเป็นตัวแปรสภาพแวดล้อม
                    for key, value in remediation_cfg.items():
                        if key in ['skip', 'enabled']:
                            # Skip metadata keys / ข้ามคีย์ข้อมูลเมตา
                            continue
                        
                        env_key = f"CONFIG_{key.upper()}"
                        if isinstance(value, (dict, list)):
                            # Pass complex objects as JSON strings / ส่งอบเจ็กต์ที่ซับซ้อนเป็นสตริง JSON
                            env[env_key] = json.dumps(value)
                        else:
                            # Simple values as strings / ค่าง่าย ๆ เป็นสตริง
                            env[env_key] = str(value)
                
                # Add global environment overrides / เพิ่มการแทนที่สภาพแวดล้อมแบบโลก
                env.update(self.remediation_env_vars)
                
                if self.verbose >= 2:
                    print(f"{Colors.BLUE}[DEBUG] Environment variables for {script_id}:{Colors.ENDC}")
                    for k, v in sorted(env.items()):
                        if k.startswith("CONFIG_") or k.startswith("BACKUP_") or k.startswith("DRY_RUN") or k.startswith("WAIT_") or k.startswith("API_"):
                            # Truncate long JSON values / ตัดคีย์ JSON ที่ยาว
                            display_val = v if len(v) < 80 else v[:77] + "..."
                            print(f"{Colors.BLUE}      {k}={display_val}{Colors.ENDC}")
            
            # Run script / รันสคริปต์
            result = subprocess.run(
                ["bash", script["path"]],
                capture_output=True,
                text=True,
                timeout=self.script_timeout,
                env=env
            )
            
            duration = round(time.time() - start_time, 2)
            
            # Parse output / แยกวิเคราะห์ผลลัพธ์
            status, reason, fix_hint, cmds = self._parse_script_output(
                result, script_id, mode, is_manual
            )
            
            return {
                "id": script_id,
                "role": script["role"],
                "level": script["level"],
                "status": status,
                "duration": duration,
                "reason": reason,
                "fix_hint": fix_hint,
                "cmds": cmds,
                "output": result.stdout + result.stderr,
                "path": script["path"],
                "component": self.get_component_for_rule(script_id)
            }
        
        except subprocess.TimeoutExpired:
            return self._create_result(
                script, "ERROR",
                f"Script timeout after {self.script_timeout}s",
                time.time() - start_time
            )
        except FileNotFoundError:
            return self._create_result(
                script, "ERROR",
                f"Script not found: {script['path']}",
                time.time() - start_time
            )
        except PermissionError:
            return self._create_result(
                script, "ERROR",
                "Permission denied executing script",
                time.time() - start_time
            )
        except Exception as e:
            return self._create_result(
                script, "ERROR",
                f"Unexpected error: {str(e)}",
                time.time() - start_time
            )

    def _is_manual_check(self, script_path):
        """Check if script is marked as manual / ตรวจสอบว่าสคริปต์ถูกทำเครื่องหมายเป็นด้วยตนเองหรือไม่"""
        try:
            with open(script_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f.readlines()[:10]:
                    if "# Title:" in line and "(Manual)" in line:
                        return True
        except Exception:
            pass
        return False

    def _parse_script_output(self, result, script_id, mode, is_manual):
        """
        Parse structured output from script
        แยกวิเคราะห์ผลลัพธ์ที่มีโครงสร้างจากสคริปต์
        """
        status = "FAIL"
        reason = ""
        fix_hint = ""
        cmds = []
        
        # Parse structured tags / แยกแท็กที่มีโครงสร้าง
        for line in result.stdout.split('\n'):
            if "[FAIL_REASON]" in line:
                reason = line.split("[FAIL_REASON]", 1)[1].strip()
            elif "[FIX_HINT]" in line:
                fix_hint = line.split("[FIX_HINT]", 1)[1].strip()
            elif "[CMD]" in line:
                cmds.append(line.split("[CMD]", 1)[1].strip())
        
        # Determine status / กำหนดสถานะ
        if mode == "remediate":
            if result.returncode == 0:
                # Check if it was actually a manual warning, not a real fix
                if "Manual intervention required" in result.stdout or "Manual check" in result.stdout:
                    status = "MANUAL"
                else:
                    status = "PASS"
            else:
                status = "FAIL"
        else:
            if is_manual:
                status = "MANUAL"
            elif result.returncode == 0:
                status = "PASS"
            else:
                status = "FAIL"
                if not reason:
                    # Fallback to last line / ใช้บรรทัดสุดท้ายเป็นทางเลือก
                    lines = result.stdout.split('\n')
                    reason = next((l for l in lines if l.strip()), "Check failed")
        
        # Generate default fix hint / สร้างคำแนะนำการแก้ไขเริ่มต้น
        if status == "FAIL" and not fix_hint:
            remediate_path = result.stdout.replace("audit", "remediate")
            if os.path.exists(remediate_path):
                fix_hint = f"Run: sudo bash {remediate_path}"
        
        return status, reason, fix_hint, cmds

    def _create_result(self, script, status, reason, duration):
        """Create result dictionary / สร้างพจนานุกรมผลลัพธ์"""
        return {
            "id": script["id"],
            "role": script["role"],
            "level": script["level"],
            "status": status,
            "duration": round(duration, 2),
            "reason": reason,
            "fix_hint": "",
            "cmds": [],
            "output": "",
            "path": script["path"],
            "component": self.get_component_for_rule(script["id"])
        }

    def update_stats(self, result):
        """Update statistics based on result / อัปเดตสถิติตามผลลัพธ์"""
        if not result:
            return
        
        role = "master" if "master" in result["role"] else "worker"
        status = result["status"].lower()
        
        if status not in self.stats[role]:
            return
        
        self.stats[role][status] += 1
        self.stats[role]["total"] += 1

    def perform_backup(self):
        """
        Create backup of critical Kubernetes configs
        สร้างสำรองข้อมูลของการตั้งค่า Kubernetes ที่สำคัญ
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = os.path.join(self.backup_dir, f"backup_{timestamp}")
        os.makedirs(backup_path, exist_ok=True)
        
        print(f"\n{Colors.CYAN}[*] Creating Backup...{Colors.ENDC}")
        
        targets = ["/etc/kubernetes/manifests", "/var/lib/kubelet/config.yaml"]
        
        for target in targets:
            if not os.path.exists(target):
                continue
            
            try:
                name = os.path.basename(target)
                if os.path.isdir(target):
                    shutil.copytree(target, os.path.join(backup_path, name))
                else:
                    shutil.copy2(target, backup_path)
            except Exception as e:
                print(f"{Colors.RED}[!] Backup error {target}: {e}{Colors.ENDC}")
        
        print(f"   -> Saved to: {backup_path}")

    def scan(self, target_level, target_role, skip_menu=False):
        """
        Execute audit scan with parallel execution
        ดำเนินการสแกนการตรวจสอบพร้อมการดำเนินการแบบขนาน
        
        Args:
            target_level: CIS level to audit ("1", "2", or "all")
            target_role: Target node role ("master", "worker", or "all")
            skip_menu: If True, skip results menu (used when in "Both" mode)
        """
        print(f"\n{Colors.CYAN}[*] Starting Audit Scan...{Colors.ENDC}")
        self.log_activity("AUDIT_START", 
                         f"Level:{target_level}, Role:{target_role}, Timeout:{self.script_timeout}s")
        
        self._prepare_report_dir("audit")
        scripts = self.get_scripts("audit", target_level, target_role)
        self.results = []
        self._init_stats()
        
        # Execute scripts in parallel / ดำเนินการสคริปต์แบบขนาน
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            self._run_scripts_parallel(executor, scripts, "audit")
        
        print(f"\n{Colors.GREEN}[+] Audit Complete.{Colors.ENDC}")
        self.save_reports("audit")
        self.print_stats_summary()
        
        # Trend analysis / การวิเคราะห์แนวโน้ม
        current_score = self.calculate_score(self.stats)
        previous = self.get_previous_snapshot("audit", target_role, target_level)
        if previous:
            self.show_trend_analysis(current_score, previous)
        
        self.save_snapshot("audit", target_role, target_level)
        
        # Show results menu only if not skipped (e.g., in "Both" mode)
        if not skip_menu:
            self.show_results_menu("audit")
        else:
            print(f"\n{Colors.CYAN}[*] Audit Complete. Proceeding to Remediation phase...{Colors.ENDC}")

    def _run_scripts_parallel(self, executor, scripts, mode):
        """
        Run scripts in parallel with progress tracking
        รันสคริปต์แบบขนานพร้อมการติดตามความคืบหน้า
        """
        futures = {executor.submit(self.run_script, s, mode): s for s in scripts}
        
        try:
            completed = 0
            for future in as_completed(futures):
                if self.stop_requested:
                    break
                
                result = future.result()
                if result:
                    self.results.append(result)
                    self.update_stats(result)
                    completed += 1
                    
                    # Show progress / แสดงความคืบหน้า
                    progress_pct = (completed / len(scripts)) * 100
                    self._print_progress(result, completed, len(scripts), progress_pct)
        
        except KeyboardInterrupt:
            self.stop_requested = True
            print("\n[!] Aborted.")

    def _print_progress(self, result, completed, total, percentage):
        """Print progress line / พิมพ์บรรทัดความคืบหน้า"""
        if self.verbose > 0:
            self.show_verbose_result(result)
            return
        
        status_color = {
            "PASS": Colors.GREEN,
            "FAIL": Colors.RED,
            "MANUAL": Colors.YELLOW,
            "SKIPPED": Colors.CYAN,
            "FIXED": Colors.GREEN,
            "ERROR": Colors.RED
        }
        
        color = status_color.get(result['status'], Colors.WHITE)
        print(f"   [{percentage:5.1f}%] [{completed}/{total}] {result['id']} -> {color}{result['status']}{Colors.ENDC}")

    def fix(self, target_level, target_role):
        """
        Execute remediation with cluster health check
        ดำเนินการแก้ไขพร้อมการตรวจสอบสุขภาพคลัสเตอร์
        """
        # Prevent remediation if cluster is critical / ป้องกันการแก้ไขหากคลัสเตอร์อยู่ในสถานะวิกฤติ
        if "CRITICAL" in self.health_status:
            print(f"{Colors.RED}[-] Cannot remediate: Cluster health is CRITICAL.{Colors.ENDC}")
            self.log_activity("FIX_SKIPPED", "Cluster health critical")
            return
        
        self._prepare_report_dir("remediation")
        self.log_activity("FIX_START", f"Level:{target_level}, Role:{target_role}")
        self.perform_backup()
        
        print(f"\n{Colors.YELLOW}[*] Starting Remediation...{Colors.ENDC}")
        scripts = self.get_scripts("remediate", target_level, target_role)
        self.results = []
        self._init_stats()
        
        # Execute remediation scripts in parallel / ดำเนินการสคริปต์แก้ไขแบบขนาน
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            self._run_scripts_parallel(executor, scripts, "remediate")
        
        print(f"\n{Colors.GREEN}[+] Remediation Complete.{Colors.ENDC}")
        self.save_reports("remediate")
        self.print_stats_summary()
        
        # Trend analysis / การวิเคราะห์แนวโน้ม
        current_score = self.calculate_score(self.stats)
        previous = self.get_previous_snapshot("remediate", target_role, target_level)
        if previous:
            self.show_trend_analysis(current_score, previous)
        
        self.save_snapshot("remediate", target_role, target_level)
        self.show_results_menu("remediate")

    def _init_stats(self):
        """Initialize statistics dictionary / เริ่มต้นพจนานุกรมสถิติ"""
        self.stats = {
            "master": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0},
            "worker": {"pass": 0, "fail": 0, "manual": 0, "skipped": 0, "error": 0, "total": 0}
        }

    def _prepare_report_dir(self, mode):
        """
        Create report directory with Oracle-style structure
        สร้างไดเรกทอรีรายงานพร้อมโครงสร้างแบบ Oracle
        """
        run_folder = f"run_{self.timestamp}"
        self.current_report_dir = os.path.join(self.date_dir, mode, run_folder)
        os.makedirs(self.current_report_dir, exist_ok=True)

    def save_snapshot(self, mode, role, level):
        """Save results for trend comparison / บันทึกผลลัพธ์เพื่อเปรียบเทียบแนวโน้ม"""
        history_file = os.path.join(
            self.history_dir,
            f"snapshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{mode}_{role}_{level}.json"
        )
        
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
        except Exception as e:
            if self.verbose >= 2:
                print(f"{Colors.RED}[DEBUG] Snapshot error: {e}{Colors.ENDC}")

    def get_previous_snapshot(self, mode, role, level):
        """Retrieve most recent previous snapshot / ดึงข้อมูลสแนปชอตก่อนหน้าล่าสุด"""
        pattern = f"snapshot_*_{mode}_{role}_{level}.json"
        snapshots = sorted(
            glob.glob(os.path.join(self.history_dir, pattern)),
            reverse=True
        )
        
        if snapshots:
            try:
                with open(snapshots[0], 'r') as f:
                    return json.load(f)
            except Exception as e:
                if self.verbose >= 1:
                    print(f"{Colors.YELLOW}[!] Snapshot load error: {e}{Colors.ENDC}")
        
        return None

    def calculate_score(self, stats):
        """
        Calculate compliance percentage score
        คำนวณคะแนนเปอร์เซ็นต์การปฏิบัติตามข้อกำหนด
        Score = Pass / (Pass + Fail + Manual) * 100
        """
        total_master = stats["master"]["pass"] + stats["master"]["fail"] + stats["master"]["manual"]
        total_worker = stats["worker"]["pass"] + stats["worker"]["fail"] + stats["worker"]["manual"]
        total = total_master + total_worker
        
        if total == 0:
            return 0.0
        
        passed = stats["master"]["pass"] + stats["worker"]["pass"]
        return round((passed / total) * 100, 2)

    def show_trend_analysis(self, current_score, previous_snapshot):
        """Display score trend comparison / แสดงการเปรียบเทียบแนวโน้มคะแนน"""
        previous_stats = previous_snapshot.get("stats", {})
        previous_score = self.calculate_score(previous_stats)
        trend = current_score - previous_score
        
        trend_symbol = "📈" if trend > 0 else ("📉" if trend < 0 else "➡️")
        trend_color = Colors.GREEN if trend > 0 else (Colors.RED if trend < 0 else Colors.YELLOW)
        
        print(f"\n{Colors.CYAN}{'='*70}")
        print(f"TREND ANALYSIS (Score Comparison)")
        print(f"{'='*70}{Colors.ENDC}")
        print(f"  Current Score:   {Colors.BOLD}{current_score}%{Colors.ENDC}")
        print(f"  Previous Score:  {Colors.BOLD}{previous_score}%{Colors.ENDC}")
        print(f"  Change:          {trend_color}{trend_symbol} {'+' if trend > 0 else ''}{trend:.2f}%{Colors.ENDC}")
        print(f"{Colors.CYAN}{'='*70}{Colors.ENDC}")

    def save_reports(self, mode):
        """
        Save all report formats (CSV, JSON, Text, HTML)
        บันทึกรูปแบบรายงานทั้งหมด (CSV, JSON, Text, HTML)
        """
        if not self.current_report_dir:
            raise ValueError("Report directory not set")
        
        # CSV report / รายงาน CSV
        self._save_csv_report()
        
        # Text reports / รายงานข้อความ
        self._save_text_reports(mode)
        
        # JSON report / รายงาน JSON
        self._save_json_report()
        
        # HTML report / รายงาน HTML
        self._save_html_report(mode)
        
        print(f"\n   [*] Reports saved to: {self.current_report_dir}")

    def _save_csv_report(self):
        """Save CSV report with structured data / บันทึกรายงาน CSV ด้วยข้อมูลที่มีโครงสร้าง"""
        if not self.current_report_dir:
            raise ValueError("Report directory not set")
        csv_file = os.path.join(self.current_report_dir, "report.csv")
        fieldnames = ["id", "role", "level", "status", "duration", "reason", "fix_hint", "component"]
        
        try:
            with open(csv_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction='ignore')
                writer.writeheader()
                writer.writerows(self.results)
        except Exception as e:
            if self.verbose >= 2:
                print(f"{Colors.RED}[DEBUG] CSV save error: {e}{Colors.ENDC}")

    def _save_text_reports(self, mode):
        """Save summary and detailed text reports / บันทึกรายงานข้อความสรุปและรายละเอียด"""
        if not self.current_report_dir:
            raise ValueError("Report directory not set")
        summary_file = os.path.join(self.current_report_dir, "summary.txt")
        failed_file = os.path.join(self.current_report_dir, "failed_items.txt")
        summary_file = os.path.join(self.current_report_dir, "summary.txt")
        failed_file = os.path.join(self.current_report_dir, "failed_items.txt")
        
        # Categorize results / จำแนกผลลัพธ์
        passed = [r for r in self.results if r['status'] in ['PASS', 'FIXED']]
        failed = [r for r in self.results if r['status'] in ['FAIL', 'ERROR']]
        manual = [r for r in self.results if r['status'] == 'MANUAL']
        skipped = [r for r in self.results if r['status'] == 'SKIPPED']
        
        # Summary / สรุป
        with open(summary_file, 'w') as f:
            total = len(self.results)
            score = (len(passed) / (len(passed) + len(failed) + len(manual)) * 100) if (len(passed) + len(failed) + len(manual)) > 0 else 0
            
            f.write(f"{'='*60}\n")
            f.write(f"CIS BENCHMARK SUMMARY - {mode.upper()}\n")
            f.write(f"Date: {datetime.now()}\n")
            f.write(f"{'='*60}\n\n")
            f.write(f"Total:    {total}\n")
            f.write(f"Pass:     {len(passed)}\n")
            f.write(f"Fail:     {len(failed)}\n")
            f.write(f"Manual:   {len(manual)}\n")
            f.write(f"Skipped:  {len(skipped)}\n")
            f.write(f"Score:    {score:.2f}%\n")
        
        # Failed/Manual/Skipped items / รายการที่ล้มเหลว/ด้วยตนเอง/ข้ามไป
        with open(failed_file, 'w') as f:
            f.write(f"DETAILED RESULTS ({mode.upper()})\n")
            f.write(f"{'='*60}\n\n")
            
            for item in failed + manual + skipped:
                title = self.extract_metadata_from_script(item.get('path'))
                f.write(f"CIS ID: {item['id']} [{item['status']}]\n")
                f.write(f"Title:  {title}\n")
                f.write(f"Role:   {item['role'].upper()}\n")
                if item.get('reason'):
                    f.write(f"Reason: {item['reason']}\n")
    def _save_json_report(self):
        """Save JSON report with full details / บันทึกรายงาน JSON ด้วยรายละเอียดเต็มรูปแบบ"""
        if not self.current_report_dir:
            raise ValueError("Report directory not set")
        json_file = os.path.join(self.current_report_dir, "report.json")
        
        try:
            with open(json_file, 'w') as f:
                json.dump({"stats": self.stats, "results": self.results}, f, indent=2)
        except Exception as e:
            if self.verbose >= 2:
                print(f"{Colors.RED}[DEBUG] JSON save error: {e}{Colors.ENDC}")

    def _save_html_report(self, mode):
        """Save HTML report with visualization / บันทึกรายงาน HTML พร้อมการแสดงภาพ"""
        if not self.current_report_dir:
            raise ValueError("Report directory not set")
        html_file = os.path.join(self.current_report_dir, "report.html")
        
        passed = len([r for r in self.results if r['status'] in ['PASS', 'FIXED']])
        failed = len([r for r in self.results if r['status'] in ['FAIL', 'ERROR']])
        manual = len([r for r in self.results if r['status'] == 'MANUAL'])
        total = len(self.results)
        score = (passed / (passed + failed + manual) * 100) if (passed + failed + manual) > 0 else 0
        
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>CIS Benchmark Report</title>
    <style>
        body {{ font-family: Arial; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }}
        h1 {{ color: #333; text-align: center; }}
        .stats {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 20px 0; }}
        .stat-box {{ padding: 15px; text-align: center; border-radius: 4px; }}
        .pass {{ background: #d4edda; color: #155724; }}
        .fail {{ background: #f8d7da; color: #721c24; }}
        .manual {{ background: #fff3cd; color: #856404; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th {{ background: #007bff; color: white; padding: 10px; }}
        td {{ padding: 10px; border-bottom: 1px solid #ddd; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>CIS Kubernetes Benchmark Report</h1>
        <p><strong>Mode:</strong> {mode.upper()} | <strong>Date:</strong> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        
        <div class="stats">
            <div class="stat-box pass"><div style="font-size: 24px; font-weight: bold;">{passed}</div>Passed</div>
            <div class="stat-box fail"><div style="font-size: 24px; font-weight: bold;">{failed}</div>Failed</div>
            <div class="stat-box manual"><div style="font-size: 24px; font-weight: bold;">{manual}</div>Manual</div>
            <div class="stat-box" style="background: #d1ecf1; color: #0c5460;"><div style="font-size: 24px; font-weight: bold;">{score:.1f}%</div>Score</div>
        </div>
        
        <table>
            <tr><th>CIS ID</th><th>Role</th><th>Status</th><th>Duration</th></tr>
            {''.join(f'<tr><td>{r["id"]}</td><td>{r["role"].upper()}</td><td>{r["status"]}</td><td>{r["duration"]}s</td></tr>' for r in self.results)}
        </table>
    </div>
</body>
</html>"""
        
        with open(html_file, 'w') as f:
            f.write(html_content)

    def print_stats_summary(self):
        """Display statistics in terminal / แสดงสถิติในเทอร์มินัล"""
        print(f"\n{Colors.CYAN}{'='*70}")
        print("STATISTICS SUMMARY")
        print(f"{'='*70}{Colors.ENDC}")
        
        for role in ["master", "worker"]:
            s = self.stats[role]
            if s['total'] == 0:
                continue
            
            success_rate = (s['pass'] * 100 // s['total']) if s['total'] > 0 else 0
            print(f"\n  {Colors.BOLD}{role.upper()}:{Colors.ENDC}")
            print(f"    Pass:    {s['pass']}")
            print(f"    Fail:    {s['fail']}")
            print(f"    Manual:  {Colors.YELLOW}{s['manual']}{Colors.ENDC}")
            print(f"    Skipped: {s['skipped']}")
            print(f"    Total:   {s['total']}")
            print(f"    Success: {success_rate}%")
        
        print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")

    def show_verbose_result(self, res):
        """Display detailed result output / แสดงผลลัพธ์รายละเอียด"""
        if self.verbose == 0:
            return
        
        title = self.extract_metadata_from_script(res.get('path'))
        if res['status'] in ['PASS', 'FIXED']:
            color = Colors.GREEN
        elif res['status'] == 'MANUAL':
            color = Colors.YELLOW
        else:
            color = Colors.RED
        
        print(f"\n{Colors.CYAN}{'='*70}")
        print(f"{color}[{res['status']}]{Colors.ENDC} {res['id']} - {title}")
        print(f"{'='*70}{Colors.ENDC}")
        
        if self.verbose >= 1:
            if res.get('reason'):
                print(f"  Reason: {res['reason']}")
            if res.get('fix_hint') and res['status'] == 'FAIL':
                print(f"  Fix:    {res['fix_hint']}")
        
        if self.verbose >= 2:
            print(f"\n  {Colors.YELLOW}[Output]{Colors.ENDC}")
            output = res.get('output', '').strip()
            print(output if output else "  (no output)")
        
        print()

    def show_menu(self):
        """Display main menu / แสดงเมนูหลัก"""
        print(f"\n{Colors.CYAN}{'='*70}")
        print("SELECT MODE")
        print(f"{'='*70}{Colors.ENDC}\n")
        print("  1) Audit only (non-destructive)")
        print("  2) Remediation only (DESTRUCTIVE)")
        print("  3) Both (Audit then Remediation)")
        print("  4) Health Check")
        print("  5) Help")
        print("  0) Exit\n")
        
        while True:
            choice = input(f"{Colors.BOLD}Choose [0-5]: {Colors.ENDC}").strip()
            if choice in ['0', '1', '2', '3', '4', '5']:
                return choice
            print(f"{Colors.RED}Invalid choice.{Colors.ENDC}")

    def get_audit_options(self):
        """Get user options for audit / ได้รับตัวเลือกของผู้ใช้สำหรับการตรวจสอบ"""
        print(f"\n{Colors.CYAN}AUDIT CONFIGURATION{Colors.ENDC}\n")
        
        # Role selection / การเลือกบทบาท
        detected_role = self.detect_node_role()
        if detected_role:
            print(f"{Colors.GREEN}[+] Detected Role: {detected_role.capitalize()}{Colors.ENDC}")
            role = detected_role
        else:
            print("  Kubernetes Role:")
            print("    1) Master only")
            print("    2) Worker only")
            print("    3) Both")
            role = {"1": "master", "2": "worker", "3": "all"}.get(
                input("\n  Select role [3]: ").strip() or "3", "all"
            )
        
        # Level selection / การเลือกระดับ
        print(f"\n  CIS Level:")
        print("    1) Level 1")
        print("    2) Level 2")
        print("    3) All")
        level = {"1": "1", "2": "2", "3": "all"}.get(
            input("\n  Select level [3]: ").strip() or "3", "all"
        )
        
        return level, role, self.verbose, False, SCRIPT_TIMEOUT

    def get_remediation_options(self):
        """Get user options for remediation / ได้รับตัวเลือกของผู้ใช้สำหรับการแก้ไข"""
        print(f"\n{Colors.RED}[!] WARNING: REMEDIATION WILL MODIFY YOUR CLUSTER!{Colors.ENDC}\n")
        
        # Role selection / การเลือกบทบาท
        detected_role = self.detect_node_role()
        if detected_role:
            print(f"{Colors.GREEN}[+] Detected Role: {detected_role.capitalize()}{Colors.ENDC}")
            role = detected_role
        else:
            print("  Kubernetes Role:")
            print("    1) Master only")
            print("    2) Worker only")
            print("    3) Both")
            role = {"1": "master", "2": "worker", "3": "all"}.get(
                input("\n  Select role [3]: ").strip() or "3", "all"
            )
        
        # Level selection / การเลือกระดับ
        print(f"\n  CIS Level:")
        print("    1) Level 1")
        print("    2) Level 2")
        print("    3) All")
        level = {"1": "1", "2": "2", "3": "all"}.get(
            input("\n  Select level [3]: ").strip() or "3", "all"
        )
        
        return level, role, SCRIPT_TIMEOUT

    def confirm_action(self, message):
        """Ask for user confirmation / ขอการยืนยันจากผู้ใช้"""
        while True:
            response = input(f"\n{message} [y/n]: ").strip().lower()
            if response in ['y', 'yes']:
                return True
            elif response in ['n', 'no']:
                return False
            print(f"{Colors.RED}Please enter 'y' or 'n'.{Colors.ENDC}")

    def show_results_menu(self, mode):
        """Show menu after scan/fix completion / แสดงเมนูหลังจากการสแกน/แก้ไขเสร็จสมบูรณ์"""
        if not self.current_report_dir:
            print(f"{Colors.RED}[!] No report directory available.{Colors.ENDC}")
            return
        
        while True:
            print(f"\n{Colors.CYAN}{'='*70}")
            print("RESULTS MENU")
            print(f"{'='*70}{Colors.ENDC}\n")
            print("  1) View summary")
            print("  2) View failed items")
            print("  3) View HTML report")
            print("  4) Return to main menu\n")
            
            choice = input(f"{Colors.BOLD}Choose [1-4]: {Colors.ENDC}").strip()
            
            if choice == '1':
                summary_file = os.path.join(self.current_report_dir, "summary.txt")
                if os.path.exists(summary_file):
                    with open(summary_file, 'r') as f:
                        print(f"\n{f.read()}")
            elif choice == '2':
                failed_file = os.path.join(self.current_report_dir, "failed_items.txt")
                if os.path.exists(failed_file):
                    with open(failed_file, 'r') as f:
                        print(f"\n{f.read()}")
            elif choice == '3':
                html_file = os.path.join(self.current_report_dir, "report.html")
                print(f"   HTML report: {html_file}")
            elif choice == '4':
                break

    def show_help(self):
        """Display help information / แสดงข้อมูลความช่วยเหลือ"""
        print(f"""
{Colors.CYAN}{'='*70}
CIS Kubernetes Benchmark - HELP
{'='*70}{Colors.ENDC}

{Colors.BOLD}[1] AUDIT{Colors.ENDC}
    Scan compliance checks (non-destructive)
    ตรวจสอบการปฏิบัติตามข้อกำหนด (ไม่ทำลาย)

{Colors.BOLD}[2] REMEDIATION{Colors.ENDC}
    Apply fixes to non-compliant items (MODIFIES CLUSTER)
    ใช้การแก้ไขเพื่อแก้ไขรายการที่ไม่สอดคล้อง (แก้ไขคลัสเตอร์)

{Colors.BOLD}[3] BOTH{Colors.ENDC}
    Run audit first, then remediation
    รันการตรวจสอบก่อน จากนั้นทำการแก้ไข

{Colors.BOLD}[4] HEALTH CHECK{Colors.ENDC}
    Check Kubernetes cluster status
    ตรวจสอบสถานะของคลัสเตอร์ Kubernetes

{Colors.CYAN}{'='*70}{Colors.ENDC}
""")

    def main_loop(self):
        """Main application loop / ลูปแอปพลิเคชันหลัก"""
        self.show_banner()
        self.check_health()
        
        while True:
            choice = self.show_menu()
            
            if choice == '1':  # Audit / การตรวจสอบ
                level, role, verbose, skip_manual, timeout = self.get_audit_options()
                self.verbose = verbose
                self.skip_manual = skip_manual
                self.script_timeout = timeout
                self.log_activity("AUDIT", f"Level:{level}, Role:{role}")
                self.scan(level, role)
                
            elif choice == '2':  # Remediation / การแก้ไข
                level, role, timeout = self.get_remediation_options()
                self.script_timeout = timeout
                
                if self.confirm_action("Confirm remediation?"):
                    self.log_activity("FIX", f"Level:{level}, Role:{role}")
                    self.fix(level, role)
                    
            elif choice == '3':  # Both / ทั้งสอง
                level, role, verbose, skip_manual, timeout = self.get_audit_options()
                self.verbose = verbose
                self.script_timeout = timeout
                self.log_activity("AUDIT_THEN_FIX", f"Level:{level}, Role:{role}")
                self.scan(level, role, skip_menu=True)
                
                if self.confirm_action("Proceed to remediation?"):
                    self.fix(level, role)
                    
            elif choice == '4':  # Health check / ตรวจสอบสุขภาพ
                self.log_activity("HEALTH_CHECK", "Initiated")
                self.check_health()
                
            elif choice == '5':  # Help / ความช่วยเหลือ
                self.show_help()
                
            elif choice == '0':  # Exit / ออก
                self.log_activity("EXIT", "Application terminated")
                print(f"\n{Colors.CYAN}Goodbye!{Colors.ENDC}\n")
                sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="CIS Kubernetes Benchmark Runner"
    )
    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="Verbosity level (-v: detailed, -vv: debug)"
    )
    args = parser.parse_args()
    
    runner = CISUnifiedRunner(verbose=args.verbose)
    runner.main_loop()
