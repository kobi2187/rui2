#!/usr/bin/env python3
"""compare.py <cases.json> <flutter.json> <rui.json> <out-dir>

Puts every case in one of these, worst first:

  mismatch       both laid it out; some node's rect differs (by more than
                 0.5 px, or 2 px for text cases)
  inexpressible  RUI cannot say it: the runner names the widget/prop
  silent         Flutter reports a layout error (unbounded flex, misuse); RUI
                 lays it out without a word
  rui-error      RUI raised while laying it out
  match          every node within tolerance (overflow cases included: what
                 matters is where things land)

Writes report.md (a table per status, the worst nodes of each mismatch) and,
for each mismatch, pictures/<case>.png: Flutter left, RUI right, leaves
filled, containers outlined, and the nodes that differ in red.
"""
import json
import os
import re
import sys
from PIL import Image, ImageDraw

cases_path, flutter_path, rui_path, out = sys.argv[1:5]
cases = json.load(open(cases_path))["cases"]
fl = json.load(open(flutter_path))
ru = json.load(open(rui_path))


def finite(v):
    # Nim writes NaN and infinities as strings; a non-finite rect is a bug to show.
    return float(v) if isinstance(v, str) else v


for res in ru.values():
    res["rects"] = {i: [finite(v) for v in r] for i, r in res.get("rects", {}).items()}
os.makedirs(os.path.join(out, "pictures"), exist_ok=True)

ORDER = ["mismatch", "inexpressible", "silent", "rui-error", "match"]


def nodes(tree):
    yield tree
    for c in tree.get("c", []):
        yield from nodes(c)


def describe(tree):
    """A one-line rendering of the tree: Row(main=end)[Box(40x30), ...]."""
    p = tree.get("p", {})
    if tree["w"] == "Box":
        return f"Box({p.get('width')}x{p.get('height')})"
    if tree["w"] == "Text":
        return "Text(…)"
    args = ",".join(f"{k}={v}" for k, v in p.items() if k != "text")
    kids = tree.get("c", [])
    inner = "[" + ", ".join(describe(k) for k in kids) + "]" if kids else ""
    return f"{tree['w']}({args}){inner}"


def deltas(case, f, r):
    axes = {"xywh": (0, 1, 2, 3), "xw": (0, 2)}[case["compare"]]
    tol = 2.0 if "text" in case["tags"] else 0.5
    out = []
    for nd in nodes(case["tree"]):
        i = nd["id"]
        if i not in f:
            continue                       # Flutter gave it no box (a TableRow, an offstage child)
        if i not in r:
            out.append((float("inf"), i, nd["w"], f[i], None))
            continue
        d = max(abs(f[i][a] - r[i][a]) for a in axes)
        if d != d:
            d = float("inf")               # NaN in RUI's rect
        if d > tol:
            out.append((d, i, nd["w"], f[i], r[i]))
    return sorted(out, key=lambda t: -t[0])


def picture(case, f, r, bad, path):
    W, H = case["size"]
    S = 2 if max(W, H) <= 400 else 1
    img = Image.new("RGB", (2 * W * S + 30, H * S + 24), "white")
    d = ImageDraw.Draw(img)
    leaves = {nd["id"] for nd in nodes(case["tree"]) if not nd.get("c")}
    badset = {b[1] for b in bad}
    for col, (label, rects) in enumerate([("Flutter", f), ("RUI", r)]):
        ox = col * (W * S + 30)
        d.rectangle([ox, 20, ox + W * S - 1, 20 + H * S - 1], outline="#999")
        d.text((ox + 2, 2), label, fill="black")
        for i, (x, y, w, h) in sorted(rects.items(), key=lambda kv: kv[0].count(".")):
            if any(v != v or v in (float("inf"), float("-inf")) for v in (x, y, w, h)):
                d.text((ox + 4, 20 + H * S - 12), f"{i}: not finite", fill="#900")
                continue
            box = [ox + x * S, 20 + y * S, ox + (x + w) * S - 1, 20 + (y + h) * S - 1]
            if box[2] < box[0] or box[3] < box[1]:
                continue
            red = i in badset
            if i in leaves:
                d.rectangle(box, fill="#f4a3a3" if red else "#a8d5a2", outline="#c00" if red else "#2a7")
            else:
                d.rectangle(box, outline="#c00" if red else "#36c", width=2 if red else 1)
            if red:
                d.text((box[0] + 2, box[1] + 2), i, fill="#900")
    img.save(path)


