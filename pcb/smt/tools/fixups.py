#!/usr/bin/env python3
"""Board fix-ups after placement. Run with KiCad's Python: python fixups.py smt.kicad_pcb smt.kicad_sch
- copy each symbol's LCSC field onto its footprint (JLCPCB assembly reads it)
- enlarge the module's 0.2 mm thermal vias to 0.3 mm (JLCPCB standard 2-layer minimum)
- hide R/C, connector and switch references on the silkscreen (labels name them)"""
import re, sys
import pcbnew as P

board_path, net_path = sys.argv[1], sys.argv[2]
sch = open(net_path).read()   # the generated .kicad_sch
lcsc, datasheet = {}, {}
for blk in re.findall(r'\(symbol \(lib_id .*?\(instances', sch, re.S):
    ref = re.search(r'\(property "Reference" "([^"]+)"', blk).group(1)
    m = re.search(r'\(property "LCSC" "([^"]+)"', blk)
    if m:
        lcsc[ref] = m.group(1)
    d = re.search(r'\(property "Datasheet" "(http[^"]+)"', blk)
    if d:
        datasheet[ref] = d.group(1)

b = P.LoadBoard(board_path)
for fp in b.GetFootprints():
    ref = fp.GetReference()
    if ref in lcsc:
        fp.SetField("LCSC", lcsc[ref])
        for f in fp.GetFields():
            if f.GetName() == "LCSC":
                f.SetVisible(False); f.SetLayer(P.F_Fab)
    if ref in datasheet:
        for f in fp.GetFields():
            if f.GetName() == "Datasheet":
                f.SetText(datasheet[ref])
    if (ref[0] in "RC" and ref[1:].isdigit()) or ref.startswith(("J", "SW")):
        fp.Reference().SetVisible(False)
    if ref == "U3":
        for pad in fp.Pads():
            if pad.GetAttribute() == P.PAD_ATTRIB_PTH and P.ToMM(pad.GetDrillSizeX()) < 0.3:
                pad.SetDrillSize(P.VECTOR2I(P.FromMM(0.3), P.FromMM(0.3)))
                pad.SetSize(P.VECTOR2I(P.FromMM(0.6), P.FromMM(0.6)))
P.SaveBoard(board_path, b)
print("LCSC fields:", len(lcsc))
