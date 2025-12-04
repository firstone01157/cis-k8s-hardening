# CIS Kubernetes Hardening - Quick Reference

> **Kubernetes Security Hardening based on CIS Kubernetes Benchmark v1.12.0**  
> **เสริมความปลอดภัย Kubernetes ตาม CIS Benchmark**

---

## 🚀 Quick Start / เริ่มต้นอย่างรวดเร็ว

### How to Run / วิธีรัน

```bash
sudo python3 cis_k8s_unified.py
```

The script will:
- Auto-detect your node role (Master/Worker)
- Ask you to select CIS Level (1, 2, or All)
- Run compliance audit and show results

---

## 📊 Scoring System / ระบบการนับคะแนน

| Status | Description | Counted in Score |
|--------|-------------|------------------|
| **PASS** | ✓ Automated check passed | ✅ YES (counts as success) |
| **FAIL** | ✗ Automated check failed | ❌ NO (counts as failure) |
| **MANUAL** | ⚠ Requires human verification | ❌ NO (excluded from score) |
| **FIXED** | ✓ Issue was remediated | ✅ YES (counts as success) |
| **ERROR** | ✗ Script execution failed | ❌ NO (counts as failure) |

**Score Formula:**
```
Compliance Score = PASS / (PASS + FAIL + MANUAL)
```

**Key Points:**
- Only `PASS` and `FIXED` checks count toward your score
- `MANUAL` items are excluded (require human review before counting)
- Score = Fully Automated + Successfully Fixed / All Checks
- A `MANUAL` check will NOT inflate your compliance percentage

**Example:**
```
Pass:   50 items
Fail:   15 items
Manual: 25 items (need human review)

Score = 50 / (50 + 15 + 25) = 55.56%
NOT 50/65 = 76.92% (that would be inflated!)
```

---

## 🔧 Troubleshooting / การแก้ปัญหา

### Issue: Kubelet Service Failed / Kubelet พัง

**Error:** Kubelet is in failed state or won't restart

**Solution:**
```bash
# Reset failed state and restart
sudo systemctl reset-failed kubelet
sudo systemctl restart kubelet

# Verify status
sudo systemctl status kubelet
```

### Issue: Permission Denied
```bash
# Must run with sudo
sudo python3 cis_k8s_unified.py
```

### Issue: Auto-Detection Failed
If script prompts for node role on a Kubernetes node:

```bash
# Restart kubelet and retry
sudo systemctl restart kubelet
sudo python3 cis_k8s_unified.py
```

---

## 📁 Project Structure

```
cis-k8s-hardening/
├── cis_k8s_unified.py           # Main runner (USE THIS!)
├── Level_1_Master_Node/         # Master node checks
├── Level_1_Worker_Node/         # Worker node checks
├── Level_2_Master_Node/         # Advanced checks
├── Level_2_Worker_Node/         # Advanced checks
├── reports/                     # Generated reports
├── backups/                     # Backup files
├── logs/                        # Log files
└── README.md                    # This file
```

---

## 📝 Usage Modes / วิธีการใช้

```bash
sudo python3 cis_k8s_unified.py

# Then select:
#  1) Audit only (just check, no changes)
#  2) Remediation only (fix issues)
#  3) Both (audit, then fix)
#  4) Health Check (check cluster status)
#  5) Help (show help)
#  0) Exit
```

---

## 🎯 Common Workflows

### Audit Only (Safe - No Changes)
```bash
sudo python3 cis_k8s_unified.py
# Select: 1) Audit only
# ✓ Checks compliance without modifying anything
```

### Fix Issues (Destructive)
```bash
sudo python3 cis_k8s_unified.py
# Select: 2) Remediation only
# Confirm: y (to apply fixes)
# ✓ Backups are created automatically
```

### Full Workflow (Audit Then Fix)
```bash
sudo python3 cis_k8s_unified.py
# Select: 3) Both
# Step 1: Run audit (non-destructive)
# Step 2: Ask for confirmation
# Step 3: Apply fixes (with backups)
```

---

## ✨ Features / ฟีเจอร์

✅ **Auto-Detection:** Automatically detect node role (Master/Worker)  
✅ **Smart Scoring:** Only count fully automated checks (not MANUAL)  
✅ **Manual Awareness:** Clearly mark checks requiring human review  
✅ **Parallel Execution:** Run checks simultaneously (faster)  
✅ **Auto-Backup:** Create backups before remediation  
✅ **Color Output:** Easy-to-read results with colors  
✅ **Bilingual:** English + Thai (ไทย) support  

---

## 📊 Coverage

- **Master Node:** 55+ checks (CIS 1.x & 2.x)
- **Worker Node:** 47+ checks (CIS 4.x & 5.x)
- **Total:** 102+ checks

---

## ℹ️ Requirements

- **OS:** CentOS 7+, Ubuntu 18.04+, or similar Linux
- **Tools:** Python 3.6+, kubectl, jq, bash
- **Access:** sudo/root for remediation
- **Kubernetes:** v1.20+

---

## 📚 Additional Documentation

For detailed guides:
- `docs/USAGE_GUIDE.md` - Detailed usage guide
- `docs/PROJECT_STRUCTURE.md` - Project structure details
- `docs/` folder - Full documentation
- `MANUAL_STATUS_ENFORCEMENT.md` - Manual check details

---

*Last Updated: December 4, 2025*
