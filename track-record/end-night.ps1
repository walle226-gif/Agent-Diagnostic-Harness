<#
Run in the morning. It fills in last night's results in runs.csv, imports the company-code grades,
and can archive the harness's night log. Then fill in the night's rows in orders.csv and run report.ps1.

Ask for each value (Enter keeps what is there):
  .\end-night.ps1

Kit night: also grade, or import a grade file you already made:
  .\end-night.ps1 -KitPath C:\kits\bitwarden-kit                     (imports the newest grade-*.csv there)
  .\end-night.ps1 -GradeCsv C:\kits\bitwarden-kit\grade-20261025-0712.csv -HintLevels "13=2,14=2"

Scripted, for example from the harness at the end of a night:
  .\end-night.ps1 -Set "orders_finished_clean=7;parts_first_try=18;night_minutes=545" -LogPath C:\varde\logs\2026-10-24
#>
param(
    [string] $RunId = '',
    [string] $Set = '',
    [string] $GradeCsv = '',
    [string] $KitPath = '',
    [string] $HintLevels = '',
    [string] $LogPath = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

$runs = @(Read-Table 'runs')
if ($runs.Count -eq 0) { throw "runs.csv is empty. Run start-night.ps1 before the night." }
if ($RunId) { $run = @($runs | Where-Object { $_.run_id -eq $RunId })[0] }
else { $run = $runs[$runs.Count - 1] }
if (-not $run) { throw "No run $RunId in runs.csv." }
Write-Host "Run $($run.run_id) ($($run.phase), night $($run.night), harness $($run.harness_version))"

# 1. Morning numbers for runs.csv.
if ($Set) {
    foreach ($pair in ($Set -split ';')) {
        if (-not $pair.Trim()) { continue }
        $k, $v = $pair -split '=', 2
        $k = $k.Trim()
        if ($script:Columns['runs'] -notcontains $k) { throw "Unknown field '$k'. Fields: $($script:MorningFields -join ', ')" }
        $run.$k = $v.Trim()
    }
} else {
    Write-Host "Enter last night's numbers. Press Enter to keep the value in brackets."
    foreach ($f in $script:MorningFields) {
        $answer = Read-Host ("  {0} [{1}]" -f $f, $run.$f)
        if ($answer -ne '') { $run.$f = $answer }
    }
}
Write-Table 'runs' $runs

# 2. Company-code grades into bugs.csv.
if (-not $GradeCsv -and $KitPath) {
    $latest = Get-ChildItem -LiteralPath $KitPath -Filter 'grade-*.csv' | Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $latest) { throw "No grade-*.csv in $KitPath. Run grade.ps1 first." }
    $GradeCsv = $latest.FullName
}
if ($GradeCsv) {
    $hint = @{}
    foreach ($pair in ($HintLevels -split ',')) {
        if ($pair -match '^\s*(\d+)\s*=\s*(\d)\s*$') { $hint['{0:D2}' -f [int]$Matches[1]] = $Matches[2] }
    }
    $graded = @(Import-Csv -LiteralPath $GradeCsv -Delimiter ';' -Encoding UTF8)
    $bugs = @(Read-Table 'bugs' | Where-Object { $_.run_id -ne $run.run_id })   # re-import replaces
    foreach ($g in $graded) {
        $isSuite = ($g.Bug -eq '--')
        $bug = if ($isSuite) { 'suite' } else { '{0:D2}' -f [int]$g.Bug }
        $base = Get-LevelNumber $g.Level
        $given = $base
        if ($hint.ContainsKey($bug)) { $given = $hint[$bug] }
        $bugs += New-Row 'bugs' @{ run_id = $run.run_id; date = $run.date; phase = $run.phase; harness_version = $run.harness_version
            bug = $bug; level = $g.Level; order_level = $given; title = $g.Title; verdict = $g.Verdict; failed = $g.Failed; passed = $g.Passed }
    }
    Write-Table 'bugs' $bugs
    $pass = @($graded | Where-Object { $_.Bug -ne '--' -and $_.Verdict -eq 'PASS' }).Count
    $total = @($graded | Where-Object { $_.Bug -ne '--' }).Count
    Write-Host "Imported $(Split-Path -Leaf $GradeCsv): $pass of $total bugs PASS."
}

# 3. Keep the raw night log next to the numbers.
if ($LogPath) {
    $dest = Join-Path (Join-Path $PSScriptRoot 'logs') $run.run_id
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item -LiteralPath $LogPath -Destination $dest -Recurse -Force
    Write-Host "Archived $LogPath to logs\$($run.run_id)"
}

$open = @(Read-Table 'orders' | Where-Object { $_.run_id -eq $run.run_id -and -not $_.outcome }).Count
Write-Host ""
if ($open) { Write-Host "Next: fill in outcome, parts_first_try, parts_done, minutes and cause for $open orders of this run in orders.csv." }
Write-Host "Then: .\report.ps1"
