# CIS Kubernetes Benchmark v1.12.0 - Complete Toolkit

This repository contains comprehensive tools for auditing and remediating Kubernetes clusters against the **CIS Kubernetes Benchmark v1.12.0**.

## What's Included

### Bash Scripts (Original Implementation)
- **`Level_1_Master_Node/`**: Standard security checks for Master Nodes
- **`Level_2_Master_Node/`**: Enhanced security checks for Master Nodes
- **`Level_1_Worker_Node/`**: Standard security checks for Worker Nodes
- **`Level_2_Worker_Node/`**: Enhanced security checks for Worker Nodes

Each check directory contains:
- `X.X.X_audit.sh`: Audit script (returns 0=PASS, 1=FAIL)
- `X.X.X_remediate.sh`: Remediation script (applies fixes)

### Python Application (New Implementation)
- **`cis_k8s_unified.py`**: Complete interactive audit/remediation tool (750+ lines)
  - Parallel execution with progress tracking
  - Multiple report formats (CSV, JSON, HTML, TXT)
  - Activity logging for audit trails
  - Interactive menu system
  - Health checking

### Testing & Validation
- `test_logging.py`: Validates activity logging functionality

## Documentation (Choose Your Path)

### Quick Start Users
→ **START HERE**: Read `QUICKSTART.md` (5-10 min)
- Installation and first run
- Common workflows with examples
- Configuration options
- Troubleshooting tips

### Technical Users
→ **DETAILED GUIDE**: Read `IMPLEMENTATION_SUMMARY.md` (20-30 min)
- 25 implemented features overview
- Architecture and design
- All report formats explained
- Code structure
- Advanced usage examples

### Logging & Compliance
→ **LOGGING DETAILS**: Read `ACTIVITY_LOGGING.md` (10-15 min)
- Activity log format and location
- All logged events documented
- Implementation details
- Audit trail use cases

### Session Information
→ **COMPLETION REPORT**: Read `COMPLETION_REPORT.md` (10-15 min)
- What was built in this session
- Code changes summary
- Quality assurance details
- Deployment checklist

### Navigation Help
→ **DOCUMENTATION INDEX**: Read `DOCUMENTATION_INDEX.md` (5 min)
- Quick navigation by task
- File locations
- Feature summary
- Getting started steps

## Quick Start

```bash
# 1. Navigate to project directory
cd CIS_Kubernetes_Benchmark_V1.12.0

# 2. Run the application
python cis_k8s_unified.py

# 3. Select menu option (1=Audit, 2=Fix, 3=Both, 4=Health, 5=Help, 0=Exit)
# Follow the prompts for Level, Role, and other options

# 4. Results are saved to:
#    - Reports: results/YYYY-MM-DD/audit/ or results/YYYY-MM-DD/remediation/
#    - Logs: results/logs/activity_*.log
#    - Backups: results/backups/
```

## Prerequisites

### For Running Bash Scripts Directly
- **OS**: Linux (Ubuntu/Debian tested)
- **Shell**: Bash
- **Tools**: kubectl, jq, grep, sed, awk, systemctl
- **Privileges**: Root or sudo access

### For Running Python Application
- **Python**: 3.10+
- **Modules**: Standard library only (subprocess, json, csv, argparse, etc.)
- **Privileges**: Root or sudo access for actual remediation

## Key Features

### Audit Operations
- ✓ Parallel execution (8 concurrent workers)
- ✓ Real-time progress display (percentage complete)
- ✓ Configurable timeout per script (default 60s)
- ✓ Manual check detection (not counted as automated PASS)
- ✓ Verbose output mode option
- ✓ Skip manual checks option

### Remediation Operations
- ✓ Automatic backup before fixing (kubernetes configs)
- ✓ Parallel execution for speed
- ✓ Graceful error handling
- ✓ Confirmation prompt before proceeding
- ✓ Health check to prevent unsafe fixes

### Reporting & Analytics
- ✓ Text summary (compliance score %)
- ✓ Detailed failed items list
- ✓ CSV export (machine-readable)
- ✓ JSON export (stats + details)
- ✓ HTML report (styled, browser-friendly)
- ✓ Performance metrics (top 5 slowest checks)
- ✓ Per-role statistics (master vs worker)

### Logging & Monitoring
- ✓ Activity logging (all operations tracked)
- ✓ Timestamped log entries
- ✓ Operation summaries
- ✓ Results tracking for compliance
- ✓ Health status monitoring

## Usage Examples

### Example 1: Full Audit with Default Settings
```bash
python cis_k8s_unified.py
> 1  # Select Audit
> <ENTER>  # All levels
> <ENTER>  # All roles
> <ENTER>  # No verbose
> <ENTER>  # Don't skip manual
> <ENTER>  # Default 60s timeout
```

### Example 2: Level 1 Master Nodes Only (Verbose)
```bash
python cis_k8s_unified.py
> 1  # Audit
> 1  # Level 1 only
> master  # Master nodes only
> y  # Verbose output
> n  # Include manual checks
> 120  # Increase timeout to 2 minutes
```

