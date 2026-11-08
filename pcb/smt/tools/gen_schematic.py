#!/usr/bin/env python3
"""Generate smt.kicad_sch: Open AIQ SMT board (ESP32-S3-WROOM-1 on board).

Run from the repo root:  KICAD_SHARE=<KiCad SharedSupport dir> python3 pcb/smt/tools/gen_schematic.py
The schematic is generated so its layout stays reviewable as code. After running,
check with `kicad-cli sch erc`.
"""
import os, re, uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
BOARD = HERE.parent
REPO = BOARD.parent.parent
SHARE = Path(os.environ.get("KICAD_SHARE", "/Applications/KiCad/KiCad.app/Contents/SharedSupport"))
LIBS = {"open-aiq": REPO / "lib" / "open-aiq.kicad_sym"}
ROOT = "6a1c2f3e-5b8d-4e7a-9c0f-1d2e3f4a5b6c"     # stable sheet uuid
U = lambda: str(uuid.uuid4())

# ---------------------------------------------------------------- library symbols
def _block(text, name):
    i = text.index(f'(symbol "{name}"')
    d = 0
    for j in range(i, len(text)):
        if text[j] == "(":
            d += 1
        elif text[j] == ")":
            d -= 1
            if d == 0:
                return text[i:j + 1]

def lib_symbol(lib_id):
    lib, name = lib_id.split(":")
    path = LIBS.get(lib, SHARE / "symbols" / f"{lib}.kicad_sym")
    text = path.read_text()
    blk = _block(text, name)
    m = re.search(r'\(extends "([^"]+)"\)', blk)
    if m:  # flatten a derived symbol: parent graphics + pins, child properties
        parent = _block(text, m.group(1))
        props = re.findall(r'\(property "[^"]*".*?\n\t\t\)', blk, re.S)
        body = re.sub(r'\(property "[^"]*".*?\n\t\t\)\s*', "", parent, flags=re.S)
        body = body.replace(f'(symbol "{m.group(1)}_', f'(symbol "{name}_')
        head = body.index("\n")
        blk = body[:head] + "\n\t\t" + "\n\t\t".join(props) + body[head:]
        blk = blk.replace(f'(symbol "{m.group(1)}"', f'(symbol "{name}"', 1)
    blk = blk.replace(f'(symbol "{name}"', f'(symbol "{lib_id}"', 1)
    pins = list(dict.fromkeys(re.findall(r'\(number "([^"]+)"', blk)))
    return blk, pins

# ---------------------------------------------------------------- sheet builder
used, items, pwr_n = {}, [], [0]

def eff(size=1.27, justify=None, hide=False):
    j = f" (justify {justify})" if justify else ""
    h = " (hide yes)" if hide else ""
    return f"(effects (font (size {size} {size})){j}){h}"

def prop(name, val, x, y, ang=0, justify=None, hide=False):
    return f'(property "{name}" "{val}" (at {x} {y} {ang}) {eff(justify=justify, hide=hide)})'

def part(lib_id, ref, value, x, y, rot=0, fp="", lcsc="", refpos=None, valpos=None, ds="~", bom=True):
    if lib_id not in used:
        used[lib_id] = lib_symbol(lib_id)
    pins = used[lib_id][1]
    rx, ry, rj = refpos or (x + 2.54, y - 1.27, "left")
    vx, vy, vj = valpos or (x + 2.54, y + 1.27, "left")
    power = ref.startswith("#")
    fa = 90 if rot in (90, 270) and not power else 0
    props = [prop("Reference", ref, rx, ry, fa, rj, hide=power),
             prop("Value", value, vx, vy, fa, vj),
             prop("Footprint", fp, x, y, hide=True),
             prop("Datasheet", ds, x, y, hide=True)]
    if lcsc:
        props.append(prop("LCSC", lcsc, x, y, hide=True))
    pin_s = " ".join(f'(pin "{p}" (uuid "{U()}"))' for p in pins)
    inb = "yes" if bom and not power else "no"
    items.append(
        f'(symbol (lib_id "{lib_id}") (at {x} {y} {rot}) (unit 1) (exclude_from_sim no) (in_bom {inb}) '
        f'(on_board {"no" if power else "yes"}) (dnp no) (uuid "{U()}")\n\t\t' + "\n\t\t".join(props) +
        f'\n\t\t{pin_s}\n\t\t(instances (project "smt" (path "/{ROOT}" (reference "{ref}") (unit 1)))))')

