$ROOT_DIR = "c:\Users\jaksupak.khe\Documents\CIS_Kubernetes_Benchmark_V1.12.0"
$CSV_FILE = Join-Path $ROOT_DIR "CIS_Kubernetes_Benchmark_V1.12.0_PDF.csv"

$DIRS = @{
    "L1_Master" = "Level_1_Master_Node"
    "L2_Master" = "Level_2_Master_Node"
    "L1_Worker" = "Level_1_Worker_Node"
    "L2_Worker" = "Level_2_Worker_Node"
}

# Ensure directories exist
foreach ($d in $DIRS.Values) {
    $path = Join-Path $ROOT_DIR $d
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

function Get-TargetDir {
    param ($applicability)
    $applicability = $applicability.ToLower()
    $is_master = $applicability -match "master"
    $is_worker = $applicability -match "worker"
    $is_level_1 = $applicability -match "level 1"
    $is_level_2 = $applicability -match "level 2"

    if ($is_master -and $is_level_1) { return $DIRS["L1_Master"] }
    if ($is_master -and $is_level_2) { return $DIRS["L2_Master"] }
    if ($is_worker -and $is_level_1) { return $DIRS["L1_Worker"] }
    if ($is_worker -and $is_level_2) { return $DIRS["L2_Worker"] }
    return $null
}

function Find-File {
    param ($filename)
    foreach ($d in $DIRS.Values) {
        $path = Join-Path (Join-Path $ROOT_DIR $d) $filename
        if (Test-Path $path) {
            return @{Path=$path; Dir=$d}
        }
    }
    return $null
}

$stats = @{
    "L1_Master" = @{expected=0; found=0; missing=@()}
    "L2_Master" = @{expected=0; found=0; missing=@()}
    "L1_Worker" = @{expected=0; found=0; missing=@()}
    "L2_Worker" = @{expected=0; found=0; missing=@()}
}
$moved_files = @()

Write-Host "Reading CSV: $CSV_FILE"

# Read CSV, skipping first 3 lines
$csvData = Get-Content $CSV_FILE | Select-Object -Skip 3 | ConvertFrom-Csv -Delimiter "|"

foreach ($row in $csvData) {
    $rule_id = $row.Number
    $profile = $row."Profile Applicability"

    if (-not $rule_id -or -not $profile) { continue }

    $target_dir_name = Get-TargetDir -applicability $profile
    if (-not $target_dir_name) { continue }

    # Map target_dir_name back to stats key
    $stats_key = $null
    foreach ($key in $DIRS.Keys) {
        if ($DIRS[$key] -eq $target_dir_name) {
            $stats_key = $key
            break
        }
    }

    if ($stats_key) {
        $stats[$stats_key].expected++
    }

    foreach ($suffix in @("_audit.sh", "_remediate.sh")) {
        $filename = "$rule_id$suffix"
        $found = Find-File -filename $filename
        
        if ($found) {
            if ($stats_key) {
                $stats[$stats_key].found += 0.5
            }
            
            if ($found.Dir -ne $target_dir_name) {
                $new_path = Join-Path (Join-Path $ROOT_DIR $target_dir_name) $filename
                Write-Host "Moving $filename from $($found.Dir) to $target_dir_name"
                Move-Item -Path $found.Path -Destination $new_path -Force
                $moved_files += $filename
            }
        } else {
            if ($stats_key) {
                $stats[$stats_key].missing += $filename
            }
        }
    }
}

Write-Host "`n============================================================"
Write-Host ("{0,-15} | {1,-18} | {2,-18} | {3,-10}" -f "Category", "Expected (Rules)", "Found (Scripts)", "Coverage")
Write-Host "------------------------------------------------------------"

foreach ($cat in $stats.Keys) {
    $data = $stats[$cat]
    $expected_scripts = $data.expected * 2
    $found_scripts = [math]::Floor($data.found * 2)
    $coverage = if ($expected_scripts -gt 0) { "{0:N1}%" -f ($found_scripts / $expected_scripts * 100) } else { "N/A" }
    Write-Host ("{0,-15} | {1,-18} | {2,-18} | {3,-10}" -f $cat, $data.expected, $found_scripts, $coverage)
}

Write-Host "`n============================================================"
Write-Host "Total Files Moved: $($moved_files.Count)"
if ($moved_files.Count -gt 0) {
    Write-Host "Files Moved:"
    $moved_files | Select-Object -First 10 | ForEach-Object { Write-Host " - $_" }
    if ($moved_files.Count -gt 10) {
        Write-Host " ... and $($moved_files.Count - 10) more."
    }
}

Write-Host "`n============================================================"
Write-Host "Missing Scripts (Sample):"
foreach ($cat in $stats.Keys) {
    if ($stats[$cat].missing.Count -gt 0) {
        Write-Host "`n$cat Missing ($($stats[$cat].missing.Count)):"
        $stats[$cat].missing | Select-Object -First 5 | ForEach-Object { Write-Host " - $_" }
        if ($stats[$cat].missing.Count -gt 5) {
            Write-Host " ... and $($stats[$cat].missing.Count - 5) more."
        }
    }
}
