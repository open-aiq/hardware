#!/usr/bin/env bash
# Regenerate a board's outputs from the command line. It runs the same KiCad jobset
# (<board>.kicad_jobset) that you can run from KiCad's GUI, then adds what KiCad
# can't make on its own: a zipped Gerber set, a JLCPCB-format placement file, 3D
# renders and one printable PDF.
#
# The PDF has, in order: the schematic, the copper prints (1:1), a drill map, the
# board's hand assembly guide (<board>-guide.typ, if there is one), the BOM and
# placement (CPL) tables, and the three 3D renders (iso, top, bottom), each on
# its own A4 page.
#
# A board can come in variants, such as plated (pth) and unplated (npth). The
# jobset then writes each variant's Gerbers to fab/<variant>/gerbers/ and its
# copper prints to <board>-<variant>-copper-*.pdf, and you get one zip
# (fab/<variant>/<board>-<variant>-gerbers.zip) and one PDF (<board>-<variant>.pdf)
# per variant. Without variants it's fab/gerbers/, <board>-bottom.pdf,
# fab/<board>-gerbers.zip and <board>.pdf.
#
# Usage: scripts/export.sh pcb/<board>
# Needs kicad-cli (KiCad 10), typst, and qpdf or pypdf; set KICAD_CLI if
# kicad-cli isn't on your PATH.
# RENDER_ZOOM sets the render camera zoom (default 0.95).
set -euo pipefail

dir="${1:?usage: scripts/export.sh pcb/<board>}"
name="$(basename "$dir")"
cli="${KICAD_CLI:-kicad-cli}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$dir"

# Stop early if we can't merge the PDF at the end
if ! command -v qpdf >/dev/null 2>&1 && ! python3 -c "import pypdf" 2>/dev/null; then
  echo "error: merging the PDF needs qpdf (brew install qpdf) or pypdf (pip install pypdf)" >&2
  exit 1
fi

# Stop early if the design isn't clean
"$cli" sch erc --severity-all --exit-code-violations -o /dev/null "$name.kicad_sch"
"$cli" pcb drc --schematic-parity --refill-zones --severity-all --exit-code-violations -o /dev/null "$name.kicad_pcb"

rm -rf fab checks
# Pages left over from an earlier run would end up in the PDF
rm -f "$name-assembly.pdf" "$name-top.pdf" "$name-bottom.pdf" "$name-drill.pdf" "$name-renders.pdf" \
  "$name-guide.pdf" "$name-tables.pdf" "$name"-*-copper-*.pdf
"$cli" jobset run --stop-on-error -f "$name.kicad_jobset" "$name.kicad_pro"

variants=()
for g in fab/*/gerbers; do
  [ -d "$g" ] && variants+=("$(basename "$(dirname "$g")")")
done
if [ "${#variants[@]}" -gt 0 ]; then
  for v in "${variants[@]}"; do
    (cd "fab/$v/gerbers" && zip -q "../$name-$v-gerbers.zip" ./*)
  done
else
  (cd fab/gerbers && zip -q "../$name-gerbers.zip" ./*)
fi

# JLCPCB wants its own placement (CPL) column names
pos="$(ls fab/*pos*.csv 2>/dev/null | head -1 || true)"
if [ -n "$pos" ]; then
  python3 - "$pos" "fab/$name-jlc-cpl.csv" <<'PY'
import csv, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f, open(dst, "w", newline="") as o:
    w = csv.writer(o); w.writerow(["Designator", "Mid X", "Mid Y", "Layer", "Rotation"])
    for r in csv.DictReader(f):
        w.writerow([r["Ref"], f'{r["PosX"]}mm', f'{r["PosY"]}mm', "Top" if r["Side"] == "top" else "Bottom", r["Rot"]])
PY
fi

# Assembly BOMs for JLCPCB (by LCSC part number) and PCBWay (by manufacturer part
# number), one row per part, from the LCSC, Manufacturer and MPN symbol fields.
# PCBWay takes the same placement file as JLCPCB.
if [ -f "fab/$name-bom.csv" ]; then
  python3 - "fab/$name-bom.csv" "$name.kicad_pcb" "fab/$name-jlc-bom.csv" "fab/$name-pcbway-bom.csv" <<'PY'
import csv, re, sys
src, board, jlc, pcbway = sys.argv[1:]
# Through-hole or SMD, from each footprint's attributes on the board
kind = {}
for fp in re.split(r'\n\t\(footprint ', open(board).read())[1:]:
    ref = re.search(r'\(property "Reference" "([^"]+)"', fp)
    attr = re.search(r'\n\t\t\(attr ([^)]*)\)', fp)
    if ref and attr:
        kind[ref.group(1)] = "SMD" if "smd" in attr.group(1) else "THT"
rows, missing = {}, []
for r in csv.DictReader(open(src, encoding="utf-8")):
    refs = [x.strip() for x in r["Reference"].split(",") if x.strip()]
    if not r.get("LCSC") or not r.get("MPN"):
        missing += refs
        continue
    g = rows.setdefault(r["LCSC"], {"refs": [], "part": r["Part"], "mfr": r["Manufacturer"],
                                    "mpn": r["MPN"], "fps": []})
    g["refs"] += refs
    fp = r["Footprint"].split(":")[-1]
    if fp not in g["fps"]:
        g["fps"].append(fp)
if missing:
    sys.exit(f"error: no LCSC or MPN field on {', '.join(missing)}; add them in the schematic")
natural = lambda ref: (re.sub(r"\d+", "", ref), int(re.sub(r"\D+", "", ref) or 0))
groups = sorted(rows.items(), key=lambda kv: natural(sorted(kv[1]["refs"], key=natural)[0]))
with open(jlc, "w", newline="", encoding="utf-8") as o:
    w = csv.writer(o)
    w.writerow(["Comment", "Designator", "Footprint", "LCSC Part #"])
    for lcsc, g in groups:
        w.writerow([g["part"], ",".join(sorted(g["refs"], key=natural)), " / ".join(g["fps"]), lcsc])
with open(pcbway, "w", newline="", encoding="utf-8") as o:
    w = csv.writer(o)
    w.writerow(["Item #", "Designator", "Qty", "Manufacturer", "Mfg Part #", "Description / Value",
                "Package/Footprint", "Type", "Your Instructions / Notes"])
    for i, (lcsc, g) in enumerate(groups, 1):
        refs = sorted(g["refs"], key=natural)
        types = sorted({kind.get(x, "THT") for x in refs})
        w.writerow([i, ",".join(refs), len(refs), g["mfr"], g["mpn"], g["part"], " / ".join(g["fps"]),
                    "/".join(types), f"LCSC {lcsc} is an exact match"])
PY
fi

here="$(pwd)"
title="$(sed -n 's/.*(title "\(.*\)").*/\1/p' "$name.kicad_pcb" | head -1)"
rev="$(sed -n 's/.*(rev "\(.*\)").*/\1/p' "$name.kicad_pcb" | head -1)"

