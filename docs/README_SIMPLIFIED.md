# CIS Kubernetes Hardening

> **Kubernetes Security Hardening based on CIS Kubernetes Benchmark v1.12.0**  
> **[TH]** ระบบเสริมความปลอดภัย Kubernetes ตาม CIS Benchmark v1.12.0

---

## 🚀 Quick Start

### For Master Node
```bash
# Interactive mode (recommended / แนะนำ)
python3 cis_k8s_unified.py

# Or run all checks
bash Level_1_Master_Node/*_audit.sh
```

### For Worker Node
```bash
# Check status
bash Level_1_Worker_Node/4.1.1_audit.sh

# Fix issue
sudo bash Level_1_Worker_Node/4.1.1_remediate.sh
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `cis_k8s_unified.py` | Main interactive runner |
| `Level_1_Master_Node/` | Master node checks |
| `Level_1_Worker_Node/` | Worker node checks |
| `config/cis_config.json` | Configuration |
| `docs/` | Full documentation |

---

## ✅ Coverage

- **Master Checks:** 55+ (CIS 1.x, 2.x)
- **Worker Checks:** 47+ (CIS 4.x, 5.x)  
- **Total:** 102+ checks

---

## 📖 Modes

| Mode | Purpose | คำสั่ง |
|------|---------|-------|
| **Audit** | ตรวจสอบปัญหา | Detect issues |
| **Remediate** | แก้ไขปัญหา | Fix issues |
| **Both** | ตรวจสอบและแก้ไข | Audit + Fix |
| **Health** | ตรวจสอบสถานะ | Check status |

---

## 🔧 Setup

```bash
# 1. Download
git clone <repo> cis-k8s-hardening && cd cis-k8s-hardening

# 2. Make executable
chmod +x *.sh *.py Level_*_*/*.sh

# 3. Run
python3 cis_k8s_unified.py
```

---

## 🆕 Latest (Dec 2025)

### Exit Code 3 for Manual Checks
```bash
# Auto-update all manual check scripts
bash batch_update_manual_exit_codes.sh
```

---

## 📚 Documentation

- **Full Guide:** `docs/USAGE_GUIDE.md`
- **Configuration:** `docs/CONFIG_DRIVEN_INTEGRATION_GUIDE.md`
- **Troubleshooting:** `docs/` folder
- **Manual Update Guide:** `MANUAL_EXIT_CODE_UPDATE_GUIDE.md`

---

## ⚠️ Important

- ✅ **Backup first** before remediation
- ✅ **Test on non-production** first
- ✅ Run with **`sudo`** for remediation scripts
- ✅ Use **`python3 cis_k8s_unified.py`** for safe execution

---

## 🤝 Support

For detailed troubleshooting and advanced features:
- See `docs/` folder
- Check `MANUAL_EXIT_CODE_UPDATE_GUIDE.md`
- Review `config/cis_config.json` examples

