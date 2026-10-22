# Shared helpers for the track-record scripts. Works in Windows PowerShell 5.1 and PowerShell 7.

$script:TR = $PSScriptRoot
$script:Utf8Bom = New-Object System.Text.UTF8Encoding $true

# One table per CSV file. Semicolon separated with a BOM, so Swedish Excel opens them directly.
$script:Columns = @{
    runs    = @('run_id', 'date', 'phase', 'night', 'project', 'language',
                'harness_version', 'harness_commit', 'harness_dirty', 'model_file', 'model_size_gb',
                'engine_build', 'mtp_on', 'context_tokens',
                'orders_queued', 'orders_finished_clean', 'orders_set_aside', 'parts_total', 'parts_first_try',
                'red_first_passes_before', 'minutes_waiting_for_person', 'idle_minutes',
                'engine_collapses', 'engine_restarts', 'nudges_no_progress', 'nudges_contradiction',
                'continuations', 'summaries', 'write_tokens_per_s', 'read_tokens_per_s',
                'suite_seconds_at_end', 'night_minutes', 'new_harness_defects', 'notes')
    orders  = @('run_id', 'date', 'phase', 'project', 'order', 'title', 'type', 'level',
                'parts_total', 'parts_first_try', 'parts_done', 'outcome', 'minutes', 'cause', 'notes')
    bugs    = @('run_id', 'date', 'phase', 'harness_version', 'bug', 'level', 'order_level',
                'title', 'verdict', 'failed', 'passed')
    changes = @('change_id', 'date', 'harness_version', 'area', 'what', 'why_data', 'expected', 'measured_after')
}

# The morning fields in runs.csv, in the order end-night.ps1 asks for them.
$script:MorningFields = @('orders_finished_clean', 'orders_set_aside', 'parts_first_try',
    'red_first_passes_before', 'minutes_waiting_for_person', 'idle_minutes',
    'engine_collapses', 'engine_restarts', 'nudges_no_progress', 'nudges_contradiction',
    'continuations', 'summaries', 'write_tokens_per_s', 'read_tokens_per_s',
    'suite_seconds_at_end', 'night_minutes', 'new_harness_defects', 'notes')

function Get-TablePath([string]$Name) { Join-Path $script:TR ($Name + '.csv') }

function Read-Table([string]$Name) {
    $path = Get-TablePath $Name
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    return @(Import-Csv -LiteralPath $path -Delimiter ';' -Encoding UTF8)
}

function Format-Cell([string]$Value) {
    if ($Value -match '[;"\r\n]') { return '"' + ($Value -replace '"', '""') + '"' }
    return $Value
}

function Write-Table([string]$Name, $Rows) {
    $cols = $script:Columns[$Name]
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(($cols -join ';'))
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { continue }
        $vals = foreach ($c in $cols) { Format-Cell ([string]$r.$c) }
        $lines.Add(($vals -join ';'))
    }
    [System.IO.File]::WriteAllLines((Get-TablePath $Name), $lines, $script:Utf8Bom)
}

function New-Row([string]$Name, [hashtable]$Values) {
    $o = [ordered]@{}
    foreach ($c in $script:Columns[$Name]) {
        if ($Values.ContainsKey($c)) { $o[$c] = [string]$Values[$c] } else { $o[$c] = '' }
    }
    return [pscustomobject]$o
}

# Numbers may be typed as 7,5 (Swedish) or 7.5. Empty or text gives $null.
function ConvertTo-Number($Value) {
    if ($null -eq $Value) { return $null }
    $t = ([string]$Value).Trim().Replace(',', '.')
    if ($t -eq '') { return $null }
    $d = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }
    return $null
}

# git without letting its error text stop the script in Windows PowerShell 5.1.
function Invoke-GitQuiet([string[]]$GitArgs) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { return @(& git @GitArgs 2>$null) } finally { $ErrorActionPreference = $old }
}

# The kit's three levels. The level number is what the hint ladder counts down.
function Get-LevelNumber([string]$Level) {
    switch -Regex ($Level) {
        '^(1|described)' { return 1 }
        '^(2|symptom)' { return 2 }
        '^(3|silent|review)' { return 3 }
        default { return $null }
    }
}
