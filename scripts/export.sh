#!/usr/bin/env bash
# Regenerate a board's outputs: schematic PDF, BOM, Gerbers + drill, JLCPCB BOM/CPL (if the
# schematic has LCSC numbers), and 3D renders. RENDER_ZOOM sets the camera zoom.
# Usage: scripts/export.sh pcb/proto2
# Needs kicad-cli (KiCad 10). Set KICAD_CLI if it isn't on your PATH.
set -euo pipefail

dir="${1:?usage: scripts/export.sh pcb/<board>}"
name="$(basename "$dir")"
cli="${KICAD_CLI:-kicad-cli}"
cd "$dir"

"$cli" sch erc --severity-error --exit-code-violations -o /dev/null "$name.kicad_sch"
"$cli" pcb drc --schematic-parity --refill-zones --severity-error --exit-code-violations -o /dev/null "$name.kicad_pcb"

"$cli" sch export pdf -o "$name-schematic.pdf" "$name.kicad_sch"

rm -rf fab && mkdir -p fab/gerbers
"$cli" sch export bom --fields 'Reference,Value,Footprint,${QUANTITY},LCSC,Datasheet' \
  --labels 'Reference,Value,Footprint,Qty,LCSC,Datasheet' --group-by Value,Footprint \
  --exclude-dnp -o "fab/$name-bom.csv" "$name.kicad_sch"
"$cli" pcb export gerbers --layers F.Cu,B.Cu,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts \
  --subtract-soldermask --no-x2 --no-netlist -o fab/gerbers/ "$name.kicad_pcb"
"$cli" pcb export drill --format excellon --excellon-separate-th --generate-map --map-format gerberx2 \
  -o fab/gerbers/ "$name.kicad_pcb"
(cd fab/gerbers && zip -q "../$name-gerbers.zip" ./*)

# Assembly files for boards with LCSC part numbers (JLCPCB's BOM and CPL formats)
if grep -q '"LCSC"' "$name.kicad_sch"; then
  "$cli" pcb export pos --format csv --units mm --side both --exclude-dnp -o "fab/$name-pos.csv" "$name.kicad_pcb"
  python3 - "$name" <<'PY'
import csv, sys
name = sys.argv[1]
with open(f"fab/{name}-bom.csv") as f, open(f"fab/{name}-jlc-bom.csv", "w", newline="") as o:
    w = csv.writer(o); w.writerow(["Comment", "Designator", "Footprint", "LCSC Part #"])
    for r in csv.DictReader(f):
        if r["LCSC"]:
            w.writerow([r["Value"], r["Reference"], r["Footprint"].split(":")[-1], r["LCSC"]])
with open(f"fab/{name}-pos.csv") as f, open(f"fab/{name}-jlc-cpl.csv", "w", newline="") as o:
    w = csv.writer(o); w.writerow(["Designator", "Mid X", "Mid Y", "Layer", "Rotation"])
    for r in csv.DictReader(f):
        w.writerow([r["Ref"], f'{r["PosX"]}mm', f'{r["PosY"]}mm', "Top" if r["Side"] == "top" else "Bottom", r["Rot"]])
PY
fi

mkdir -p renders
zoom="${RENDER_ZOOM:-0.95}"
render() { "$cli" pcb render --quality high --floor --background opaque -w 1800 -h 1200 "$@" "$name.kicad_pcb" >/dev/null; }
render --perspective --rotate '-40,0,25' --zoom "$zoom" -o "renders/$name-iso.png"
render --zoom "$zoom" -o "renders/$name-top.png"
render --side bottom --zoom "$zoom" -o "renders/$name-bottom.png"

echo "Exported $name: schematic PDF, fab/, renders/"