rows = {k: [] for k in ORDER}
for case in cases:
    name = case["name"]
    F, R = fl.get(name, {}), ru.get(name, {})
    ferr = [e for e in F.get("errors", []) if "overflowed" not in e]
    overflow = any("overflowed" in e for e in F.get("errors", []))
    entry = {"case": case, "flutter_errors": F.get("errors", []), "approx": R.get("approx", [])}
    if R.get("inexpressible"):
        entry["why"] = R["inexpressible"]
        rows["inexpressible"].append(entry)
    elif R.get("errors"):
        entry["why"] = "; ".join(R["errors"])
        rows["rui-error"].append(entry)
    elif ferr:
        entry["why"] = ferr[0]
        rows["silent"].append(entry)
    else:
        bad = deltas(case, F.get("rects", {}), R.get("rects", {}))
        entry["overflow"] = overflow
        if bad:
            entry["bad"] = bad
            slug = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
            entry["pic"] = f"pictures/{slug}.png"
            picture(case, F["rects"], R["rects"], bad, os.path.join(out, entry["pic"]))
            rows["mismatch"].append(entry)
        else:
            rows["match"].append(entry)


def fmt(r):
    return "–" if r is None else "[" + ", ".join(f"{v:g}" for v in r) + "]"


total = len(cases)
md = ["# Layout conformance: RUI vs Flutter", "",
      f"{total} cases. " + ", ".join(f"**{len(rows[k])} {k}**" for k in ORDER), "",
      "Generated by mobile/layout_conformance/run.sh. Rects are [x, y, width, height] in "
      "logical pixels; node ids are tree paths (0 = root, 0.1 = its second child).", ""]
by_tag = {}
for k in ORDER:
    for e in rows[k]:
        for t in e["case"]["tags"]:
            by_tag.setdefault(t, {s: 0 for s in ORDER})[k] += 1
md += ["## By area", "", "| tag | " + " | ".join(ORDER) + " |", "|---|" + "---|" * len(ORDER)]
for t in sorted(by_tag):
    md.append(f"| {t} | " + " | ".join(str(by_tag[t][k] or "") for k in ORDER) + " |")
md.append("")

md += ["## Mismatches", ""]
for e in rows["mismatch"]:
    c = e["case"]
    md.append(f"### {c['name']}" + ("  (Flutter: overflow)" if e["overflow"] else ""))
    md.append(f"`{describe(c['tree'])}` in {c['size'][0]}x{c['size'][1]}")
    if c.get("expect"):
        md.append(f"*Flutter:* {c['expect']}")
    if e["approx"]:
        md.append(f"*Approximated in RUI:* {'; '.join(e['approx'])}")
    md += ["", "| node | widget | Flutter | RUI | off by |", "|---|---|---|---|---|"]
    for d, i, w, f, r in e["bad"][:6]:
        md.append(f"| {i} | {w} | {fmt(f)} | {fmt(r)} | {d:g} |")
    md += ["", f"![{c['name']}]({e['pic']})", ""]

md += ["## Inexpressible in RUI", "", "| case | what is missing |", "|---|---|"]
for e in rows["inexpressible"]:
    md.append(f"| {e['case']['name']} | `{e['why']}` |")
md.append("")
md += ["## Flutter rejects, RUI is silent", "",
       "Flutter reports these as errors; RUI lays them out without a word.", "",
       "| case | Flutter says |", "|---|---|"]
for e in rows["silent"]:
    md.append(f"| {e['case']['name']} | {e['why']} |")
md.append("")
if rows["rui-error"]:
    md += ["## RUI errors", ""] + [f"- {e['case']['name']}: {e['why']}" for e in rows["rui-error"]] + [""]
md += ["## Matches", "", ", ".join(e["case"]["name"] for e in rows["match"]), ""]
open(os.path.join(out, "report.md"), "w").write("\n".join(md))
json.dump({k: [e["case"]["name"] for e in rows[k]] for k in ORDER},
          open(os.path.join(out, "summary.json"), "w"), indent=1)
print(" ".join(f"{k}={len(rows[k])}" for k in ORDER))