def pwr(kind, x, y, rot=0):
    pwr_n[0] += 1
    off = {"GND": 3.81, "PWR_FLAG": -3.81}.get(kind, -3.81)
    if kind == "GND" and rot == 180:
        off = -3.81
    if rot in (90, 270):
        vp = (x + (3.81 if rot == 90 else -3.81), y, "left" if rot == 90 else "right")  # 90 points right, 270 left
    else:
        vp = (x, round(y + off, 2), None)
    part(f"power:{kind}", f"#PWR{pwr_n[0]:02d}" if kind != "PWR_FLAG" else f"#FLG{pwr_n[0]:02d}",
         kind, x, y, rot, refpos=(x, y, None), valpos=vp)

def wire(*pts):
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        items.append(f'(wire (pts (xy {x1} {y1}) (xy {x2} {y2})) (stroke (width 0) (type default)) (uuid "{U()}"))')

def junc(x, y):
    items.append(f'(junction (at {x} {y}) (diameter 0) (color 0 0 0 0) (uuid "{U()}"))')

def label(name, x, y, ang=0):
    j = "left bottom" if ang in (0, 90) else "right bottom"
    items.append(f'(label "{name}" (at {x} {y} {ang}) {eff(justify=j)} (uuid "{U()}"))')

def nc(x, y):
    items.append(f'(no_connect (at {x} {y}) (uuid "{U()}"))')

def text(t, x, y, size=1.8):
    items.append(f'(text "{t}" (exclude_from_sim no) (at {x} {y} 0) (effects (font (size {size} {size}) (bold yes)) (justify left bottom)) (uuid "{U()}"))')

def stub(px, py, name, dx):
    """Short wire from a pin end plus a net label (dx<0: to the left)."""
    wire((px, py), (px + dx, py))
    label(name, px + dx, py, 180 if dx < 0 else 0)

# ---------------------------------------------------------------- footprints / parts
R0603 = "Resistor_SMD:R_0603_1608Metric"
C0603 = "Capacitor_SMD:C_0603_1608Metric"
C0805 = "Capacitor_SMD:C_0805_2012Metric"
SW = "Button_Switch_SMD:SW_Push_1P1T_XKB_TS-1187A"
LCSC = {"5.1k": "C23186", "10k": "C25804", "4.7k": "C23162", "100nF": "C14663",
        "1uF": "C15849", "10uF": "C19702", "22uF": "C45783"}

def R(ref, val, x, y, rot=0, **k):
    if rot == 90:
        k.setdefault("refpos", (x, y - 2.54, None)); k.setdefault("valpos", (x, y + 2.54, None))
    part("Device:R", ref, val, x, y, rot, R0603, LCSC[val], **k)

def C(ref, val, x, y, **k):
    part("Device:C", ref, val, x, y, 0, C0805 if val == "22uF" else C0603, LCSC[val], **k)

# ================================================================ A: USB-C, ESD, fuse, LDO
text("USB-C power, ESD and 3.3 V", 27.94, 35.56)
part("Connector:USB_C_Receptacle_USB2.0_16P", "J1", "USB-C", 38.1, 71.12,
     fp="Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12", lcsc="C165948",
     refpos=(27.94, 46.99 + 2.54, "left"), valpos=(22.86, 101.6, "left"))
VB, CC1, CC2, DMA, DMB, DPA, DPB = 45.72, 60.96, 63.5, 68.58, 71.12, 73.66, 76.2
VBP = 55.88  # J1 VBUS pin
JX = 53.34
nc(JX, 83.82); nc(JX, 86.36)                      # SBU1/SBU2
pwr("GND", 38.1, 93.98)
pwr("GND", 45.72, 106.68); pwr("PWR_FLAG", 45.72, 106.68)   # marks GND as driven for ERC
pwr("GND", 30.48, 93.98)                           # shield
# CC pull-downs (5.1k: tells a USB-C charger to give us 5 V)
R("R1", "5.1k", 60.96, CC1, 90, refpos=(57.91, 58.42, None), valpos=(63.5, 58.42, None))
R("R2", "5.1k", 60.96, CC2, 90, refpos=(57.91, 66.04, None), valpos=(63.5, 66.04, None))
wire((JX, CC1), (57.15, CC1)); wire((JX, CC2), (57.15, CC2))
wire((64.77, CC1), (64.77, CC2)); junc(64.77, CC2); pwr("GND", 64.77, CC2)
# D-/D+ pairs joined, then through the ESD diode array
wire((JX, DMA), (55.88, DMA), (55.88, DMB)); wire((JX, DMB), (55.88, DMB), (66.04, DMB)); junc(55.88, DMB)
wire((JX, DPB), (55.88, DPB), (55.88, DPA)); wire((JX, DPA), (55.88, DPA), (66.04, DPA)); junc(55.88, DPA)
part("Power_Protection:USBLC6-2SC6", "U1", "USBLC6-2SC6", 71.12, 71.12,
     fp="Package_TO_SOT_SMD:SOT-23-6", lcsc="C7519", refpos=(73.66, 64.77, "left"), valpos=(66.04, 81.28, "left"))
