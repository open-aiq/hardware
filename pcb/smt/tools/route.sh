#!/usr/bin/env bash
# Autoroute smt.kicad_pcb with Freerouting (GND routed as tracks, then pours added).
# Usage: tools/route.sh   (from pcb/smt). Needs KiCad's Python (KICAD_PY), Java 25 (JAVA) and
# freerouting.jar (FREEROUTING_JAR).
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${KICAD_PY:?KiCad python}"; JAVA="${JAVA:-java}"; JAR="${FREEROUTING_JAR:-$HOME/.kicad-mcp/freerouting.jar}"
tmp="$(mktemp -d)"
"$PY" -I - "$tmp" <<'PYEOF'
import sys, shutil, pcbnew as P
tmp = sys.argv[1]
b = P.LoadBoard("smt.kicad_pcb")
for t in [t for t in b.GetTracks()]: b.Remove(t)
P.SaveBoard("smt.kicad_pcb", b)
shutil.copy("smt.kicad_pcb", f"{tmp}/nozones.kicad_pcb")
PYEOF
"$PY" -I - "$tmp" <<'PYEOF'
import sys, pcbnew as P
tmp = sys.argv[1]
b = P.LoadBoard(f"{tmp}/nozones.kicad_pcb")
for z in [z for z in b.Zones() if not z.GetIsRuleArea()]: b.Remove(z)
P.SaveBoard(f"{tmp}/nozones.kicad_pcb", b)
PYEOF
"$PY" -I -c "import sys,pcbnew as P; b=P.LoadBoard('$tmp/nozones.kicad_pcb'); P.ExportSpecctraDSN(b,'$tmp/smt.dsn')"
"$JAVA" -Djava.awt.headless=true -jar "$JAR" -de "$tmp/smt.dsn" -do "$tmp/smt.ses" -mp 300 --gui.enabled=false 2>&1 \
  | grep -E "stage completed" || true
"$PY" -I -c "import pcbnew as P; b=P.LoadBoard('smt.kicad_pcb'); P.ImportSpecctraSES(b,'$tmp/smt.ses'); P.ZONE_FILLER(b).Fill(b.Zones()); P.SaveBoard('smt.kicad_pcb',b)"
rm -rf "$tmp"
echo "routed"
