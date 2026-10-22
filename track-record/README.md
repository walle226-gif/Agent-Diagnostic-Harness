# Track record

One record for everything the agent runs: the company-code kit, the hint nights, the two weeks of work orders, and the kit again after the harness improvements. Every row is tied to the harness version, model and engine settings that produced it, so results from different weeks can be compared fairly.

## The plan it is built for

| Phase | Name in the record | Nights | Harness |
|---|---|---|---|
| Company-code kit, 14 orders | `kit-1` | 2 | `harness-v1` |
| Hint ladder: unfixed bugs, one level clearer | `kit-hints` | 1–2 | `harness-v1` |
| Two weeks of work orders | `orders` | 14 | `harness-v1` |
| Improve the harness from the data | | daytime | becomes `harness-v2` |
| Company-code kit again, from a fresh setup | `kit-2` | 2–4 | `harness-v2` |

The report puts `harness-v1` and `harness-v2` side by side on the same 15 bugs. That is the before and after.

## Rules that keep the record trustworthy

1. **Tag the harness before each phase:** `git tag harness-v1` in the harness repository. `start-night.ps1` refuses to start if the harness has uncommitted changes.
2. **Freeze the harness during a phase.** Fix only crashes, commit them, and log each fix in `changes.csv`.
3. **Don't edit an order once the night has started.** A failed order is data.
4. **Grade every bug on every kit night.** A silent bug fixed by accident also counts.

## Each night

**Evening**, just before you press Run:

```powershell
# Company-code kit, first night
.\start-night.ps1 -Phase kit-1 -Night 1 -HarnessRepo C:\varde -Model C:\models\bonsai-2-27b.gguf `
    -EngineBuild b10777 -Mtp on -Context 131072 -KitPath C:\kits\bitwarden-kit -Orders (1..7)

# Second night: -Night 2 -Orders (8..14)

# Hint night: pass the clearer orders you queued
.\start-night.ps1 -Phase kit-hints -Night 1 ... -HintFiles 'C:\kits\bitwarden-kit\hints\bug 13 - level 2 Symptom only - Someone joined with an unverified e-mail address.txt'

# Two weeks of work orders: night 1 to 14, the orders come from work-orders\orders-index.csv
.\start-night.ps1 -Phase orders -Night 1 -HarnessRepo C:\varde -Model C:\models\bonsai-2-27b.gguf -EngineBuild b10777 -Mtp on -Context 131072
```

It records the harness version, model and engine settings, and adds tonight's orders to `orders.csv`.

**Morning**, about 5 minutes:

1. Kit nights only: commit the agent's work and run `grade.ps1` from the kit.
2. `.\end-night.ps1`. It asks for last night's numbers (Enter skips one). On kit nights add `-KitPath C:\kits\bitwarden-kit` to import the newest grade file. On hint nights also add `-HintLevels "13=2,11=1"`: the level each hinted bug was given. `-LogPath` copies the harness's night log into `logs\`.
3. Open `orders.csv` and fill in the night's rows: `outcome`, `parts_first_try`, `parts_done`, `minutes`, `cause`.
4. `.\report.ps1` and open `track-record.html`.

**When you change the harness**, add a row to `changes.csv`: what changed, the run or order that showed the need (`why_data`), and what you expect to improve. Fill in `measured_after` once `kit-2` has run.

## Words to use in orders.csv

Fixed words make the report's counts work.

- **outcome:** `done`, `partial`, `set-aside`, `stalled`, `not-started`
- **cause** (when not done): `wrong-fix`, `test-not-red`, `broke-tests`, `stalled-loop`, `engine`, `harness`, `timeout`, `approval-stop`, `gave-up`, `other`

## Files

| File | One row per | Filled by |
|---|---|---|
| `runs.csv` | night | `start-night.ps1` in the evening, `end-night.ps1` in the morning |
| `orders.csv` | order per night | `start-night.ps1` adds the rows, you fill in the results |
| `bugs.csv` | kit bug per kit night | `end-night.ps1` from the kit's `grade-*.csv` |
| `changes.csv` | harness change | you |
| `track-record.html` | | `report.ps1` |
| `logs\<run>\` | night | `end-night.ps1 -LogPath` |

`runs.csv` holds every column of the old `nightly-log.csv`, plus the phase, harness version, model and idle minutes.

## Good to know

- **Excel:** the files are semicolon separated with UTF-8, so Swedish Excel opens them directly. When you save, choose **CSV UTF-8**, or å, ä and ö can break. Excel turns `01` into `1`; the report handles that.
- **Automation:** the harness can call `end-night.ps1 -Set "orders_finished_clean=7;parts_first_try=18;night_minutes=545"` at the end of a night, so the morning only needs `orders.csv`.
- **Works in** Windows PowerShell 5.1 and PowerShell 7.
- **What the report shows:**
  - the kit score per harness version and level, and each bug's night and level of fix;
  - work orders by project and type: first-try parts and minutes per part;
  - why orders failed;
  - every night's settings and idle time;
  - the change log.