mkdir -p renders
zoom="${RENDER_ZOOM:-0.95}"
render() { "$cli" pcb render --quality high --floor --background opaque -w 1800 -h 1200 "$@" "$name.kicad_pcb" >/dev/null; }
render --perspective --rotate '-40,0,25' --zoom "$zoom" -o "renders/$name-iso.png"
render --zoom "$zoom" -o "renders/$name-top.png"
render --side bottom --zoom "$zoom" -o "renders/$name-bottom.png"

# The 3D renders as A4 pages, laid out by typst (scripts/renders.typ)
if [ -f "renders/$name-iso.png" ]; then
  typst compile --root "$root" --input "dir=${here#"$root"/}" --input "name=$name" \
    --input "title=$title" --input "rev=$rev" \
    "$root/scripts/renders.typ" "$name-renders.pdf"
fi

# The hand assembly guide, written per board in typst (after the renders, which
# it may show)
if [ -f "$name-guide.typ" ]; then
  typst compile --root "$root" --input "title=$title" --input "rev=$rev" \
    "$name-guide.typ" "$name-guide.pdf"
fi

# The BOM and placement files as tables (scripts/tables.typ)
bom="" cpl=""
[ -f "fab/$name-bom.csv" ] && bom="${here#"$root"/}/fab/$name-bom.csv"
[ -f "fab/$name-jlc-cpl.csv" ] && cpl="${here#"$root"/}/fab/$name-jlc-cpl.csv"
if [ -n "$bom$cpl" ]; then
  typst compile --root "$root" --input "title=$title" --input "rev=$rev" \
    --input "bom=$bom" --input "cpl=$cpl" \
    "$root/scripts/tables.typ" "$name-tables.pdf"
fi

# A drill map: every hole on the board, marked by size, with a legend. The
# jobset already makes a Gerber copy for the fab; this one is for the PDF.
drill_tmp="$(mktemp -d)"
"$cli" pcb export drill --format excellon --generate-map --map-format pdf \
  -o "$drill_tmp/" "$name.kicad_pcb" >/dev/null
mv "$drill_tmp/$name-drl_map.pdf" "$name-drill.pdf"
rm -rf "$drill_tmp"

# One printable PDF per variant: the schematic (which KiCad writes as $name.pdf),
# the copper, the drill map, the assembly guide, the BOM and CPL, then the 3D
# renders, all A4.
merge() {
  local out="$1"; shift
  if command -v qpdf >/dev/null 2>&1; then
    qpdf --empty --pages "$@" -- "$out"
  else
    python3 - "$out" "$@" <<'PY'
import sys
from pypdf import PdfWriter
w = PdfWriter()
for part in sys.argv[2:]:
    w.append(part)
w.write(sys.argv[1])
PY
  fi
}
# The pages that exist, in order, with the given copper prints
pages() {
  local f
  for f in "$name.pdf" "$@" "$name-drill.pdf" "$name-guide.pdf" "$name-tables.pdf" "$name-renders.pdf"; do
    if [ -f "$f" ]; then echo "$f"; fi
  done
}
if [ "${#variants[@]}" -gt 0 ]; then
  made=()
  for v in "${variants[@]}"; do
    copper=()
    for f in "$name-$v"-copper-*.pdf; do
      [ -f "$f" ] && copper+=("$f")
    done
    parts=()
    while IFS= read -r f; do parts+=("$f"); done < <(pages ${copper[@]+"${copper[@]}"})
    merge "$name-$v.pdf" "${parts[@]}"
    rm -f ${copper[@]+"${copper[@]}"}
    made+=("$name-$v.pdf")
  done
  rm -f "$name.pdf" "$name-drill.pdf" "$name-guide.pdf" "$name-tables.pdf" "$name-renders.pdf"
  echo "Exported $name: ${made[*]} (schematic, copper, drill map, assembly guide, BOM, CPL and 3D renders), fab/, renders/"
else
  parts=()
  while IFS= read -r f; do parts+=("$f"); done < <(pages "$name-bottom.pdf")
  if [ "${#parts[@]}" -gt 1 ]; then
    merge "$name-merged.pdf" "${parts[@]}"
    rm -f "${parts[@]}"
    mv "$name-merged.pdf" "$name.pdf"
  fi
  echo "Exported $name: $name.pdf (schematic, bottom copper, drill map, assembly guide, BOM, CPL and 3D renders), fab/, renders/"
fi
