#!/usr/bin/env bash
# Regenerate a board's outputs from the command line. It runs the same KiCad jobset
# (<board>.kicad_jobset) that you can run from KiCad's GUI, then adds what KiCad
# can't make on its own: a zipped Gerber set, a JLCPCB-format placement file, and
# 3D renders.
#
# Usage: scripts/export.sh pcb/<board>
# Needs kicad-cli (KiCad 10); set KICAD_CLI if it isn't on your PATH.
# RENDER_ZOOM sets the render camera zoom (default 0.95).
set -euo pipefail

dir="${1:?usage: scripts/export.sh pcb/<board>}"
name="$(basename "$dir")"
cli="${KICAD_CLI:-kicad-cli}"
cd "$dir"

# Stop early if the design isn't clean
"$cli" sch erc --severity-all --exit-code-violations -o /dev/null "$name.kicad_sch"
"$cli" pcb drc --schematic-parity --refill-zones --severity-all --exit-code-violations -o /dev/null "$name.kicad_pcb"

rm -rf fab checks
"$cli" jobset run --stop-on-error -f "$name.kicad_jobset" "$name.kicad_pro"

(cd fab/gerbers && zip -q "../$name-gerbers.zip" ./*)

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

mkdir -p renders
zoom="${RENDER_ZOOM:-0.95}"
render() { "$cli" pcb render --quality high --floor --background opaque -w 1800 -h 1200 "$@" "$name.kicad_pcb" >/dev/null; }
render --perspective --rotate '-40,0,25' --zoom "$zoom" -o "renders/$name-iso.png"
render --zoom "$zoom" -o "renders/$name-top.png"
render --side bottom --zoom "$zoom" -o "renders/$name-bottom.png"

echo "Exported $name: $name.pdf, $name-assembly.pdf, fab/, renders/"
