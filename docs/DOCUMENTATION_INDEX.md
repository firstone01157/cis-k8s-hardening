# Documentation Index | ดัชนีเอกสาร

> Quick reference to all documentation files

---

## 📄 Main Documentation

### README.md (START HERE / เริ่มที่นี่)
- Quick start guide
- Basic usage examples
- Installation instructions
- Key features overview

### DETAILED_GUIDE.md
- Advanced usage patterns
- Configuration details
- Troubleshooting guide
- Batch operations
- Integration examples
- Security best practices

### MANUAL_EXIT_CODE_UPDATE_GUIDE.md
- Exit code 3 standardization
- Batch update methods
- Rollback instructions
- Verification commands

---

## 🔧 Quick Reference Files

### Quick Commands
```bash
# Update manual exit codes
bash batch_update_manual_exit_codes.sh

# Run audit
python3 cis_k8s_unified.py

# Hardening kubelet
python3 harden_kubelet.py
```

---

## 📚 Documentation by Topic

### Getting Started
1. **README.md** - Start here
2. **Installation** - Setup instructions in README
3. **DETAILED_GUIDE.md** - Advanced setup

### Usage Guides
1. **README.md** - Quick examples
2. **DETAILED_GUIDE.md** - Advanced examples
3. **docs/USAGE_GUIDE.md** - Comprehensive guide

### Configuration
1. **README.md** - Basic config
2. **DETAILED_GUIDE.md** - Detailed config
3. **docs/CONFIG_DRIVEN_INTEGRATION_GUIDE.md** - Advanced config

### Troubleshooting
1. **README.md** - Common issues
2. **DETAILED_GUIDE.md** - Detailed troubleshooting

### Features
1. **MANUAL_EXIT_CODE_UPDATE_GUIDE.md** - Exit code 3 update
2. **docs/REFACTORING_QUICK_REFERENCE.md** - Refactoring info
3. **docs/VISUAL_GUIDE.md** - Visual examples

---

## 🗂️ File Structure

```
cis-k8s-hardening/
├── README.md                           ← START HERE
├── DETAILED_GUIDE.md                   ← Advanced features
├── MANUAL_EXIT_CODE_UPDATE_GUIDE.md    ← Exit code 3 guide
├── DOCUMENTATION_INDEX.md              ← This file
│
├── cis_k8s_unified.py                  ← Main runner
├── harden_kubelet.py                   ← Kubelet tool
│
├── Level_1_Master_Node/                ← Master checks
├── Level_1_Worker_Node/                ← Worker checks
├── Level_2_Master_Node/                ← Advanced master
├── Level_2_Worker_Node/                ← Advanced worker
│
├── config/
│   ├── cis_config.json                 ← Main config
│   ├── cis_config_example.json         ← Example config
│   ├── Dockerfile
│   └── Job.YAML
│
├── docs/
│   ├── USAGE_GUIDE.md
│   ├── CONFIG_DRIVEN_INTEGRATION_GUIDE.md
│   ├── PROJECT_STRUCTURE.md
│   ├── VISUAL_GUIDE.md
│   ├── REFACTORING_QUICK_REFERENCE.md
│   ├── QA_QUICK_REFERENCE.md
│   └── ... (30+ more docs)
│
├── logs/                               ← Execution logs
├── results/                            ← Audit results
└── backups/                            ← Backup files
```

---

## 🎯 Documentation by Use Case

### "I want to audit my Kubernetes cluster"
1. Read: **README.md** (Quick Start)
2. Run: `python3 cis_k8s_unified.py`
3. Select: Option 1 (Audit only)

### "I want to fix security issues"
1. Read: **README.md** (Important Notes)
2. Read: **DETAILED_GUIDE.md** (Configuration)
3. Run: `python3 cis_k8s_unified.py`
4. Select: Option 2 or 3 (Remediate or Both)

### "I want to update exit codes for manual checks"
1. Read: **MANUAL_EXIT_CODE_UPDATE_GUIDE.md**
2. Run: `bash batch_update_manual_exit_codes.sh`

