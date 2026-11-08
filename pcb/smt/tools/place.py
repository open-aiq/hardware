#!/usr/bin/env python3
"""Place parts, draw the outline + SHT30 thermal slot, silkscreen and GND pours.
Run with KiCad's Python:  python place.py smt.kicad_pcb   (re-runnable; tracks are untouched)"""
import sys
import pcbnew as P

path = sys.argv[1]
import subprocess
if "--clear" in sys.argv:
    # Clear previous outline, silkscreen and zones in its own process: pcbnew's SWIG
    # wrappers misbehave if you keep editing (or reload) after Remove().
    b = P.LoadBoard(path)
    for d in [d for d in b.GetDrawings()]:
        if d.GetLayer() in (P.Edge_Cuts, P.F_SilkS, P.B_SilkS):
            b.Remove(d)
    for z in [z for z in b.Zones()]:
        b.Remove(z)
    P.SaveBoard(path, b)
    sys.exit(0)
subprocess.run([sys.executable, "-I", __file__, path, "--clear"], check=True,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
b = P.LoadBoard(path)
OX, OY = 100.0, 60.0
W, H = 56.0, 44.0
mm = lambda x, y: P.VECTOR2I(P.FromMM(OX + x), P.FromMM(OY + y))

place = {   # ref: (x, y, rotation)
    "U3": (30.0, 6.3, 0),      # module; antenna hangs off the top edge
    "H1": (3.0, 3.0, 0), "H2": (53.0, 3.0, 0), "H3": (3.0, 41.0, 0), "H4": (53.0, 41.0, 0),
    # PMS5003 on the left edge, cable enters from the left
    "J2": (4.0, 20.0, 270), "C7": (10.0, 12.5, 90), "R4": (10.5, 25.5, 0), "R5": (10.5, 27.5, 0),
    # EN / RESET and module decoupling
    "SW1": (11.0, 5.0, 0), "C5": (17.6, 1.9, 0), "C6": (17.6, 4.1, 0), "R3": (17.6, 6.3, 0), "C4": (17.6, 8.5, 0),
    # USB-C, ESD, fuse, LDO (bottom left)
    "J1": (20.0, 41.0, 0), "U1": (20.0, 32.0, 0), "R1": (15.8, 33.8, 90), "R2": (24.2, 33.8, 90),
    "F1": (12.8, 39.5, 90), "U2": (7.5, 33.0, 0), "C1": (13.6, 31.5, 90), "C2": (14.6, 25.5, 0), "C3": (14.6, 27.5, 0),
    # right side: BOOT, Qwiic (OLED), I2C pull-ups
    "SW2": (45.0, 16.0, 0), "J3": (52.7, 26.0, 90), "R7": (46.0, 24.0, 0), "R8": (46.0, 26.0, 0),
    # SHT30 island in the bottom-right corner
    "U4": (46.5, 38.5, 0), "C8": (49.9, 37.0, 0), "R6": (45.6, 41.6, 0),
    # user buttons and status LED
    "SW4": (30.5, 39.0, 0), "SW3": (38.0, 39.0, 0), "D1": (35.0, 24.0, 0), "C9": (38.0, 24.0, 0),
}
for ref, (x, y, rot) in place.items():
    fp = b.FindFootprintByReference(ref)
    fp.SetPosition(mm(x, y))
    fp.SetOrientationDegrees(rot)
for h in ("H1", "H2", "H3", "H4"):
    b.FindFootprintByReference(h).Reference().SetVisible(False)

def seg(x1, y1, x2, y2, layer=P.Edge_Cuts, w=0.1):
    s = P.PCB_SHAPE(b, P.SHAPE_T_SEGMENT); s.SetLayer(layer); s.SetWidth(P.FromMM(w))
    s.SetStart(mm(x1, y1)); s.SetEnd(mm(x2, y2)); b.Add(s)
def arc(cx, cy, sx, sy):
    a = P.PCB_SHAPE(b, P.SHAPE_T_ARC); a.SetLayer(P.Edge_Cuts); a.SetWidth(P.FromMM(0.1))
    a.SetCenter(mm(cx, cy)); a.SetStart(mm(sx, sy)); a.SetArcAngleAndEnd(P.EDA_ANGLE(90, P.DEGREES_T), True); b.Add(a)
r = 2.0
seg(r, 0, W - r, 0); seg(W, r, W, H - r); seg(W - r, H, r, H); seg(0, H - r, 0, r)
arc(r, r, 0, r); arc(W - r, r, W - r, 0); arc(W - r, H - r, W, H - r); arc(r, H - r, r, H)

# L-shaped slot that thermally isolates the SHT30 corner
slot = [(42.6, 33.6), (50.0, 33.6), (50.0, 34.6), (43.6, 34.6), (43.6, 37.6), (42.6, 37.6)]
for a, c in zip(slot, slot[1:] + slot[:1]):
    seg(*a, *c)

# Keep traces and vias 0.6 mm away from the slot (the router doesn't see inner cut-outs)
for x1, y1, x2, y2 in ((42.0, 33.0, 50.6, 35.2), (42.0, 33.0, 44.2, 38.2)):
    k = P.ZONE(b); k.SetIsRuleArea(True); k.SetLayerSet(P.LSET.AllCuMask())
    k.SetDoNotAllowTracks(True); k.SetDoNotAllowVias(True); k.SetDoNotAllowPads(False)
    k.SetDoNotAllowZoneFills(False); k.SetDoNotAllowFootprints(False)
    o = k.Outline(); o.NewOutline()
    for x, y in ((x1, y1), (x2, y1), (x2, y2), (x1, y2)):
        o.Append(P.FromMM(OX + x), P.FromMM(OY + y))
    b.Add(k)

def text(t, x, y, size=1.0, layer=P.F_SilkS, bold=False, rot=0):
    tx = P.PCB_TEXT(b); tx.SetText(t); tx.SetLayer(layer); tx.SetPosition(mm(x, y))
    tx.SetTextSize(P.VECTOR2I(P.FromMM(size), P.FromMM(size))); tx.SetTextThickness(P.FromMM(size * 0.15))
    tx.SetBold(bold); tx.SetTextAngleDegrees(rot)
    if layer == P.B_SilkS: tx.SetMirrored(True)
    b.Add(tx)

text("PMS5003", 8.4, 20.0, 0.9, bold=True, rot=90)
text("OLED", 48.6, 30.6, 0.9, bold=True)
text("RESET", 11.0, 9.0, 0.8)
text("BOOT", 45.0, 20.0, 0.8)
text("LEFT", 30.5, 35.2, 0.8, bold=True)
text("RIGHT", 38.0, 35.2, 0.8, bold=True)
text("SHT30", 47.4, 42.9, 0.8)
text("USB-C", 20.0, 36.8 - 1.9, 0.8)
text("Open AIQ", 33.0, 29.5, 1.2, bold=True)
text("SMT rev A", 33.0, 31.4, 0.9)
text("Open AIQ SMT rev A", 28.0, 22.0, 1.2, layer=P.B_SilkS, bold=True)
text("github.com/open-aiq/hardware", 28.0, 24.4, 0.9, layer=P.B_SilkS)

# --- GND pours on both layers
gnd = b.FindNet("GND")
for layer in (P.F_Cu, P.B_Cu):
    z = P.ZONE(b); z.SetLayer(layer); z.SetNet(gnd)
    z.SetLocalClearance(P.FromMM(0.25)); z.SetMinThickness(P.FromMM(0.2))
    z.SetPadConnection(P.ZONE_CONNECTION_THERMAL)
    z.SetThermalReliefGap(P.FromMM(0.4)); z.SetThermalReliefSpokeWidth(P.FromMM(0.4))
    ol = z.Outline(); ol.NewOutline()
    for x, y in ((0.3, 0.3), (W - 0.3, 0.3), (W - 0.3, H - 0.3), (0.3, H - 0.3)):
        ol.Append(P.FromMM(OX + x), P.FromMM(OY + y))
    b.Add(z)

P.SaveBoard(path, b)
print("placed", len(place))
