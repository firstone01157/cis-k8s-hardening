# Print Stats Summary - Complete Reference Guide

## Complete Refactored Method

```python
def print_stats_summary(self):
    """Display color-coded statistics summary / แสดงสรุปสถิติที่มีรหัสสี"""
    print(f"\n{Colors.CYAN}{'='*70}")
    print("STATISTICS SUMMARY")
    print(f"{'='*70}{Colors.ENDC}")
    
    for role in ["master", "worker"]:
        s = self.stats[role]
        if s['total'] == 0:
            continue
        
        success_rate = (s['pass'] * 100 // s['total']) if s['total'] > 0 else 0
        
        # Determine score color based on success rate
        if success_rate > 80:
            score_color = Colors.GREEN
            score_status = "Excellent"
        elif success_rate >= 50:
            score_color = Colors.YELLOW
            score_status = "Needs Improvement"
        else:
            score_color = Colors.RED
            score_status = "Critical"
        
        print(f"\n  {Colors.BOLD}{role.upper()}:{Colors.ENDC}")
        print(f"    {Colors.GREEN}Pass{Colors.ENDC}:     {Colors.GREEN}{s['pass']}{Colors.ENDC}")
        print(f"    {Colors.RED}Fail{Colors.ENDC}:     {Colors.RED}{s['fail']}{Colors.ENDC}")
        print(f"    {Colors.YELLOW}Manual{Colors.ENDC}:   {Colors.YELLOW}{s['manual']}{Colors.ENDC}")
        print(f"    {Colors.BLUE}Skipped{Colors.ENDC}:  {Colors.BLUE}{s['skipped']}{Colors.ENDC}")
        print(f"    {Colors.BOLD}Total{Colors.ENDC}:    {Colors.BOLD}{s['total']}{Colors.ENDC}")
        print(f"    {Colors.BOLD}Score{Colors.ENDC}:    {score_color}{success_rate}% ({score_status}){Colors.ENDC}")
    
    print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
```

## Color Specifications

### Label Colors
- **Pass**: `Colors.GREEN` (`\033[92m`)
- **Fail**: `Colors.RED` (`\033[91m`)
- **Manual**: `Colors.YELLOW` (`\033[93m`)
- **Skipped**: `Colors.BLUE` (`\033[94m`)

### Value Colors (Match Labels)
- Pass count: `Colors.GREEN`
- Fail count: `Colors.RED`
- Manual count: `Colors.YELLOW`
- Skipped count: `Colors.BLUE`

### Special Elements
- **Total label**: `Colors.BOLD` (`\033[1m`)
- **Total value**: `Colors.BOLD`
- **Score label**: `Colors.BOLD`
- **Score value**: Dynamic (based on percentage)

### Score Color Logic
```python
if success_rate > 80:
    score_color = Colors.GREEN
    score_status = "Excellent"
elif success_rate >= 50:
    score_color = Colors.YELLOW
    score_status = "Needs Improvement"
else:
    score_color = Colors.RED
    score_status = "Critical"
```

### Structure Colors
- Header/Footer: `Colors.CYAN` (`\033[96m`)
- Color Reset: `Colors.ENDC` (`\033[0m`)

## Output Format

### Header
```
══════════════════════════════════════════════════════════════════════════
STATISTICS SUMMARY
══════════════════════════════════════════════════════════════════════════
```
(70 characters wide, CYAN color)

### Role Section
```
  [ROLE HEADER - BOLD, UPPERCASE]
    [LABEL - COLOR]: [VALUE - COLOR]
    [LABEL - COLOR]: [VALUE - COLOR]
    [LABEL - COLOR]: [VALUE - COLOR]
    [LABEL - COLOR]: [VALUE - COLOR]
    [LABEL - BOLD]: [VALUE - BOLD]
    [LABEL - BOLD]: [VALUE - DYNAMIC COLOR] ([STATUS MESSAGE])
```

