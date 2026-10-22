<#
Run in the evening, just before you press Run. It records what runs tonight (harness version,
model, engine settings) and adds tonight's orders to orders.csv, ready to fill in tomorrow.

Company-code kit, first night (orders 01-07):
  .\start-night.ps1 -Phase kit-1 -Night 1 -HarnessRepo C:\varde -Model C:\models\bonsai-2-27b.gguf `
      -EngineBuild b10777 -Mtp on -Context 131072 -KitPath C:\kits\bitwarden-kit -Orders (1..7)

Hint-ladder night (the clearer versions of unfixed bugs):
  .\start-night.ps1 -Phase kit-hints -Night 1 ... -HintFiles 'C:\kits\bitwarden-kit\hints\bug 13 - level 2 Symptom only - Someone joined with an unverified e-mail address.txt'

Two weeks of work orders, night 1:
  .\start-night.ps1 -Phase orders -Night 1 -HarnessRepo C:\varde -Model ... -EngineBuild b10777 -Mtp on -Context 131072
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('kit-1', 'kit-hints', 'orders', 'kit-2')][string] $Phase,
    [Parameter(Mandatory = $true)][int] $Night,
    [Parameter(Mandatory = $true)][string] $HarnessRepo,
    [Parameter(Mandatory = $true)][string] $Model,
    [string] $EngineBuild = '',
    [ValidateSet('on', 'off')][string] $Mtp = 'on',
    [int] $Context = 0,
    [string] $KitPath = '',
    [int[]] $Orders = @(),
    [string[]] $HintFiles = @(),
    [string] $OrdersIndex = '',
    [switch] $AllowDirty
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')
if (-not $OrdersIndex) { $OrdersIndex = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'work-orders') 'orders-index.csv' }

# 1. Harness version. Every night's results must belong to one committed version.
$HarnessRepo = (Resolve-Path -LiteralPath $HarnessRepo).Path
$commit = (Invoke-GitQuiet @('-C', $HarnessRepo, 'rev-parse', '--short', 'HEAD')) -join ''
if ($LASTEXITCODE -ne 0 -or -not $commit) {
    throw "$HarnessRepo is not a git repository. Put the harness under git, so every night is tied to a version."
}
$version = (Invoke-GitQuiet @('-C', $HarnessRepo, 'describe', '--tags', '--always')) -join ''
$dirty = (Invoke-GitQuiet @('-C', $HarnessRepo, 'status', '--porcelain', '--untracked-files=no')).Count -gt 0
if ($dirty -and -not $AllowDirty) {
    throw "The harness has uncommitted changes. Commit and tag them first (for example: git tag harness-v1), so tonight's results belong to one version. Use -AllowDirty to record anyway."
}

# 2. Model file.
$mf = Get-Item -LiteralPath $Model
$sizeGb = '{0:0.0}' -f ($mf.Length / 1GB)

# 3. Run id, unique per phase and night.
$date = Get-Date -Format 'yyyy-MM-dd'
$runId = '{0}-{1}-n{2:D2}' -f $date, $Phase, $Night
$runs = @(Read-Table 'runs')
if (@($runs | Where-Object { $_.run_id -eq $runId }).Count) { throw "Run $runId is already recorded. Use another -Night, or edit runs.csv." }

# 4. Tonight's orders, pre-filled so the morning only needs the results.
$new = @()
if ($Phase -eq 'orders') {
    if (-not (Test-Path -LiteralPath $OrdersIndex)) { throw "Cannot find $OrdersIndex. Pass -OrdersIndex." }
    $idx = @(Import-Csv -LiteralPath $OrdersIndex -Delimiter ';' -Encoding UTF8 | Where-Object { [int]$_.night -eq $Night })
    if ($Orders.Count) { $idx = @($idx | Where-Object { $Orders -contains [int]$_.order }) }
    if ($idx.Count -eq 0) { throw "No orders for night $Night in $OrdersIndex." }
    $project = $idx[0].project; $language = $idx[0].language
    foreach ($o in $idx) {
        $new += New-Row 'orders' @{ run_id = $runId; date = $date; phase = $Phase; project = $o.project; order = $o.order
            title = $o.title; type = $o.type; parts_total = $o.parts }
    }
} elseif ($Phase -eq 'kit-hints') {
    $project = 'Bitwarden'; $language = 'CSharp'
    if ($HintFiles.Count -eq 0) { throw "Pass -HintFiles with tonight's hint orders from the kit's hints folder." }
    foreach ($f in $HintFiles) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($f)   # bug 13 - level 2 Symptom only - Title
        $bits = $name -split ' - ', 3
        if ($bits.Count -lt 3) { throw "Unexpected hint file name: $name" }
        $bug = '{0:D2}' -f [int]($bits[0] -replace '\D', '')
        $parts = @(Select-String -LiteralPath $f -Pattern '^Part \d+:').Count
        $new += New-Row 'orders' @{ run_id = $runId; date = $date; phase = $Phase; project = $project; order = "bug $bug"
            title = $bits[2]; type = 'bugfix'; level = ($bits[1] -replace '^level\s+', ''); parts_total = $parts }
    }
} else {
    $project = 'Bitwarden'; $language = 'CSharp'
    if (-not $KitPath) { throw "Pass -KitPath (the company-code kit folder) for the kit phases." }
    $tasks = @((Get-Content -LiteralPath (Join-Path $KitPath 'tasks.json') -Raw | ConvertFrom-Json).tasks)
    foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $KitPath 'orders') -Filter '*.txt' | Sort-Object Name)) {
        $num = [int]$f.Name.Substring(0, 2)
        if ($Orders.Count -and -not ($Orders -contains $num)) { continue }
        $key = '{0:D2}' -f $num
        $t = @($tasks | Where-Object { ([string]$_.order).StartsWith($key) })
        $level = '1 Described'
        if ($t.Count -and $t[0].level -eq 'symptom') { $level = '2 Symptom only' }
        if ($t.Count -and $t[0].level -eq 'silent') { $level = '3 Review' }
        $type = 'bugfix'; if ($level -eq '3 Review') { $type = 'review' }
        $parts = @(Select-String -LiteralPath $f.FullName -Pattern '^Part \d+:').Count
        $new += New-Row 'orders' @{ run_id = $runId; date = $date; phase = $Phase; project = $project; order = $key
            title = $f.BaseName.Substring(3); type = $type; level = $level; parts_total = $parts }
    }
    if ($new.Count -eq 0) { throw "No kit orders matched -Orders $($Orders -join ',')." }
}

$partsTotal = 0; foreach ($o in $new) { $partsTotal += [int]$o.parts_total }
$runs += New-Row 'runs' @{ run_id = $runId; date = $date; phase = $Phase; night = $Night; project = $project; language = $language
    harness_version = $version; harness_commit = $commit; harness_dirty = $(if ($dirty) { 'yes' } else { 'no' })
    model_file = $mf.Name; model_size_gb = $sizeGb; engine_build = $EngineBuild; mtp_on = $Mtp; context_tokens = $Context
    orders_queued = $new.Count; parts_total = $partsTotal }
Write-Table 'runs' $runs
$all = @(Read-Table 'orders') + $new
Write-Table 'orders' $all

Write-Host "Recorded $runId"
Write-Host "  Harness $version ($commit)$(if ($dirty) { ', UNCOMMITTED CHANGES' })"
Write-Host "  Model $($mf.Name), $sizeGb GB; engine $EngineBuild; MTP $Mtp; context $Context"
Write-Host "  $($new.Count) orders, $partsTotal parts added to orders.csv"
Write-Host ""
Write-Host "Tomorrow morning: .\end-night.ps1 (and fill in this run's rows in orders.csv)."