### "I need advanced configuration"
1. Read: **DETAILED_GUIDE.md** (Configuration Details)
2. Edit: `config/cis_config.json`
3. Run: `python3 cis_k8s_unified.py`

### "Something is broken, help!"
1. Read: **README.md** (Troubleshooting)
2. Read: **DETAILED_GUIDE.md** (Troubleshooting)
3. Check: `docs/` folder for specific issues

### "I want to integrate with CI/CD"
1. Read: **DETAILED_GUIDE.md** (Integration with CI/CD)
2. Copy: Jenkins/K8s examples
3. Customize: For your environment

---

## 📖 Advanced Documentation (in docs/ folder)

| File | Purpose |
|------|---------|
| USAGE_GUIDE.md | Comprehensive usage guide |
| CONFIG_DRIVEN_INTEGRATION_GUIDE.md | Configuration guide |
| PROJECT_STRUCTURE.md | Full project structure |
| VISUAL_GUIDE.md | Visual examples |
| REFACTORING_QUICK_REFERENCE.md | Refactoring reference |
| QA_QUICK_REFERENCE.md | QA checklist |
| QUICK_REFERENCE.md | Command reference |
| ... | 30+ more documentation files |

---

## 🆕 Recent Updates (Dec 2025)

### New Features
1. **Exit Code 3 for Manual Checks**
   - Standardized exit code handling
   - `batch_update_manual_exit_codes.sh`
   - See: MANUAL_EXIT_CODE_UPDATE_GUIDE.md

2. **Simplified README**
   - Shortened for quick reference
   - Moved details to DETAILED_GUIDE.md
   - Added Thai translations

3. **Python Exit Code Support**
   - `cis_k8s_unified.py` recognizes exit code 3
   - Auto-categorizes manual checks
   - Integrated with statistics tracking

---

## 🔗 Cross-References

### Configuration
- Main: `config/cis_config.json`
- Example: `config/cis_config_example.json`
- Guide: **DETAILED_GUIDE.md** → Configuration Details
- Advanced: **docs/CONFIG_DRIVEN_INTEGRATION_GUIDE.md**

### Troubleshooting
- Quick: **README.md** → Troubleshooting
- Detailed: **DETAILED_GUIDE.md** → Troubleshooting
- Logs: Check `logs/` folder

### Commands
- Quick Start: **README.md**
- Advanced: **DETAILED_GUIDE.md**
- Quick Ref: **docs/QUICK_REFERENCE.md**

---

## 💡 Tips for Finding Information

### By Problem
- **Permission error** → README.md Troubleshooting
- **Config not loading** → DETAILED_GUIDE.md Configuration
- **Remediation failed** → DETAILED_GUIDE.md Troubleshooting
- **Need to update exit codes** → MANUAL_EXIT_CODE_UPDATE_GUIDE.md

### By Task
- **Quick audit** → README.md Quick Start
- **Deep dive audit** → docs/USAGE_GUIDE.md
- **Configure system** → DETAILED_GUIDE.md Configuration
- **Integrate with CI/CD** → DETAILED_GUIDE.md Integration
- **Batch operations** → DETAILED_GUIDE.md Batch Operations

### By Experience Level
- **Beginner** → README.md
- **Intermediate** → DETAILED_GUIDE.md
- **Advanced** → docs/ folder

---

## 📞 Support Resources

### Documentation
- **Quick answers** → README.md
- **How-to guides** → DETAILED_GUIDE.md
- **Detailed reference** → docs/ folder

### Troubleshooting
- **Common issues** → README.md
- **Advanced issues** → DETAILED_GUIDE.md
- **Specific problems** → docs/ folder

### Configuration
- **Quick config** → config/cis_config_example.json
- **Full config guide** → DETAILED_GUIDE.md
- **Advanced config** → docs/CONFIG_DRIVEN_INTEGRATION_GUIDE.md

---

*Last Updated: December 4, 2025*