### Footer
```
══════════════════════════════════════════════════════════════════════════
```
(70 characters wide, CYAN color)

## Line-by-Line Analysis

### Line 1: Method Definition
```python
def print_stats_summary(self):
```
- Standard instance method
- No parameters except `self`
- No return value

### Line 2: Docstring
```python
"""Display color-coded statistics summary / แสดงสรุปสถิติที่มีรหัสสี"""
```
- English and Thai descriptions
- Explains the method's purpose

### Lines 3-4: Header
```python
print(f"\n{Colors.CYAN}{'='*70}")
print("STATISTICS SUMMARY")
```
- Blank line (`\n`)
- 70-character border in CYAN
- Title text

### Line 5: Header Bottom
```python
print(f"{'='*70}{Colors.ENDC}")
```
- Closing border with color reset

### Line 6: Role Loop
```python
for role in ["master", "worker"]:
```
- Iterates through both node types
- Process each independently

### Lines 7-8: Stats Retrieval
```python
s = self.stats[role]
if s['total'] == 0:
```
- Get stats dict for current role
- Skip if no tests ran (total == 0)

### Line 9: Continue Statement
```python
    continue
```
- Skip to next role if total is 0

### Line 11: Calculate Success Rate
```python
success_rate = (s['pass'] * 100 // s['total']) if s['total'] > 0 else 0
```
- Integer percentage calculation
- Prevents division by zero
- Formula: (pass_count * 100) // total_count

### Lines 13-22: Score Color Determination
```python
if success_rate > 80:
    score_color = Colors.GREEN
    score_status = "Excellent"
elif success_rate >= 50:
    score_color = Colors.YELLOW
    score_status = "Needs Improvement"
else:
    score_color = Colors.RED
    score_status = "Critical"
```
- Multi-branch conditional
- Determines both color and status message
- Thresholds: 80% and 50%

### Line 24: Role Header
```python
print(f"\n  {Colors.BOLD}{role.upper()}:{Colors.ENDC}")
```
- Blank line before role
- 2-space indent
- BOLD uppercase role name
- Color reset

### Lines 25-30: Metric Rows
```python
print(f"    {Colors.GREEN}Pass{Colors.ENDC}:     {Colors.GREEN}{s['pass']}{Colors.ENDC}")
print(f"    {Colors.RED}Fail{Colors.ENDC}:     {Colors.RED}{s['fail']}{Colors.ENDC}")
print(f"    {Colors.YELLOW}Manual{Colors.ENDC}:   {Colors.YELLOW}{s['manual']}{Colors.ENDC}")
print(f"    {Colors.BLUE}Skipped{Colors.ENDC}:  {Colors.BLUE}{s['skipped']}{Colors.ENDC}")
print(f"    {Colors.BOLD}Total{Colors.ENDC}:    {Colors.BOLD}{s['total']}{Colors.ENDC}")
```
- 4-space indent
- Color label + reset
- Consistent spacing (labels aligned)
- Color value + reset

### Line 31: Score Row
```python
print(f"    {Colors.BOLD}Score{Colors.ENDC}:    {score_color}{success_rate}% ({score_status}){Colors.ENDC}")
```
- Same 4-space indent
- BOLD label
- Dynamic color value
- Status message in parentheses
- Color reset

### Line 33: Footer
```python
print(f"\n{Colors.CYAN}{'='*70}{Colors.ENDC}")
```
- Blank line
- CYAN 70-character border
- Color reset

## Edge Cases Handled

1. **Zero Tests for a Role**
   - Check: `if s['total'] == 0: continue`
   - Skips role if no tests were run

2. **Division by Zero in Success Rate**
   - Check: `if s['total'] > 0 else 0`
   - Returns 0% if total is 0

3. **Boundary Condition: 80%**
   - Uses `>` (strictly greater than)
   - 80% exactly = YELLOW, not GREEN

4. **Boundary Condition: 50%**
   - Uses `>=` (greater than or equal)
   - 50% exactly = YELLOW, not RED

