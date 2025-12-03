# Quick Start Guide - CIS Kubernetes Benchmark Tool

## Installation

```bash
cd "CIS_Kubernetes_Benchmark_V1.12.0"
pip install -r requirements.txt  # If dependencies needed
```

## Basic Usage

### Start the Application
```bash
python cis_k8s_unified.py
```

### Menu Navigation
```
=== CIS KUBERNETES BENCHMARK (Unified) ===
MENU: 1)Audit 2)Fix 3)Both 4)Health 5)Help 0)Exit
> 1
```

## Common Workflows

### Workflow 1: Quick Audit of All Checks
```
> 1
Level [all]: <ENTER>
Role [all]: <ENTER>
Verbose (y/n) [n]: <ENTER>
Skip manual [n]: <ENTER>
Timeout [60]: <ENTER>
```
**Result**: Full audit with default settings, reports saved to `results/YYYY-MM-DD/audit/`

### Workflow 2: Audit Level 1 Master Nodes Only
```
> 1
Level [all]: 1
Role [all]: master
Verbose (y/n) [n]: y
Skip manual [n]: <ENTER>
Timeout [60]: 120
```
**Result**: Level 1 master nodes only, verbose output, with extended 120s timeout

### Workflow 3: Fix with Confirmation
```
> 2
Level [all]: 1
Role [all]: master
Timeout [60]: <ENTER>
Confirm Fix (y/n): y
```
**Result**: Remediation runs, automatic backups created to `results/backups/`

### Workflow 4: Audit Then Conditional Fix
```
> 3
Level [all]: 2
Role [all]: all
Verbose (y/n) [n]: n
Skip manual [n]: y
Timeout [60]: <ENTER>
Proceed to Fix (y/n): y
```
**Result**: Level 2 audit (skipping manual checks), review results, then fix if satisfied

## Configuration Options

| Option | Values | Default | Description |
|--------|--------|---------|-------------|
| Level | 1, 2, all | all | CIS Benchmark level |
| Role | master, worker, all | all | Kubernetes node role |
| Verbose | y, n | n | Detailed output per check |
| Skip Manual | y, n | n | Skip manual checks (SKIPPED status) |
| Timeout | seconds | 60 | Max time per script |

## Output Files

After each run, outputs are saved to:

```
results/
  YYYY-MM-DD/
    audit/
      run_YYYYMMDD_HHMMSS/
        summary.txt           ← Key statistics and score
        failed_items.txt      ← Detailed failures/manual/skipped
        report.csv            ← Machine-readable results
        report.json           ← Stats + detailed JSON
        report.html           ← Styled HTML report (open in browser!)
    remediation/
      run_YYYYMMDD_HHMMSS/
        (same reports)
  logs/
    activity_YYYYMMDD_HHMMSS.log  ← All operations logged
  backups/
    backup_YYYYMMDD_HHMMSS/       ← Pre-remediation backups
```

## Viewing Results

**After audit/fix completes, you get a results menu:**
```
View Results:
1) Summary
2) Failed Items
3) HTML Report
4) Skip
> 1
```

**Or manually**:
```bash
# View summary
cat results/YYYY-MM-DD/audit/run_*/summary.txt

# View failed checks
cat results/YYYY-MM-DD/audit/run_*/failed_items.txt

# Open HTML report in browser
open results/YYYY-MM-DD/audit/run_*/report.html

# View activity logs
cat results/logs/activity_*.log
```

## Activity Logging

All operations are logged automatically:

```bash
# View recent activities
tail -20 results/logs/activity_*.log

# Search for specific operations
grep "AUDIT_START\|AUDIT_END" results/logs/activity_*.log
grep "FIX_START\|FIX_END" results/logs/activity_*.log

# Real-time monitoring
tail -f results/logs/activity_*.log
```

## Understanding Results

### Summary Report Example
```
============================================================
CIS KUBERNETES BENCHMARK AUDIT SUMMARY
============================================================
Total Checks:      245
PASS:              198 (80.8%)
FAIL:               25 (10.2%)
MANUAL:             15  (6.1%)
SKIPPED:             7  (2.9%)
ERROR:               0  (0.0%)

Compliance Score: 80.8%
============================================================
```

### Status Meanings
- **PASS**: Check passed, system is compliant
- **FAIL**: Check failed, remediation recommended
- **MANUAL**: Manual review required, not automated
- **SKIPPED**: Manually skipped by user request
- **ERROR**: Script execution error, review details

## Troubleshooting

### "Missing dependencies: kubectl, jq, grep, sed, awk"
This is just a warning. The tool will still run, but some advanced checks may not work.
**Solution**: Install missing tools on your system

### "Cannot remediate: Cluster Health is CRITICAL"
The cluster health check failed, fixing is unsafe.
**Solution**: 
1. Check cluster health: Menu → 4
2. Fix critical issues first
3. Then try remediation again

### Logs not appearing
Check that results/logs/ directory was created:
```bash
ls -la results/logs/
```

### Script timeout errors
Some checks may take longer than default 60s.
**Solution**: Increase timeout when prompted (e.g., 300 for 5 minutes)

## Advanced Usage

### Run audit in background
```bash
nohup python cis_k8s_unified.py > audit.log 2>&1 &
```

### Process logs programmatically
```python
import re

with open("results/logs/activity_*.log") as f:
    for line in f:
        if "AUDIT_END" in line:
            print("Audit completed:", line)
```

### Compare audit results
```bash
# Save previous results
cp results/YYYY-MM-DD/audit/run_*/report.json report_prev.json

# Run new audit
python cis_k8s_unified.py
# Menu: 1

# Compare results
diff report_prev.json results/YYYY-MM-DD/audit/run_*/report.json
```

## Tips & Tricks

1. **First run**: Use menu option 3 (Both) with skip_manual=y to see what needs fixing
2. **Timing**: Audit typically takes 5-15 minutes depending on cluster size
3. **Backups**: Backups are auto-created before any fix operation (check results/backups/)
4. **Help**: Menu option 5 shows detailed help for each operation
5. **Logs**: Activity logs are great for compliance audits and troubleshooting

## Performance Tips

- **Single level audit**: Faster (~5 min) than full audit (~15 min)
- **Skip manual checks**: Saves time if you're just looking at automated checks
- **Extend timeout**: If seeing many timeouts, increase timeout to 120-300 seconds
- **Parallel execution**: Already using 8 workers, not configurable per check

## Support Resources

- **Full docs**: See IMPLEMENTATION_SUMMARY.md
- **Logging docs**: See ACTIVITY_LOGGING.md
- **Completion report**: See COMPLETION_REPORT.md
- **Original README**: See README.md

## Exit Codes

- **0**: Success (normal exit)
- **1**: Command-line error or keyboard interrupt

---

**Happy Benchmarking!** Use this tool to ensure your Kubernetes clusters comply with CIS security standards.
