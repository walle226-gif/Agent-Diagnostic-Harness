# Two weeks of work orders for harness data

Four new projects in four languages, built from a skeleton and then grown night by night. The goal is data: how the harness and the model behave on new code, on growing existing code, and in two languages the agent has not been measured on yet (C# and Go).

## The projects

| | Project | Language | What it is | Project check | Install before the skeleton |
|---|---|---|---|---|---|
| A | Ledger | C# (.NET 8) | Bookkeeping for a small Swedish company: vouchers, VAT, SIE 4, year-end | `dotnet test` | .NET 8 SDK |
| B | Gridcalc | TypeScript (Node 20+) | Spreadsheet engine with formulas, dependency graph and a small web page | `npm test` | Node.js 20+ (already used) |
| C | Logwatch | Python 3.12 | Log analysis: parsers, SQLite, anomalies, reports, alerts | `python -m pytest -q` | Python 3.12 (already used) |
| D | Dispatch | Go 1.23+ | Route planning for service technicians: time windows, skills, 2-opt | `go test ./...` | Go 1.23+ |

## Schedule

Estimate: about 20 minutes per part, from the finished parts with MTP. New languages and later nights on larger code will likely be slower; that difference is part of the data.

| Night | Project | Folder | Orders | Parts | Estimate |
|---|---|---|---|---|---|
| 01 | Ledger | `A Ledger (CSharp)/Night 01` (orders 01–09) | 9 | 24 | ~8.0 h |
| 02 | Gridcalc | `B Gridcalc (TypeScript)/Night 02` (orders 01–10) | 10 | 24 | ~8.0 h |
| 03 | Logwatch | `C Logwatch (Python)/Night 03` (orders 01–09) | 9 | 26 | ~8.7 h |
| 04 | Dispatch | `D Dispatch (Go)/Night 04` (orders 01–11) | 11 | 24 | ~8.0 h |
| 05 | Ledger | `A Ledger (CSharp)/Night 05` (orders 10–18) | 9 | 24 | ~8.0 h |
| 06 | Gridcalc | `B Gridcalc (TypeScript)/Night 06` (orders 11–19) | 9 | 24 | ~8.0 h |
| 07 | Logwatch | `C Logwatch (Python)/Night 07` (orders 10–20) | 11 | 24 | ~8.0 h |
| 08 | Dispatch | `D Dispatch (Go)/Night 08` (orders 12–22) | 11 | 24 | ~8.0 h |
| 09 | Ledger | `A Ledger (CSharp)/Night 09` (orders 19–27) | 9 | 26 | ~8.7 h |
| 10 | Gridcalc | `B Gridcalc (TypeScript)/Night 10` (orders 20–28) | 9 | 24 | ~8.0 h |
| 11 | Logwatch | `C Logwatch (Python)/Night 11` (orders 21–31) | 11 | 24 | ~8.0 h |
| 12 | Dispatch | `D Dispatch (Go)/Night 12` (orders 23–33) | 11 | 24 | ~8.0 h |
| 13 | Ledger | `A Ledger (CSharp)/Night 13` (orders 28–36) | 9 | 24 | ~8.0 h |
| 14 | Gridcalc | `B Gridcalc (TypeScript)/Night 14` (orders 29–37) | 9 | 24 | ~8.0 h |
| | **Total** | | **137** | **340** | **~113 h** |

Each project's skeleton is sent in the daytime before its first night: A before night 01, B before 02, C before 03, D before 04.

## How to run it

1. **Daytime, once per project:** make an empty folder, `git init`, open it in Varde and send `00 Skeleton - <name>.txt`. Watch it, because the skeleton installs packages and may ask for approval. Check that the project check is green, then commit.
2. **Evening:** copy that night's `Night NN` files into the project's inbox. Check that Keep going is on and press Run.
3. **Morning:** fill in one row of `nightly-log.csv` and read the set-aside orders.
4. **Do not edit an order to suit the agent once the run has started.** A failed order is data. Write a new order instead, outside this set.

## Built into every order

- Now / Should / Parts with Done when, as in *How to write a work order*.
- The red-first line: "Every part's new test must fail on today's code and pass after the part."
- Structure-only orders (one per project, on its third night) replace that line with a note, because the existing tests are their check. Swap in your own opt-out wording if your harness expects a specific line.
- The rules line: "Rules: Work only inside this project folder. Do not add, remove or update packages. Keep every existing test green and the full test run under 2 minutes. Throwaway scripts go in _scratch/, which git ignores; do not commit them." Swap in your standard rules line if you have one.
- **No new packages after the skeleton.** A package install needs the network and your approval, which would stop a night.
- **Test runs stay under 2 minutes**, with performance tests kept small and benchmarks off by default, because the suite runs after every step.
- **`_scratch/` in every project**, ignored by git, for throwaway scripts. It avoids both the temp-folder approval stop and committed probe files.

## What the set is designed to show

- **New code vs growing code:** each project's first night builds on a small skeleton; later nights work in code the agent wrote earlier.
- **Unfamiliar languages:** C# (Ledger) and Go (Dispatch) are new to your measurements.
- **Order types**, tagged in `orders-index.csv`: feature, edge, format, performance, concurrency, migration, security, refactor, ui, ux, testing, docs. Compare finished parts and minutes per part by type.
- **Known traps on purpose:** Windows paths and encodings, the October clock change, code page 437 in SIE files, multiprocessing on Windows, large files, two processes writing at once.

## Files

- `<project>/00 Skeleton - <name>.txt`: the first prompt for each project.
- `<project>/Night NN/*.txt`: the work orders, numbered per project.
- `orders-index.csv`: every order with night, type, parts and red-first status (semicolon separated, opens in Swedish Excel).
- `nightly-log.csv`: an empty log with one column per measurement, to fill in each morning.
