import csv, os, re, shutil, sys
SRC = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
RULES = ("Rules: Work only inside this project folder. Do not add, remove or update packages. "
         "Keep every existing test green and the full test run under 2 minutes. "
         "Throwaway scripts go in _scratch/, which git ignores; do not commit them.")
REDFIRST = "Every part's new test must fail on today's code and pass after the part."
PROJECTS = {
  "A": ("Ledger", "CSharp", "A Ledger (CSharp)", {1: 1, 2: 5, 3: 9, 4: 13}),
  "B": ("Gridcalc", "TypeScript", "B Gridcalc (TypeScript)", {1: 2, 2: 6, 3: 10, 4: 14}),
  "C": ("Logwatch", "Python", "C Logwatch (Python)", {1: 3, 2: 7, 3: 11}),
  "D": ("Dispatch", "Go", "D Dispatch (Go)", {1: 4, 2: 8, 3: 12}),
}
MIN_PER_PART = 20

def parse_orders(path):
    orders, cur = [], None
    for raw in open(path, encoding="utf-8").read().splitlines():
        line = raw.rstrip()
        if line.startswith("=== "):
            oid, pnight, otype, title = [x.strip() for x in line[4:].split("|")]
            cur = dict(id=oid, pnight=int(pnight), type=otype, title=title, now=None, should=None, parts=[], note=None)
            orders.append(cur)
        elif not line:
            continue
        else:
            key, _, val = line.partition(": ")
            if key == "Now": cur["now"] = val
            elif key == "Should": cur["should"] = val
            elif key == "P": cur["parts"].append([val, None])
            elif key == "D":
                assert cur["parts"] and cur["parts"][-1][1] is None, (cur["id"], line)
                cur["parts"][-1][1] = val
            elif key == "N": cur["note"] = val
            else: raise SystemExit(f"bad line in {cur['id']}: {line}")
    for o in orders:
        assert o["now"] and o["should"] and o["parts"], o["id"]
        assert all(p and d for p, d in o["parts"]), o["id"]
        assert 1 <= len(o["parts"]) <= 3, o["id"]
    return orders

def safe(name):
    return re.sub(r'[<>:"/\\|?*]', "", name).strip()

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write(text if text.endswith("\n") else text + "\n")

def order_text(o):
    out = [o["title"], "", "Now: " + o["now"], "", "Should: " + o["should"], ""]
    for i, (p, d) in enumerate(o["parts"], 1):
        out += [f"Part {i}: {p}", f"Done when: {d}", ""]
    out.append(o["note"] if o["note"] else REDFIRST)
    out.append(RULES)
    return "\n".join(out)

# skeletons
skel = {}
for block in open(os.path.join(SRC, "skeletons.txt"), encoding="utf-8").read().split("=== ")[1:]:
    head, _, body = block.partition("\n")
    letter, name, lang, check = [x.strip() for x in head.split("|")]
    skel[letter] = dict(name=name, lang=lang, check=check, body=body.strip())

if os.path.exists(OUT): shutil.rmtree(OUT)
index, nights = [], {}
for letter, (name, lang, folder, nmap) in PROJECTS.items():
    s = skel[letter]
    write(os.path.join(OUT, folder, f"00 Skeleton - {name}.txt"), s["body"])
    for num, o in enumerate(parse_orders(os.path.join(SRC, f"orders_{letter.lower()}.txt")), 1):
        night = nmap[o["pnight"]]
        fname = f"{num:02d} {safe(o['title'])}.txt"
        write(os.path.join(OUT, folder, f"Night {night:02d}", fname), order_text(o))
        index.append(dict(night=night, project=name, language=lang, order=f"{num:02d}", title=o["title"],
                          type=o["type"], parts=len(o["parts"]), red_first="no (structure only)" if o["note"] else "yes",
                          project_night=o["pnight"], file=f"{folder}/Night {night:02d}/{fname}"))
        nights.setdefault(night, dict(project=name, folder=folder, lang=lang, orders=0, parts=0, first=None, last=None))
        n = nights[night]; n["orders"] += 1; n["parts"] += len(o["parts"])
        n["first"] = n["first"] or f"{num:02d}"; n["last"] = f"{num:02d}"