pwr("+5V", 71.12, 66.04); pwr("GND", 71.12, 78.74)
stub(76.2, DMB, "USB_D-", 2.54); stub(76.2, DPA, "USB_D+", 2.54)
# VBUS -> resettable fuse -> +5V -> LDO
part("Device:Polyfuse", "F1", "1.1A", 60.96, VB, 90, fp="Fuse:Fuse_1206_3216Metric", lcsc="C7542963",
     refpos=(60.96, VB - 2.54, None), valpos=(60.96, VB + 2.54, None))
wire((JX, VBP), (55.88, VBP), (55.88, VB), (57.15, VB)); label("VBUS", JX + 0.635, VBP)
wire((64.77, VB), (67.31, VB), (73.66, VB), (78.74, VB), (83.82, VB))
junc(67.31, VB); junc(73.66, VB); junc(78.74, VB)
pwr("+5V", 67.31, VB); pwr("PWR_FLAG", 73.66, VB)
C("C1", "22uF", 78.74, 49.53); pwr("GND", 78.74, 53.34)
part("Regulator_Linear:AMS1117-3.3", "U2", "AMS1117-3.3", 91.44, VB, fp="Package_TO_SOT_SMD:SOT-223-3_TabPin2",
     lcsc="C6186", refpos=(88.9, 39.37, "left"), valpos=(93.98, 55.88, "left"))
pwr("GND", 91.44, 53.34)
wire((99.06, VB), (104.14, VB), (109.22, VB), (114.3, VB)); junc(104.14, VB); junc(109.22, VB)
C("C2", "22uF", 104.14, 49.53); pwr("GND", 104.14, 53.34)
C("C3", "100nF", 109.22, 49.53); pwr("GND", 109.22, 53.34)
pwr("+3V3", 114.3, VB)

# ================================================================ B: ESP32-S3 module
text("ESP32-S3-WROOM-1 (N16R8)", 172.72, 55.88)
MX, MY = 190.5, 101.6
part("RF_Module:ESP32-S3-WROOM-1", "U3", "ESP32-S3-WROOM-1-N16R8", MX, MY,
     fp="RF_Module:ESP32-S3-WROOM-1", lcsc="C2913202", refpos=(177.8, 71.12, "left"), valpos=(193.04, 133.35, "left"),
     ds="https://www.espressif.com/sites/default/files/documentation/esp32-s3-wroom-1_wroom-1u_datasheet_en.pdf")
L, Rt = MX - 15.24, MX + 15.24
y = lambda local: round(MY - local, 2)
pwr("+3V3", MX, y(27.94)); pwr("GND", MX, y(-27.94))
# EN: 10k pull-up + 1uF delay + RESET button (all above the EN line)
EN = y(22.86)
wire((L, EN), (170.18, EN), (165.1, EN), (160.02, EN)); junc(170.18, EN); junc(165.1, EN)
R("R3", "10k", 170.18, 74.93); pwr("+3V3", 170.18, 71.12)
part("Device:C", "C4", "1uF", 165.1, 74.93, fp=C0603, lcsc=LCSC["1uF"], refpos=(162.56, 73.66, "right"), valpos=(162.56, 76.2, "right"))
pwr("GND", 165.1, 71.12, 180)
part("Switch:SW_Push", "SW1", "RESET", 160.02, 73.66, 90, fp=SW, lcsc="C318884",
     refpos=(156.21, 72.39, None), valpos=(156.21, 74.93, None))
pwr("GND", 160.02, 68.58, 180)
# BOOT button on IO0
IO0 = y(17.78)
wire((L, IO0), (154.94, IO0))
part("Switch:SW_Push", "SW2", "BOOT", 154.94, 88.9, 90, fp=SW, lcsc="C318884",
     refpos=(150.495, 87.63, None), valpos=(150.495, 90.17, None))
