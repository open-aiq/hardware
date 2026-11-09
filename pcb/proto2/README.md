# Proto2: devkit carrier

Proto2 is the board we use to get Open AIQ off the breadboard. The OLED sits
top-left with three buttons under it, the sensors take the middle, and your
ESP32-S3 devkit plugs into two sockets on the right with its USB port at the
bottom edge. It's single-sided (all copper on the bottom) and everything is
through-hole, so you can solder it by hand and get it made almost anywhere.

![Proto2, 3D render](renders/proto2-iso.png)

| Top | Bottom |
| --- | --- |
| ![Top](renders/proto2-top.png) | ![Bottom](renders/proto2-bottom.png) |

## What's on it

| Ref | Part | Wiring |
| --- | --- | --- |
| U1 | ESP32-S3-DevKitC-1, or a pin-compatible clone, on two 1×22 sockets 25.4 mm (1.0 in) apart | All signals are on the left header. USB faces the bottom edge |
| J1 | PMS5003 particulate sensor, 8-pin 1.25 mm connector | 5 V, UART on GPIO 18 (ESP TX) / 17 (ESP RX), SET on GPIO 8, RESET on GPIO 16 |
| J2 | 1.3 in SH1106 128×64 I2C OLED module, 4-pin socket | I2C, `SDA SCL VCC GND` from left to right. The module lies flat over the dashed OLED area |
| J3 | SHT30 breakout with 6 pins, on a 1×4 and a 1×2 socket | I2C, `VIN GND SCL SDA`. The 2 pins on the far edge (usually ADDR and ALERT) are for support only |
| SW1, SW2, SW3 | Right, left and pair buttons, 6 × 6 mm 4-leg tactile switches | GPIO 15, GPIO 6 and GPIO 7, active-low |
| R1, R2 | 4.7 kΩ I2C pull-ups | SDA (GPIO 5), SCL (GPIO 4) to 3.3 V |
| R3, R4 | 10 kΩ pull-ups | SET (R3) and RESET (R4), so the PMS5003 stays awake and out of reset unless the firmware says otherwise |
| C1–C4 | Bulk and decoupling capacitors | 100 µF + 100 nF on 5 V, 10 µF + 100 nF on 3.3 V |

The pins match [`src/board.rs`](https://github.com/open-aiq/device/blob/main/src/board.rs)
in open-aiq/device. Rev B moved several pins so every trace fits on one side of
the board, so flash firmware with the matching `board.rs` before you plug a
devkit in. Older breadboard builds used the previous map (SDA 8, SCL 9, buttons
4 and 5), which you'll find in the firmware README. A few pins are there for
later:

- **SW3 Pair (GPIO 7)** will start BLE pairing with the phone app. The firmware
  doesn't read it yet, so for now pressing it does nothing.
- **SET and RESET** have pull-ups that keep the sensor running. Later the
  firmware can drive them to rest the sensor between readings.

The schematic is in [`proto2.pdf`](proto2.pdf), and [`proto2-assembly.pdf`](proto2-assembly.pdf) shows where each part goes.

## Before you build

- **Check your OLED's pin order.** The socket reads `SDA SCL VCC GND` from left
  to right, and the silkscreen says so too. Some modules swap GND and VCC, and
  plugging one in backwards can damage it.
- **Clone devkits need the 5 V pad bridged.** Many DevKitC-1 clones have an
  `IN-OUT` solder jumper next to the 5V pin. Until you bridge it, USB power
  doesn't reach that pin, and the PMS5003 stays dark. Once it's bridged, don't
  feed 5 V into the pin while USB is plugged in.
- **The OLED lies flat over its dashed area.** It plugs into J2 face-up and
  rests over that area, which is why nothing else is placed there.
- **Measure your SHT30 before you order.** We set the gap between its two pin
  rows to 6.35 mm from a photo. If yours differs, the 4-pin row still works, and
  you can leave the 1×2 socket out.
- **The PMS5003 sits on the marked bed.** Stick it down with double-sided foam
  tape, vents facing the top edge so it doesn't pull in warm air from the
  devkit. Its case is metal, but there's no copper on top, so it can't short
  anything.
- **The devkit's antenna hangs off the top edge.** That's on purpose: copper
  under an antenna weakens WiFi and BLE, so the ground fill also stops short of
  that end.
- **R8 modules use GPIO 35, 36 and 37 for PSRAM.** Proto2 leaves them
  unconnected, so keep it that way if you add anything.

## Parts

You'll find the generated list in [`fab/proto2-bom.csv`](fab/proto2-bom.csv).
To buy them:

| Qty | Part | Notes |
| --- | --- | --- |
| 2 | 1×22 female header, 2.54 mm | Sockets for the devkit (U1) |
| 2 | 1×4 female header, 2.54 mm | OLED (J2) and SHT30 (J3) |
| 1 | 1×2 female header, 2.54 mm | SHT30's far-edge pins (J3) |
| 1 | Molex PicoBlade 53047-0810, 8-pin vertical | PMS5003 (J1). Check that it fits your sensor's cable first |
| 3 | 6 × 6 mm through-hole tactile switch, 4-leg (for example Omron B3F-1000) | SW1, SW2, SW3 |
| 2 | 4.7 kΩ resistor, 1/4 W axial | R1, R2 |
| 2 | 10 kΩ resistor, 1/4 W axial | R3, R4 |
| 1 | 100 µF electrolytic, ≥10 V, 6.3 mm radial, 2.5 mm pitch | C1 |
| 1 | 10 µF electrolytic, ≥10 V, 5 mm radial, 2 mm pitch | C3 |
| 2 | 100 nF ceramic, 5 mm pitch | C2, C4 |

## Ordering

[`fab/proto2-gerbers.zip`](fab/proto2-gerbers.zip) holds the Gerbers and
Excellon drill files: bottom copper, bottom solder mask, top silkscreen, the
outline and drills. Upload it to JLCPCB, PCBWay or a local shop as it is. We
haven't placed an order yet, so treat these settings as our first guess:

| Setting | Value |
| --- | --- |
| Size | 142 × 63 mm |
| Layers | 1 (copper on the bottom, parts on top). You can also order it as 2-layer for plated holes; the top side then has pads only |
| Thickness | 1.6 mm |
| Min track / clearance | 0.3 / 0.25 mm (power 0.8 mm), so a track can pass between two 2.54 mm pins |
| Min hole | 0.5 mm (PMS5003 connector pins); no vias |
| Surface finish | HASL is fine |

Every part is through-hole, so there's no pick-and-place file.

## Editing

Open `proto2.kicad_pro` in KiCad 10. The repo's [Working in KiCad](../../README.md#working-in-kicad)
guide covers libraries, rules and outputs. These are ours, in [`lib/`](../../lib):

- the devkit socket and SHT30 socket footprints. The devkit socket marks its
  GND pins and its two 3V3 pins as joined inside the devkit (KiCad *jumper pad
  groups*), so they don't need tracks between them
- the arrow and phone-with-Bluetooth icons under the buttons, which are
  board-only footprints you can move
- the sensor symbols

To refresh the outputs, run `proto2.kicad_jobset` in KiCad, or this from the repo
root:

```sh
scripts/export.sh pcb/proto2
```

Both stop if ERC or DRC finds a problem.
