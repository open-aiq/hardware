#!/usr/bin/env bash
# Regenerate a board's outputs: schematic PDF, BOM, Gerbers + drill, and 3D renders.
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

mkdir -p renders
render() { "$cli" pcb render --quality high --floor --background opaque -w 1800 -h 1200 "$@" "$name.kicad_pcb" >/dev/null; }
render --perspective --rotate '-40,0,25' --zoom 0.9 -o "renders/$name-iso.png"
render --zoom 0.95 -o "renders/$name-top.png"
render --side bottom --zoom 0.95 -o "renders/$name-bottom.png"

echo "Exported $name: schematic PDF, fab/, renders/"