pwr("GND", 154.94, 93.98)
# Signals to the rest of the board
stub(L, y(7.62), "BTN_RIGHT", -2.54)   # IO4
stub(L, y(5.08), "BTN_LEFT", -2.54)    # IO5
stub(L, y(-2.54), "SDA", -2.54)        # IO8
stub(L, y(-5.08), "SCL", -2.54)        # IO9
stub(L, y(-20.32), "PMS_RESET", -2.54) # IO15
stub(L, y(-22.86), "PMS_SET", -2.54)   # IO16
stub(Rt, y(17.78), "ESP_TX", 2.54)     # IO17
stub(Rt, y(15.24), "ESP_RX", 2.54)     # IO18
stub(Rt, y(12.7), "USB_D-", 2.54)      # IO19
stub(Rt, y(10.16), "USB_D+", 2.54)     # IO20
stub(Rt, y(-22.86), "LED_DIN", 2.54)   # IO48
for l in (15.24, 12.7, 10.16, 2.54, 0, -7.62, -10.16, -12.7, -15.24, -17.78):
    nc(L, y(l))
for l in (22.86, 20.32, 7.62, 5.08, 2.54, 0, -2.54, -5.08, -7.62, -10.16, -12.7, -15.24, -17.78, -20.32):
    nc(Rt, y(l))
# Module decoupling, close to its 3V3 pin
text("Module decoupling", 210.82, 50.8, 1.27)
C("C5", "22uF", 213.36, 64.77); pwr("+3V3", 213.36, 60.96); pwr("GND", 213.36, 68.58)
C("C6", "100nF", 220.98, 64.77); pwr("+3V3", 220.98, 60.96); pwr("GND", 220.98, 68.58)

# ================================================================ C: PMS5003
text("PMS5003 particle sensor (cable from the box)", 243.84, 43.18)
PX, PY = 269.24, 73.66
part("open-aiq:PMS5003", "J2", "PMS5003", PX, PY, fp="Connector_Molex:Molex_PicoBlade_53261-0871_1x08-1MP_P1.25mm_Horizontal",
     lcsc="C2681529", refpos=(261.62, 64.77, "left"), valpos=(271.78, 83.82, "left"))
pwr("+5V", PX, 60.96); pwr("GND", PX, 86.36)
PR = PX + 12.7
wire((PR, 68.58), (284.48, 68.58), (292.1, 68.58)); junc(284.48, 68.58); label("PMS_RESET", 292.1, 68.58)
wire((PR, 71.12), (289.56, 71.12), (292.1, 71.12)); junc(289.56, 71.12); label("PMS_SET", 292.1, 71.12)
wire((PR, 73.66), (292.1, 73.66)); label("ESP_TX", 292.1, 73.66)
wire((PR, 76.2), (292.1, 76.2)); label("ESP_RX", 292.1, 76.2)
R("R4", "10k", 284.48, 64.77, refpos=(281.94, 63.5, "right"), valpos=(281.94, 66.04, "right")); pwr("+3V3", 284.48, 60.96)
R("R5", "10k", 289.56, 57.15); pwr("+3V3", 289.56, 53.34)
wire((289.56, 60.96), (289.56, 71.12))       # R5 lead crosses PMS_RESET without connecting
C("C7", "22uF", 248.92, 73.66); pwr("+5V", 248.92, 69.85); pwr("GND", 248.92, 77.47)

# ================================================================ D: OLED (Qwiic), SHT30, I2C pull-ups
text("OLED (Qwiic cable) and SHT30", 243.84, 99.06)
QX, QY = 269.24, 114.3
part("open-aiq:Qwiic_JST_SH_4", "J3", "OLED (Qwiic)", QX, QY,
     fp="Connector_JST:JST_SH_SM04B-SRSS-TB_1x04-1MP_P1.00mm_Horizontal", lcsc="C160404",
     refpos=(261.62, 107.95, "left"), valpos=(271.78, 121.92, "left"))
pwr("+3V3", QX, 104.14); pwr("GND", QX, 124.46); nc(256.54, 116.84)
stub(281.94, 111.76, "SDA", 2.54); stub(281.94, 116.84, "SCL", 2.54)
SX, SY = 309.88, 114.3
part("Sensor_Humidity:SHT30-DIS", "U4", "SHT30-DIS-B", SX, SY, fp="Sensor_Humidity:Sensirion_DFN-8-1EP_2.5x2.5mm_P0.5mm_EP1.1x1.7mm",
     lcsc="C77361", refpos=(304.8, 104.14, "right"), valpos=(312.42, 125.73, "left"))