index.sort(key=lambda r: (r["night"], r["order"]))
with open(os.path.join(OUT, "orders-index.csv"), "w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(index[0].keys()), delimiter=";"); w.writeheader(); w.writerows(index)
# The nightly log lives in ../track-record (runs.csv), shared with the company-code kit.

# README
L = []
L.append("# Two weeks of work orders for harness data\n")
L.append("Four new projects in four languages, built from a skeleton and then grown night by night. "
         "The goal is data: how the harness and the model behave on new code, on growing existing code, "
         "and in two languages the agent has not been measured on yet (C# and Go).\n")
L.append("## The projects\n")
L.append("| | Project | Language | What it is | Project check | Install before the skeleton |")
L.append("|---|---|---|---|---|---|")
what = {"A": "Bookkeeping for a small Swedish company: vouchers, VAT, SIE 4, year-end", "B": "Spreadsheet engine with formulas, dependency graph and a small web page",
        "C": "Log analysis: parsers, SQLite, anomalies, reports, alerts", "D": "Route planning for service technicians: time windows, skills, 2-opt"}
need = {"A": ".NET 8 SDK", "B": "Node.js 20+ (already used)", "C": "Python 3.12 (already used)", "D": "Go 1.23+"}
for letter, (name, lang, folder, nmap) in PROJECTS.items():
    L.append(f"| {letter} | {name} | {skel[letter]['lang']} | {what[letter]} | `{skel[letter]['check']}` | {need[letter]} |")
L.append("")
L.append("## Schedule\n")
L.append(f"Estimate: about {MIN_PER_PART} minutes per part, from the finished parts with MTP. "
         "New languages and later nights on larger code will likely be slower; that difference is part of the data.\n")
L.append("| Night | Project | Folder | Orders | Parts | Estimate |")
L.append("|---|---|---|---|---|---|")
tot_o = tot_p = 0
for night in sorted(nights):
    n = nights[night]; tot_o += n["orders"]; tot_p += n["parts"]
    h = n["parts"] * MIN_PER_PART / 60
    L.append(f"| {night:02d} | {n['project']} | `{n['folder']}/Night {night:02d}` (orders {n['first']}–{n['last']}) | {n['orders']} | {n['parts']} | ~{h:.1f} h |")
L.append(f"| | **Total** | | **{tot_o}** | **{tot_p}** | **~{tot_p*MIN_PER_PART/60:.0f} h** |\n")
L.append("Each project's skeleton is sent in the daytime before its first night: A before night 01, B before 02, C before 03, D before 04.\n")
L.append("## How to run it\n")
L.append("1. **Daytime, once per project:** make an empty folder, `git init`, open it in Varde and send `00 Skeleton - <name>.txt`. "
         "Watch it, because the skeleton installs packages and may ask for approval. Check that the project check is green, then commit.")
L.append("2. **Evening:** copy that night's `Night NN` files into the project's inbox. Check that Keep going is on and press Run.")
L.append("3. **Morning:** record the night with `track-record\\end-night.ps1` and fill in its rows in `track-record\\orders.csv` (see `../track-record/README.md`; start each night with `start-night.ps1`). Then read the set-aside orders.")
L.append("4. **Do not edit an order to suit the agent once the run has started.** A failed order is data. Write a new order instead, outside this set.\n")
L.append("## Built into every order\n")
L.append("- Now / Should / Parts with Done when, as in *How to write a work order*.")
L.append(f"- The red-first line: \"{REDFIRST}\"")
L.append("- Structure-only orders (one per project, on its third night) replace that line with a note, because the existing tests are their check. "
         "Swap in your own opt-out wording if your harness expects a specific line.")
L.append(f"- The rules line: \"{RULES}\" Swap in your standard rules line if you have one.")
L.append("- **No new packages after the skeleton.** A package install needs the network and your approval, which would stop a night.")
L.append("- **Test runs stay under 2 minutes**, with performance tests kept small and benchmarks off by default, because the suite runs after every step.")
L.append("- **`_scratch/` in every project**, ignored by git, for throwaway scripts. It avoids both the temp-folder approval stop and committed probe files.\n")
L.append("## What the set is designed to show\n")
L.append("- **New code vs growing code:** each project's first night builds on a small skeleton; later nights work in code the agent wrote earlier.")
L.append("- **Unfamiliar languages:** C# (Ledger) and Go (Dispatch) are new to your measurements.")
L.append("- **Order types**, tagged in `orders-index.csv`: feature, edge, format, performance, concurrency, migration, security, refactor, ui, ux, testing, docs. "
         "Compare finished parts and minutes per part by type.")
L.append("- **Known traps on purpose:** Windows paths and encodings, the October clock change, code page 437 in SIE files, "
         "multiprocessing on Windows, large files, two processes writing at once.\n")
L.append("## Files\n")
L.append("- `<project>/00 Skeleton - <name>.txt`: the first prompt for each project.")
L.append("- `<project>/Night NN/*.txt`: the work orders, numbered per project.")
L.append("- `orders-index.csv`: every order with night, type, parts and red-first status (semicolon separated, opens in Swedish Excel).")
L.append("- The nightly log lives in `../track-record/`, shared with the company-code kit, so all phases end up in one report.")
write(os.path.join(OUT, "README.md"), "\n".join(L))
print("orders", tot_o, "parts", tot_p)
for night in sorted(nights):
    n = nights[night]; print(f"night {night:02d} {n['project']:9s} orders {n['orders']} parts {n['parts']} ~{n['parts']*MIN_PER_PART/60:.1f}h")
