# CIS Kubernetes Hardening - Project Structure

## 📁 โครงสร้างโฟลเดอร์ (Organized)

```
cis-k8s-hardening/
│
├── 📁 Level_1_Master_Node/          ← CIS 1.x & 2.x Master Node checks
├── 📁 Level_1_Worker_Node/          ← CIS 4.x & 5.x Worker Node checks
├── 📁 Level_2_Master_Node/          ← Level 2 Master Node checks
├── 📁 Level_2_Worker_Node/          ← Level 2 Worker Node checks
│
├── 📁 scripts/                      ← All shell/bash scripts
│   ├── *_audit.sh
│   ├── *_remediate.sh
│   ├── *.sh (utilities)
│   └── *.ps1 (PowerShell)
│
├── 📁 tools/                        ← Python tools & utilities
│   ├── *.py (hardening tools)
│   ├── test_*.py
│   └── Unit Test/
│
├── 📁 docs/                         ← Documentation & references
│   ├── *.md (markdown docs)
│   ├── *.csv (CIS Benchmark reference)
│   ├── *.xlsx (CIS Benchmark spreadsheet)
│   └── IMPLEMENTATION_SUMMARY.md
│
├── 📁 config/                       ← Configuration files
│   ├── *.json (config files)
│   ├── *.yaml (k8s resources)
│   └── Dockerfile
│
├── 📁 logs/                         ← Log files (generated)
├── 📁 results/                      ← Audit results (generated)
├── 📁 temp/                         ← Temporary files
│
├── .git/                            ← Git repository
├── .gitignore
├── README.md                        ← Project README
└── __pycache__/                     ← Python cache (auto-generated)
```

---

## 🚀 Quick Start

### View Audit Scripts
```bash
ls -la Level_1_Worker_Node/4.1.*_audit.sh
```

### View Remediation Scripts
```bash
ls -la Level_1_Worker_Node/4.1.*_remediate.sh
```

### Run Audit
```bash
bash Level_1_Worker_Node/4.1.3_audit.sh
```

### Run Remediation
```bash
sudo bash Level_1_Worker_Node/4.1.3_remediate.sh
```

### View Tools
```bash
ls -la tools/*.py
```

### View Documentation
```bash
ls -la docs/*.md
```

---

## 📂 Directory Guide

| Folder | Purpose | Content |
|--------|---------|---------|
| **Level_1_Master_Node** | Master node checks (CIS 1.x, 2.x) | audit & remediate scripts |
| **Level_1_Worker_Node** | Worker node checks (CIS 4.x, 5.x) | audit & remediate scripts |
| **Level_2_Master_Node** | Level 2 master checks | audit & remediate scripts |
| **Level_2_Worker_Node** | Level 2 worker checks | audit & remediate scripts |
| **scripts** | Utility & main scripts | .sh, .ps1 files |
| **tools** | Python hardening tools | .py files, unit tests |
| **docs** | Documentation & references | .md, .csv, .xlsx |
| **config** | Configuration templates | .json, .yaml, Dockerfile |
| **logs** | Execution logs | Generated at runtime |
| **results** | Audit results | Generated at runtime |
| **temp** | Temporary files | Build artifacts, etc. |

---

## 🛠️ Key Scripts Location

### Main Executables (scripts/)
- `master_run_all.sh` - Run all master checks
- `worker_recovery.py` - Worker node recovery tool
- `harden_kubelet.py` - Kubelet hardening tool
- `safe_audit_remediation.sh` - Safe audit/remediation

### Tools (tools/)
- `harden_kubelet.py` - Advanced kubelet config
- `kubelet_config_manager.py` - Config management
- `enhance_audit_scripts.py` - Script enhancement
- `bulk_update_debug_info.py` - Bulk updates

### CIS Level Checks
- `Level_1_Master_Node/` - 1.x & 2.x master checks
- `Level_1_Worker_Node/` - 4.x & 5.x worker checks
- `Level_2_Master_Node/` - Level 2 master checks
- `Level_2_Worker_Node/` - Level 2 worker checks

---

## 📖 Documentation

All documentation is in `docs/`:

### Getting Started
- `QUICK_REFERENCE.md` - Quick reference guide
- `USAGE_GUIDE.md` - Detailed usage guide
- `HARDEN_KUBELET_QUICK_START.sh` - Quick start script

### Configuration & Implementation
- `CONFIG_DRIVEN_INTEGRATION_GUIDE.md` - Config guide
- `CONFIG_DRIVEN_REMEDIATION.md` - Remediation guide
- `IMPLEMENTATION_SUMMARY.md` - Implementation details

### Kubelet Hardening
- `PROTECT_KERNEL_DEFAULTS_FIX.md` - Kernel defaults fix
- `KUBELET_REMEDIATION_QUICK_REFERENCE.md` - Kubelet ref
- `HARDEN_KUBELET_USAGE.md` - Kubelet usage

### Other Resources
- `CIS_Kubernetes_Benchmark_V1.12.0_PDF.csv` - CIS Benchmark (CSV)
- `CIS_Kubernetes_Benchmark_V1.12.0_PDF.xlsx` - CIS Benchmark (Excel)

---

## ⚙️ Configuration Files (config/)

- `cis_config.json` - Main CIS configuration
- `cis_config_example.json` - Configuration example
- `Job.YAML` - Kubernetes Job resource
- `Dockerfile` - Docker image definition

---

## 🧪 Testing (tools/)

- `Unit Test/` - Unit test suite
- `test_logging.py` - Logging tests

---

## 🔧 Workflow

### 1. Audit
```bash
bash Level_1_Worker_Node/4.1.3_audit.sh
```

### 2. View Results
```bash
cat results/audit_results.txt
```

### 3. Remediate
```bash
sudo bash Level_1_Worker_Node/4.1.3_remediate.sh
```

### 4. Re-Audit to Verify
```bash
bash Level_1_Worker_Node/4.1.3_audit.sh
```

---

## 📝 Notes

- All scripts are organized by **CIS level and node type**
- **Level 1** = Basic security requirements
- **Level 2** = Advanced security requirements
- **Master Node** = Control plane components
- **Worker Node** = Kubelet, kube-proxy
- Scripts are **idempotent** (safe to run multiple times)

---

## 📞 Support

For specific checks, navigate to the appropriate directory:
- Master node checks: `Level_1_Master_Node/` or `Level_2_Master_Node/`
- Worker node checks: `Level_1_Worker_Node/` or `Level_2_Worker_Node/`
- Python tools: `tools/`
- Documentation: `docs/`

Happy hardening! 🔒