### Example 3: Audit Then Fix with Review
```bash
python cis_k8s_unified.py
> 3  # Both audit and fix
> 1  # Level 1
> all  # All roles
> n  # No verbose
> y  # Skip manual checks
> <ENTER>  # Default timeout
# Review audit results, then:
> y  # Confirm fix
```

## Output Structure

```
results/
├── YYYY-MM-DD/
│   ├── audit/run_YYYYMMDD_HHMMSS/
│   │   ├── summary.txt           # Compliance score and statistics
│   │   ├── failed_items.txt      # Detailed list of failures/manual/skipped
│   │   ├── report.csv            # Machine-readable results
│   │   ├── report.json           # Full data in JSON format
│   │   └── report.html           # Styled HTML report (open in browser!)
│   └── remediation/run_YYYYMMDD_HHMMSS/
│       └── (same report files)
├── logs/
│   └── activity_YYYYMMDD_HHMMSS.log  # All operations logged
└── backups/
    └── backup_YYYYMMDD_HHMMSS/       # Pre-remediation backups
```

## Understanding Results

### Summary Report
Shows the compliance score and breakdown:
- **PASS**: Check passed, system is compliant (counted in score)
- **FAIL**: Check failed, remediation recommended
- **MANUAL**: Requires manual review (not counted in compliance score)
- **SKIPPED**: User requested to skip (not counted in compliance score)
- **ERROR**: Script execution error (check details)

### HTML Report
Open `report.html` in any web browser to see:
- Compliance score and statistics
- Pass/Fail/Manual/Skipped breakdown per role
- Detailed results table with all checks
- Styled formatting for easy reading

### Activity Log
Useful for:
- Audit trail for compliance requirements
- Troubleshooting issues
- Tracking when operations were performed
- Performance analysis

## Important Notes

### Manual Checks
- Some CIS checks cannot be safely automated (e.g., network configuration)
- These are marked as "Manual" and require human review
- The tool detects these automatically (looks for "(Manual)" in check title)
- They are NOT counted in the compliance score by default
- Use "Skip manual?" option to exclude them from results

### Service Restarts
- Remediation scripts may require service restarts to take effect
- The tool does NOT automatically restart services (to prevent downtime)
- Static pods (apiserver, etcd, etc.) usually restart automatically
- Kubelet changes require: `systemctl daemon-reload && systemctl restart kubelet`

### Safety
- Backups are created before ANY remediation (see `results/backups/`)
- Confirmation prompt required before running fixes
- Health check prevents fixes when cluster is unhealthy
- Ctrl+C to abort long operations

## Troubleshooting

### "Missing dependencies: kubectl, jq, grep, sed, awk"
Just a warning. The tool will still run but some checks may fail.
**Solution**: Install missing tools on your Kubernetes nodes

### "Cannot remediate: Cluster Health is CRITICAL"
The cluster is in a bad state. Fixing could make it worse.
**Solution**: Review cluster health (menu 4) and fix critical issues first

### Script timeout errors
Some checks take longer than default 60 seconds.
**Solution**: Increase timeout when prompted (e.g., 300 for 5 minutes)

### Logs not appearing
Check that the results directory was created properly.
**Solution**: Manually create `results/` and `results/logs/` directories

## Requirements

### Minimum System
- Python 3.10+
- 10 MB disk space for application
- 100 MB disk space for results/backups

### Recommended
- Python 3.10+ (latest stable)
- 1 GB disk space for results/backups/logs
- kubectl configured with admin access
- Internet connectivity (optional, for updates)

## Support & Documentation

**Need Help?** Read the appropriate documentation file:

| Question | File | Time |
|----------|------|------|
| How do I get started? | `QUICKSTART.md` | 5-10 min |
| How does it work? | `IMPLEMENTATION_SUMMARY.md` | 20-30 min |
| Where are my logs? | `ACTIVITY_LOGGING.md` | 10-15 min |
| What was built? | `COMPLETION_REPORT.md` | 10-15 min |
| Where do I start? | `DOCUMENTATION_INDEX.md` | 5 min |

## Disclaimer

These scripts and tools are provided "as is" without warranty of any kind. The user assumes all risk associated with their use. Always test in a non-production environment first.

## Version Information

- **Tool Version**: 1.0
- **Benchmark Version**: CIS Kubernetes Benchmark v1.12.0
- **Python**: 3.10+
- **Status**: Production Ready
- **Last Updated**: 2025-11-26

---

## Next Steps

1. **Read** `QUICKSTART.md` for getting started
2. **Run** `python cis_k8s_unified.py`
3. **Review** the generated reports
4. **Check** activity logs for compliance tracking
5. **Deploy** to your Kubernetes clusters

**Happy Benchmarking!** Ensure your Kubernetes clusters meet CIS security standards.