pwr("+3V3", SX, 106.68); pwr("GND", SX, 121.92)
pwr("GND", 299.72, 111.76, 270)                 # ADDR low -> 0x44
pwr("GND", 299.72, 116.84, 270)                 # R pin to ground
R("R6", "10k", 293.37, SY, 90, refpos=(293.37, SY - 2.54, None), valpos=(293.37, SY + 2.54, None)); wire((297.18, SY), (299.72, SY)); pwr("+3V3", 289.56, SY)
stub(320.04, 111.76, "SDA", 2.54); stub(320.04, 114.3, "SCL", 2.54); nc(320.04, 116.84)
C("C8", "100nF", 332.74, 110.49); pwr("+3V3", 332.74, 106.68); pwr("GND", 332.74, 114.3)
text("I2C pull-ups", 243.84, 134.62, 1.27)
R("R7", "4.7k", 254, 143.51); pwr("+3V3", 254, 139.7); wire((254, 147.32), (254, 149.86)); label("SDA", 254, 149.86, 270)
R("R8", "4.7k", 264.16, 143.51); pwr("+3V3", 264.16, 139.7); wire((264.16, 147.32), (264.16, 149.86)); label("SCL", 264.16, 149.86, 270)

# ================================================================ E: buttons, LED, mounting
text("User buttons", 342.9, 66.04)
part("Switch:SW_Push", "SW3", "RIGHT", 355.6, 73.66, fp=SW, lcsc="C318884", refpos=(355.6, 71.12, None), valpos=(355.6, 76.2, None))
stub(350.52, 73.66, "BTN_RIGHT", -2.54); pwr("GND", 360.68, 73.66, 90)
part("Switch:SW_Push", "SW4", "LEFT", 355.6, 83.82, fp=SW, lcsc="C318884", refpos=(355.6, 81.28, None), valpos=(355.6, 86.36, None))
stub(350.52, 83.82, "BTN_LEFT", -2.54); pwr("GND", 360.68, 83.82, 90)
text("Status LED", 342.9, 134.62)
part("LED:WS2812B-2020", "D1", "WS2812B-2020", 355.6, 149.86, fp="LED_SMD:LED_WS2812B-2020_PLCC4_2.0x2.0mm",
     lcsc="C965555", refpos=(358.14, 140.97, "left"), valpos=(358.14, 160.02, "left"))
stub(347.98, 149.86, "LED_DIN", -2.54); nc(363.22, 149.86)
pwr("+3V3", 355.6, 142.24); pwr("GND", 355.6, 157.48)
C("C9", "100nF", 373.38, 149.86); pwr("+3V3", 373.38, 146.05); pwr("GND", 373.38, 153.67)
text("Mounting (M2.5)", 342.9, 177.8, 1.27)
for i, x in enumerate((345.44, 355.6, 365.76, 375.92), 1):
    part("Mechanical:MountingHole", f"H{i}", "M2.5", x, 185.42, fp="MountingHole:MountingHole_2.7mm_M2.5",
         refpos=(x, 181.61, None), valpos=(x, 189.23, None), bom=False)

# ---------------------------------------------------------------- write
lib_symbols = "\n\t\t".join(b for b, _ in used.values())
out = f'''(kicad_sch
	(version 20250114)
	(generator "open_aiq_gen")
	(generator_version "10.0")
	(uuid "{ROOT}")
	(paper "A3")
	(title_block
		(title "Open AIQ SMT: ESP32-S3 air-quality board")
		(date "2026-11-08")
		(rev "A")
		(company "Open AIQ")
		(comment 1 "Native USB-C (USB Serial/JTAG), WROOM-1 N16R8 module, SHT30 on board")
		(comment 2 "GPIO map follows open-aiq/device src/board.rs")
	)
	(lib_symbols
		{lib_symbols}
	)
	{chr(10).join(chr(9) + i for i in items)}
	(sheet_instances (path "/" (page "1")))
	(embedded_fonts no)
)
'''
(BOARD / "smt.kicad_sch").write_text(out)
print(f"wrote {BOARD / 'smt.kicad_sch'}: {len(used)} symbols, {len(items)} items")