## Requirements Met

✅ **Requirement 1: Color-Coded Labels**
- Pass: GREEN
- Fail: RED
- Manual: YELLOW
- Skipped: BLUE

✅ **Requirement 2: Score Color Logic**
- > 80%: GREEN (Excellent)
- 50-80%: YELLOW (Needs Improvement)
- < 50%: RED (Critical)

✅ **Requirement 3: Clean Layout**
- Proper indentation (2/4 spaces)
- Consistent alignment
- Professional spacing

✅ **Requirement 4: Bold Total**
- Total label: BOLD
- Total value: BOLD

✅ **Requirement 5: Complete Code**
- Full method provided
- Ready for copy-paste
- All dependencies satisfied

✅ **Requirement 6: Bilingual**
- English docstring
- Thai docstring

## Testing Examples

### Example 1: Excellent Security (85% Score)
```
Input:
  s['pass'] = 42
  s['fail'] = 5
  s['manual'] = 8
  s['skipped'] = 2
  s['total'] = 57

Calculation:
  success_rate = (42 * 100) // 57 = 4200 // 57 = 73%
  
Wait, 73% is not > 80, so it should be YELLOW...

Let me recalculate for truly > 80%:
  s['pass'] = 49
  s['fail'] = 4
  s['manual'] = 3
  s['skipped'] = 1
  s['total'] = 57
  
  success_rate = (49 * 100) // 57 = 4900 // 57 = 86%
  
86% > 80 → GREEN, "Excellent"

Output:
  Score:    86% (Excellent)  [GREEN]
```

### Example 2: Moderate Security (65% Score)
```
Input:
  s['pass'] = 37
  s['fail'] = 12
  s['manual'] = 6
  s['skipped'] = 2
  s['total'] = 57

Calculation:
  success_rate = (37 * 100) // 57 = 3700 // 57 = 64%
  
64% >= 50 and 64% <= 80 → YELLOW, "Needs Improvement"

Output:
  Score:    64% (Needs Improvement)  [YELLOW]
```

### Example 3: Critical Issues (35% Score)
```
Input:
  s['pass'] = 20
  s['fail'] = 25
  s['manual'] = 10
  s['skipped'] = 2
  s['total'] = 57

Calculation:
  success_rate = (20 * 100) // 57 = 2000 // 57 = 35%
  
35% < 50 → RED, "Critical"

Output:
  Score:    35% (Critical)  [RED]
```

## Integration Points

The method is called in the normal execution flow:
```python
# In run_audit_for_role() method
# After all tests complete and stats are collected
self.print_stats_summary()

# In show_menu() or main loop
# Displays final statistics before exit
```

## Dependencies

**Required:**
- `self.stats`: Dictionary with structure:
  ```python
  {
      "master": {"pass": int, "fail": int, "manual": int, "skipped": int, "total": int},
      "worker": {"pass": int, "fail": int, "manual": int, "skipped": int, "total": int}
  }
  ```
- `Colors` class: ANSI color codes

**Optional:**
- None (method is completely self-contained)

## Performance

- **Time Complexity**: O(2) = O(1) - loops through fixed 2 roles
- **Space Complexity**: O(1) - no additional data structures
- **I/O Operations**: 9+ print statements (acceptable for summary output)

## Backward Compatibility

✅ **Fully Backward Compatible**
- Signature unchanged
- No parameters added
- No return value
- Same data structure usage
- Existing code will work without modification

## Accessibility

The color-coded approach provides:
- **Color**: Visual indication for rapid scanning
- **Text Labels**: Support for color-blind users
- **Status Messages**: Explicit text description ("Excellent", "Needs Improvement", "Critical")
- **Structure**: Clear layout with consistent formatting

## Future Enhancements

Possible improvements:
1. Configurable color scheme
2. Status message customization
3. Export to JSON/CSV
4. Timestamp addition
5. Trend tracking (previous scores)
6. Role-specific recommendations

