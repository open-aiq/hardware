#!/usr/bin/env bash
# Regenerate a board's outputs from the command line. It runs the same KiCad jobset
# (<board>.kicad_jobset) that you can run from KiCad's GUI, then adds what KiCad
# can't make on its own: a zipped Gerber set, a JLCPCB-format placement file, and
# 3D renders.
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

# The 3D renders as A4 pages, laid out by typst (scripts/renders.typ)
if [ -f "renders/$name-iso.png" ]; then
  here="$(pwd)"
  title="$(sed -n 's/.*(title "\(.*\)").*/\1/p' "$name.kicad_pcb" | head -1)"
  rev="$(sed -n 's/.*(rev "\(.*\)").*/\1/p' "$name.kicad_pcb" | head -1)"
  typst compile --root "$root" --input "dir=${here#"$root"/}" --input "name=$name" \
    --input "title=$title" --input "rev=$rev" \
    "$root/scripts/renders.typ" "$name-renders.pdf"
fi

# One printable PDF: the schematic (which KiCad writes as $name.pdf), the board
# drawings, then the 3D renders, all A4. Needs qpdf, or Python with pypdf.
parts=()
for f in "$name.pdf" "$name-assembly.pdf" "$name-top.pdf" "$name-bottom.pdf" "$name-renders.pdf"; do
  [ -f "$f" ] && parts+=("$f")
done
if [ "${#parts[@]}" -gt 1 ]; then
  if command -v qpdf >/dev/null 2>&1; then
    qpdf --empty --pages "${parts[@]}" -- "$name-merged.pdf"
  elif python3 -c "import pypdf" 2>/dev/null; then
    python3 - "$name-merged.pdf" "${parts[@]}" <<'PY'
import sys
from pypdf import PdfWriter
w = PdfWriter()
for part in sys.argv[2:]:
    w.append(part)
w.write(sys.argv[1])
PY
  else
    echo "error: merging the PDFs needs qpdf (brew install qpdf) or pypdf (pip install pypdf)" >&2
    exit 1
  fi
  rm -f "${parts[@]}"
  mv "$name-merged.pdf" "$name.pdf"
fi

echo "Exported $name: $name.pdf (schematic, board drawings and 3D renders), fab/, renders/"
