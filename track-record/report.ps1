<#
Builds track-record.html from the four tables: the company-code score per harness version,
the work orders per night, project and type, reliability per night, and the harness changes.

  .\report.ps1
  .\report.ps1 -Out C:\Users\Johan\Desktop\track-record.html
#>
param([string] $Out = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')
if (-not $Out) { $Out = Join-Path $PSScriptRoot 'track-record.html' }

$runs = @(Read-Table 'runs'); $orders = @(Read-Table 'orders'); $bugs = @(Read-Table 'bugs'); $changes = @(Read-Table 'changes')
# Excel turns 01 into 1 when it saves; put the zero back so bugs line up across nights.
foreach ($b in $bugs) { if ($b.bug -match '^\d+$') { $b.bug = '{0:D2}' -f [int]$b.bug } }
$sb = New-Object System.Text.StringBuilder
function Add([string]$s) { [void]$sb.AppendLine($s) }
function Enc($s) { [System.Net.WebUtility]::HtmlEncode([string]$s) }
function Sum($rows, [string]$field) { $t = 0.0; foreach ($r in @($rows)) { $n = ConvertTo-Number $r.$field; if ($null -ne $n) { $t += $n } }; return $t }
function Pct($a, $b) { if (-not $b) { return '&ndash;' }; return ('{0:0}%' -f (100.0 * $a / $b)) }
function Bar($a, $b) {
    if (-not $b) { return '' }
    $w = [math]::Max(0, [math]::Min(100, [math]::Round(100.0 * $a / $b)))
    return "<span class='bar'><span style='width:$w%'></span></span>"
}
function Num1($x) { if ($null -eq $x) { return '&ndash;' }; return ('{0:0.#}' -f $x) }
function Table([string[]]$head, $rowsHtml) {
    Add "<div class='scroll'><table><thead><tr>$(($head | ForEach-Object { "<th>$(Enc $_)</th>" }) -join '')</tr></thead><tbody>"
    foreach ($r in $rowsHtml) { Add "<tr>$(($r | ForEach-Object { "<td>$_</td>" }) -join '')</tr>" }
    Add "</tbody></table></div>"
}
function IsDone($o) { return ([string]$o.outcome).Trim().ToLower() -eq 'done' }

Add @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Harness track record</title>
<style>
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#6b6a65;--line:#e4e1d8;--card:#ffffff;--accent:#2f6f4f;--bad:#a8432f}
@media (prefers-color-scheme:dark){:root{--bg:#171715;--fg:#ecebe6;--muted:#a3a19a;--line:#33322e;--card:#20201d;--accent:#6fbf93;--bad:#e08a75}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,-apple-system,Segoe UI,sans-serif}
main{max-width:980px;margin:0 auto;padding:20px 16px 48px}
h1{font-size:1.5rem;margin:0 0 4px}h2{font-size:1.15rem;margin:32px 0 8px}h3{font-size:1rem;margin:20px 0 6px}
p{margin:6px 0}.muted{color:var(--muted)}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:12px 0}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px}
.card b{display:block;font-size:1.4rem}.card span{color:var(--muted);font-size:.85rem}
.scroll{overflow-x:auto;border:1px solid var(--line);border-radius:10px;background:var(--card)}
table{border-collapse:collapse;width:100%;font-size:.9rem}
th,td{padding:6px 10px;border-bottom:1px solid var(--line);text-align:left;white-space:nowrap}
th{color:var(--muted);font-weight:600}tr:last-child td{border-bottom:0}
.wrap{white-space:normal;display:inline-block;min-width:170px;max-width:280px}
.pass{color:var(--accent);font-weight:600}.fail{color:var(--bad)}
.bar{display:inline-block;width:70px;height:8px;background:var(--line);border-radius:4px;vertical-align:middle;margin-left:6px}
.bar span{display:block;height:100%;background:var(--accent);border-radius:4px}
</style></head><body><main>
<h1>Harness track record</h1>
<p class="muted">Built $(Get-Date -Format 'yyyy-MM-dd HH:mm') from $($runs.Count) nights. Every number is tied to the harness version that ran it.</p>
"@

# ---------- 1. Company-code kit ----------
Add "<h2>Company code: real bugs in Bitwarden server</h2>"
$kit = @($bugs | Where-Object { $_.bug -ne 'suite' })
if ($kit.Count -eq 0) { Add "<p class='muted'>No grades yet. After a kit night: .\end-night.ps1 -KitPath &lt;kit folder&gt;</p>" }
else {
    $levelOf = @{}; $titleOf = @{}
    foreach ($b in $kit) { $levelOf[$b.bug] = Get-LevelNumber $b.level; $titleOf[$b.bug] = $b.title }
    $allBugs = @($levelOf.Keys | Sort-Object)
    $perLevel = @{ 1 = @($allBugs | Where-Object { $levelOf[$_] -eq 1 }).Count; 2 = @($allBugs | Where-Object { $levelOf[$_] -eq 2 }).Count; 3 = @($allBugs | Where-Object { $levelOf[$_] -eq 3 }).Count }
    $versions = @($kit | ForEach-Object { $_.harness_version } | Select-Object -Unique)
    $rows = @()
    foreach ($v in $versions) {
        $vr = @($kit | Where-Object { $_.harness_version -eq $v })
        $fixed = @($vr | Where-Object { $_.verdict -eq 'PASS' } | ForEach-Object { $_.bug } | Select-Object -Unique)
        $noHint = @($vr | Where-Object { $_.verdict -eq 'PASS' -and [int]$_.order_level -eq $levelOf[$_.bug] } | ForEach-Object { $_.bug } | Select-Object -Unique)
        $cells = @("<b>$(Enc $v)</b>")
        foreach ($l in 1, 2, 3) { $n = @($fixed | Where-Object { $levelOf[$_] -eq $l }).Count; $cells += "$n / $($perLevel[$l])$(Bar $n $perLevel[$l])" }
        $cells += "<b>$($fixed.Count) / $($allBugs.Count)</b>"
        $cells += "$($noHint.Count)"
        $suite = @($bugs | Where-Object { $_.bug -eq 'suite' -and $_.harness_version -eq $v } | Select-Object -Last 1)
        if ($suite.Count) { $cls = if ($suite[0].verdict -eq 'GREEN') { 'pass' } else { 'fail' }; $cells += "<span class='$cls'>$(Enc $suite[0].verdict)</span>" } else { $cells += '&ndash;' }
        $nights = @($vr | ForEach-Object { $_.run_id } | Select-Object -Unique).Count
        $cells += "$nights"
        $rows += , $cells
    }
    Table @('Harness', 'Level 1 Described', 'Level 2 Symptom', 'Level 3 Silent', 'Total fixed', 'Without hints', 'Existing tests', 'Graded nights') $rows
    Add "<p class='muted'>A bug counts as fixed for a version when any of that version's nights graded it PASS. &ldquo;Without hints&rdquo; counts bugs fixed from their original order.</p>"

    Add "<h3>Each bug: the night and the level it was fixed at</h3>"
    $rows = @()
    foreach ($bug in $allBugs) {
        $cells = @($bug, "$($levelOf[$bug])", "<span class='wrap'>$(Enc $titleOf[$bug])</span>")
        foreach ($v in $versions) {
            $first = @($kit | Where-Object { $_.bug -eq $bug -and $_.harness_version -eq $v -and $_.verdict -eq 'PASS' } | Sort-Object date | Select-Object -First 1)
            if ($first.Count) { $cells += "<span class='pass'>PASS</span> $(Enc $first[0].date), level $(Enc $first[0].order_level)" }
            else {
                $last = @($kit | Where-Object { $_.bug -eq $bug -and $_.harness_version -eq $v } | Select-Object -Last 1)
                if ($last.Count) { $cells += "<span class='fail'>$(Enc $last[0].verdict)</span>" } else { $cells += '&ndash;' }
            }
        }
        $rows += , $cells
    }
    Table (@('Bug', 'Level', 'What it is') + $versions) $rows
}

# ---------- 2. Two weeks of work orders ----------
Add "<h2>Work orders: four projects, two weeks</h2>"
$wo = @($orders | Where-Object { $_.phase -eq 'orders' })
$woFilled = @($wo | Where-Object { $_.outcome })
if ($woFilled.Count -eq 0) { Add "<p class='muted'>No results yet. Fill in outcome, parts_first_try, parts_done and minutes in orders.csv after each night.</p>" }
else {
    $done = @($woFilled | Where-Object { IsDone $_ }).Count
    $pt = Sum $woFilled 'parts_total'; $pf = Sum $woFilled 'parts_first_try'; $pd = Sum $woFilled 'parts_done'; $mins = Sum $woFilled 'minutes'
    $perPart = $null; if ($pd) { $perPart = $mins / $pd }
    Add "<div class='cards'>"
    Add "<div class='card'><b>$done / $($woFilled.Count)</b><span>orders done</span></div>"
    Add "<div class='card'><b>$(Pct $pf $pt)</b><span>parts passed on the first try</span></div>"
    Add "<div class='card'><b>$(Pct $pd $pt)</b><span>parts done in the end</span></div>"
    Add "<div class='card'><b>$(Num1 $perPart)</b><span>minutes per finished part</span></div>"
    Add "</div>"
    foreach ($group in @(@{ Field = 'project'; Title = 'By project'; Label = 'Project' }, @{ Field = 'type'; Title = 'By order type'; Label = 'Order type' })) {
        Add "<h3>$($group.Title)</h3>"
        $rows = @()
        foreach ($g in ($woFilled | Group-Object -Property $group.Field | Sort-Object Name)) {
            $gd = @($g.Group | Where-Object { IsDone $_ }).Count
            $gt = Sum $g.Group 'parts_total'; $gf = Sum $g.Group 'parts_first_try'; $gp = Sum $g.Group 'parts_done'; $gm = Sum $g.Group 'minutes'
            $mpp = $null; if ($gp) { $mpp = $gm / $gp }
            $rows += , @((Enc $g.Name), "$gd / $($g.Count)$(Bar $gd $g.Count)", "$(Pct $gf $gt)$(Bar $gf $gt)", (Num1 $mpp))
        }
        Table @($group.Label, 'Orders done', 'First-try parts', 'Min per part') $rows
    }
    Add "<h3>Why orders did not finish</h3>"
    $rows = @()
    foreach ($g in (@($woFilled | Where-Object { -not (IsDone $_) }) | Group-Object -Property cause | Sort-Object Count -Descending)) {
        $name = $g.Name; if (-not $name) { $name = '(no cause given)' }
        $rows += , @((Enc $name), "$($g.Count)")
    }
    if ($rows.Count) { Table @('Cause', 'Orders') $rows } else { Add "<p>Every order finished.</p>" }
}

# ---------- 3. Every night ----------
Add "<h2>Every night</h2>"
if ($runs.Count -eq 0) { Add "<p class='muted'>No nights recorded yet. Start with .\start-night.ps1.</p>" }
else {
    $rows = @()
    foreach ($r in $runs) {
        $ro = @($orders | Where-Object { $_.run_id -eq $r.run_id -and $_.outcome })
        $rd = @($ro | Where-Object { IsDone $_ }).Count
        $rt = Sum $ro 'parts_total'; $rf = Sum $ro 'parts_first_try'
        $rows += , @((Enc $r.date), (Enc $r.phase), (Enc $r.night), (Enc $r.project), (Enc $r.harness_version), (Enc $r.model_file),
            "MTP $(Enc $r.mtp_on), $(Enc $r.context_tokens)", "$rd / $(Enc $r.orders_queued)", "$(Pct $rf $rt)",
            (Enc $r.night_minutes), (Enc $r.idle_minutes), (Enc $r.minutes_waiting_for_person), (Enc $r.engine_collapses), (Enc $r.write_tokens_per_s), "<span class='wrap'>$(Enc $r.notes)</span>")
    }
    Table @('Date', 'Phase', 'Night', 'Project', 'Harness', 'Model', 'Engine', 'Orders done', 'First-try parts', 'Night min', 'Idle min', 'Waiting min', 'Collapses', 'Write tok/s', 'Notes') $rows
    $idle = Sum $runs 'idle_minutes'; $wait = Sum $runs 'minutes_waiting_for_person'; $coll = Sum $runs 'engine_collapses'
    Add "<p>In total: $(Num1 $idle) idle minutes, $(Num1 $wait) minutes waiting for a person, $(Num1 $coll) engine collapses.</p>"
}

# ---------- 4. Harness changes ----------
Add "<h2>Harness changes</h2>"
if ($changes.Count -eq 0) { Add "<p class='muted'>No changes logged yet. Add a row to changes.csv for each change, with the run or order that showed the need.</p>" }
else {
    $rows = @()
    foreach ($c in $changes) { $rows += , @((Enc $c.change_id), (Enc $c.date), (Enc $c.harness_version), (Enc $c.area), "<span class='wrap'>$(Enc $c.what)</span>", "<span class='wrap'>$(Enc $c.why_data)</span>", "<span class='wrap'>$(Enc $c.expected)</span>", "<span class='wrap'>$(Enc $c.measured_after)</span>") }
    Table @('Change', 'Date', 'Version', 'Area', 'What', 'Why (data)', 'Expected', 'Measured after') $rows
}

Add "</main></body></html>"
[System.IO.File]::WriteAllText($Out, $sb.ToString(), $script:Utf8Bom)
Write-Host "Wrote $Out"
