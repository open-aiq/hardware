// Proto2 rev C: design rationale.
// Build from this folder with:  typst compile proto2-rationale.typ
// Fonts are Typst's bundled ones, so it builds the same anywhere.

// ---------------------------------------------------------------- style
#let ink = rgb("#3b2716")
#let accent = rgb("#8a5d3b")
#let sage = rgb("#6f7f5c")
#let sand = rgb("#f1e6d6")
#let wood = rgb("#c9a77c")

#set document(
  title: "Proto2 rev C: design rationale",
  author: "Open AIQ",
  keywords: ("Open AIQ", "Proto2", "ESP32-S3", "PMS5003", "SHT30", "SH1106"),
)
#set page(
  paper: "a4",
  margin: (x: 2.2cm, top: 2.2cm, bottom: 2.4cm),
  numbering: "1",
  footer: context [
    #set text(size: 8pt, fill: sage)
    Open AIQ · Proto2 rev C · Design rationale
    #h(1fr)
    #counter(page).display("1 / 1", both: true)
  ],
)
#set text(font: "Libertinus Serif", size: 10.5pt, fill: ink, lang: "en")
#set par(justify: true, leading: 0.62em, spacing: 1.05em)
#show raw: set text(font: "DejaVu Sans Mono", size: 8.6pt)
#show link: set text(fill: accent)
#set heading(numbering: "1.1")
#show heading: set text(fill: accent)
#show heading.where(level: 1): it => {
  v(0.9em)
  block(below: 0.7em, stroke: (bottom: 0.6pt + wood), inset: (bottom: 0.35em), width: 100%, it)
}
#show heading.where(level: 2): set block(above: 1.2em, below: 0.6em)
#set table(
  stroke: (x, y) => (
    top: if y == 0 { 0.8pt + wood } else if y == 1 { 0.6pt + wood } else { 0.3pt + sand.darken(10%) },
    bottom: 0.8pt + wood,
  ),
  inset: (x: 5pt, y: 4.5pt),
  fill: (x, y) => if y == 0 { sand },
)
#show table.cell.where(y: 0): set text(weight: "bold")
#show table: set text(size: 9pt)
#show table: set par(justify: false)
#set enum(numbering: "1.", spacing: 0.9em)

// ---------------------------------------------------------------- references
// Each entry records the parts of the source this document relies on.
#let refs = (
  (
    key: "esp-ds",
    entry: [Espressif Systems. _ESP32-S3 Series Datasheet_. Version 2.2, 5 March 2026.],
    used: [§2.3.4 Restrictions for GPIOs and RTC_GPIOs (p. 25); §2.3.5 Peripheral Pin Assignment (p. 26); Table 2-8 Analog Functions (p. 24); Table 2-9 Peripheral Pin Assignment (p. 27); §2.6, Table 2-14 Pin Mapping Between Chip and Flash/PSRAM (p. 31); Table 3-1 Default Configuration of Strapping Pins (p. 32); §3.1, Table 3-3 Chip Boot Mode Control (p. 33); §3.2, Table 3-4 VDD_SPI Voltage Control (p. 34); §4.1.3.1 IO MUX and GPIO Matrix (p. 40); §4.2.2.1 SAR ADC, note (p. 59); §5.4, Table 5-4 DC Characteristics (p. 65).],
    url: "https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf",
  ),
  (
    key: "devkit",
    entry: [Espressif Systems. _ESP32-S3-DevKitC-1 v1.1 User Guide_. esp-dev-kits documentation, "latest" (undated web page); compared with the v1.0 guide.],
    used: [Getting Started › Description of Components; Hardware Reference › Power Supply Options; Hardware Reference › Header Block (J1, J3); Hardware Revision Details.],
    url: "https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32s3/esp32-s3-devkitc-1/user_guide_v1.1.html",
  ),
  (
    key: "wroom",
    entry: [Espressif Systems. _ESP32-S3-WROOM-1 & ESP32-S3-WROOM-1U Datasheet_. Version 1.8, 2 March 2026.],
    used: [§3.2 Pin Description, Table 3-1 Pin Definitions, note b (p. 12); series comparison of PSRAM variants (p. 3).],
    url: "https://www.espressif.com/sites/default/files/documentation/esp32-s3-wroom-1_wroom-1u_datasheet_en.pdf",
  ),
  (
    key: "hdg",
    entry: [Espressif Systems. _ESP32-S3 Hardware Design Guidelines_. Release "master" (revision history up to v1.8, 3 July 2025).],
    used: [§1.3.2 Power Supply (p. 5); §1.4.7 General Principles of PCB Layout for Modules, Figures 24–26 (pp. 28–31).],
    url: "https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32s3/",
  ),
  (
    key: "pms",
    entry: [Plantower. _Digital Universal Particle Concentration Sensor PMS5003 Series Data Manual_. Version V2.3, 1 June 2016. The manual has no section numbers; pages are PDF pages.],
    used: [Technical Index (p. 3); Pin Definition, Figure 2 Connector Definition (p. 4); Circuit Attentions, items 1–4 (p. 10); Appendix I, transport protocol (p. 13).],
    url: "https://cdn-shop.adafruit.com/product-files/3686/plantower-pms5003-manual_v2-3.pdf",
  ),
  (
    key: "usb",
    entry: [Compaq, Hewlett-Packard, Intel, Lucent, Microsoft, NEC and Philips. _Universal Serial Bus Specification_. Revision 2.0, 27 April 2000.],
    used: [§7.2.4.1 Inrush Current Limiting (p. 177); Table 7-7 DC Electrical Characteristics, C#sub[RPB] (p. 178).],
    url: "https://www.usb.org/document-library/usb-20-specification",
  ),
  (
    key: "aoe",
    entry: [Paul Horowitz and Winfield Hill. _The Art of Electronics_. 3rd edition. Cambridge University Press, 2015.],
    used: [Chapter 1, Foundations (capacitors and their uses), cited at chapter level for general background only.],
    url: "https://artofelectronics.net/",
  ),
  (
    key: "sh1106",
    entry: [_SH1106: 132 × 64 Dot Matrix OLED/PLED Segment/Common Driver with Controller_. Version 2.3, June 2013.],
    used: [Features (p. 1); I²C-bus Interface (pp. 11–13); Command 6, Set Segment Re-map A0H–A1H (p. 21); Command 13, Set Common Output Scan Direction C0H–C8H (p. 24); AC characteristics, f#sub[SCL] (p. 43).],
    url: "https://www.pololu.com/file/0J1813/SH1106.pdf",
  ),
  (
    key: "sht",
    entry: [Sensirion AG. _Datasheet SHT3x-DIS: Humidity and Temperature Sensor_. Version 7, December 2022.],
    used: [§2.1 Electrical Specifications, Table 3 (p. 6); §3.1 Power Pins (p. 8); §3.2 Serial Clock and Serial Data (p. 8); Table 7 Pin Assignment (p. 8); §3.4, Table 8 I²C Device Addresses (p. 9); §4.14, Table 21 Communication Timing (p. 14).],
    url: "https://sensirion.com/file/datasheet_sht3x_digital",
  ),
  (
    key: "sht-guide",
    entry: [Sensirion AG. _SHTxx and STSxx Design Guide_. Revision 1.1, May 2019.],
    used: [Overview, recommendation 4 "Sensor is decoupled from heat sources" (p. 1); Heating (p. 2).],
    url: "https://sensirion.com/products/downloads",
  ),
  (
    key: "ti",
    entry: [Rajan Arora. _I²C Bus Pullup Resistor Calculation_. Texas Instruments application note SLVA689A, February 2015, revised October 2026.],
    used: [§2 Pullup Resistor Calculation, Equations 1, 5 and 6 and Table 2-1 Parametrics from I²C Specifications (p. 3). The note restates NXP UM10204, _I²C-bus Specification and User Manual_, Rev. 7.0, 2021, which we did not consult directly.],
    url: "https://www.ti.com/lit/an/slva689/slva689.pdf",
  ),
  (
    key: "ipc",
    entry: [IPC. _IPC-2221A: Generic Standard on Printed Board Design_. May 2003.],
    used: [§6.2 Conductive Material Requirements, Figure 6-4 Conductor Thickness and Width for Internal and External Layers (pp. 40–41). Section and figure titles were checked against IPC's published table of contents; the current values in this document come from the curve fit commonly used for that chart, not from the standard's text.],
    url: "https://www.electronics.org/TOC/IPC-2221A.pdf",
  ),
)

#let rc(key, loc) = {
  let i = refs.position(r => r.key == key)
  assert(i != none, message: "unknown reference " + key)
  link(label("ref-" + key))[\[#(i + 1)#if loc != none [, #loc]\]]
}

// ---------------------------------------------------------------- keywords
#let keywords = (
  ("active-low", "Active-low", [A signal that means "on" when it is at 0 V. Proto2's buttons are active-low: pressing one connects its GPIO to ground.]),
  ("bulk", "Bulk capacitor", [A capacitor of several microfarads or more that stores charge to cover a load step lasting microseconds to milliseconds, while the supply further away catches up.]),
  ("decoupling", "Decoupling capacitor", [A small ceramic capacitor, typically 100 nF, placed next to a supply pin. It supplies the fastest current edges and gives high-frequency noise a short path to ground.]),
  ("pull-up", "Pull-up resistor", [A resistor from a signal to the supply. It holds the signal high whenever nothing actively drives it low.]),
  ("open-drain", "Open-drain", [An output that can only pull a line low or let go of it. It never drives the line high; a pull-up resistor does that.]),
  ("strapping", "Strapping pin", [A GPIO whose level the ESP32-S3 latches at reset to choose its boot mode and some settings. After reset it works as an ordinary GPIO.]),
  ("matrix", "GPIO matrix", [The ESP32-S3's internal switch that connects a peripheral's signals, such as a UART or I²C, to almost any GPIO.]),
  ("rise", "Rise time", [For I²C, the time a line takes to rise from 30 % to 70 % of the supply voltage after it is released.]),
  ("cb", "Bus capacitance", [The total capacitance on one I²C line (C#sub[b]): its tracks, every connected pin, and any module wiring.]),
  ("inrush", "Inrush current", [The surge of current at power-up while a device's capacitors charge.]),
  ("netclass", "Net class", [A named set of routing rules, such as track width and clearance, that applies to a group of nets.]),
  ("fill", "Ground fill", [Copper on a layer that fills the free space and connects to ground. It gives return currents a wide, low-resistance path.]),
  ("keepout", "Keep-out", [An area where the design rules forbid copper, tracks or parts.]),
  ("pth", "Plated through-hole", [A drilled hole lined with copper, which joins the pads on both sides of the board and holds a soldered lead firmly.]),
  ("thermal", "Thermal decoupling", [Keeping heat from warm parts away from a sensor by distance and by removing copper that would conduct it.]),
)
#let kw(key, body) = {
  assert(keywords.any(k => k.at(0) == key), message: "unknown keyword " + key)
  link(label("kw-" + key), strong(body))
}

// ---------------------------------------------------------------- title
#block(width: 100%, inset: (bottom: 0.4em))[
  #set par(justify: false)
  #text(size: 9pt, fill: sage, tracking: 0.08em)[OPEN AIQ · HARDWARE]
  #v(0.15em)
  #text(size: 24pt, weight: "bold", fill: ink)[Proto2 rev C: design rationale]
  #v(0.1em)
  #text(size: 12pt, fill: accent)[Why each part and pin is on the carrier board, and why it works]
  #v(0.4em)
  #text(size: 9pt, fill: sage)[12 November 2026 · Matches `proto2.kicad_sch` and `proto2.kicad_pcb` in open-aiq/hardware, and `src/board.rs` in open-aiq/device]
]
#line(length: 100%, stroke: 0.6pt + wood)

= How to read this

Proto2 is a carrier board. You plug an ESP32-S3 devkit into it, and the board connects it to a particle sensor, a temperature and humidity sensor, a small screen and three buttons. Everything is through-hole and all copper is on the bottom, so you can solder it by hand and have it made almost anywhere.

This document goes through the board one part at a time. For each part you'll find what it does, the number behind its value, and what would happen without it. Words in *bold* are defined in Keywords (§6). Numbers in brackets point to References (§7), with the table or section we relied on, like this: #rc("esp-ds", "Table 3-1").

#figure(
  image("renders/proto2-top.png", width: 100%),
  caption: [Proto2 rev C from the top. The devkit plugs into the two long sockets on the right, with its antenna past the top edge.],
)

= Pin choices

The ESP32-S3's #kw("matrix")[GPIO matrix] lets a UART, I²C or RMT peripheral use almost any GPIO #rc("esp-ds", "§4.1.3.1, Table 2-9"). So choosing pins is mostly about avoiding the ones that already have a job. Espressif marks the #kw("strapping")[strapping pins] and the USB pins "use with caution", and the pins wired to the in-package flash and PSRAM as already taken #rc("esp-ds", "§2.3.5"). Proto2 uses none of them.

#table(
  columns: (auto, 1.25fr, 2.6fr),
  table.header[GPIO][On Proto2][Why it's safe],
  [4, 5], [I²C SCL, SDA at 400 kHz], [Plain GPIOs with no boot, USB, flash or PSRAM role.],
  [6, 7, 15], [Left, pair and right buttons], [6 and 7 are plain GPIOs. 15 can drive a 32 kHz crystal (XTAL_32K_P) #rc("esp-ds", "Table 2-8"), but the devkit brings it out to its header as an ordinary pin #rc("devkit", "Header Block").],
  [8], [PMS5003 SET (output)], [Plain GPIO, not a strapping pin.],
  [16], [PMS5003 RESET (not driven yet)], [XTAL_32K_N, free for the same reason as 15.],
  [17, 18], [UART1 RX, TX at 9600 baud], [These are ADC2 pins, and ADC2 can't measure while Wi-Fi is on #rc("esp-ds", "§4.2.2.1, note"). We use them as a UART, not an ADC, so Wi-Fi doesn't matter. Their default UART1 roles are the other way round (17 TX, 18 RX) #rc("esp-ds", "Table 2-9")\; the GPIO matrix swaps them at no cost.],
  [48, 38], [Status LED (on the devkit)], [The devkit's RGB LED is on 48 on v1.0 and on 38 on v1.1 #rc("devkit", "Hardware Revision Details"). The firmware drives both with the same signal. Proto2 leaves both free.],
  [0, 3, 45, 46], [Unused], [Strapping pins. Their defaults give a normal SPI boot and 3.3 V flash: GPIO0 has a weak pull-up, 45 and 46 weak pull-downs, and 3 floats #rc("esp-ds", "Tables 3-1, 3-3, 3-4"). Leaving them unconnected keeps those defaults.],
  [19, 20], [Unused on Proto2], [USB D− and D+, wired to the devkit's USB port #rc("esp-ds", "Table 2-8, §2.3.4").],
  [26–32], [Not on the header], [In-package flash and PSRAM. Espressif says not to use them for anything else #rc("esp-ds", "§2.6, Table 2-14").],
  [35, 36, 37], [Unused], [Taken by the octal PSRAM on R8 modules, such as the N16R8 #rc("wroom", "Table 3-1, note b").],
  [43, 44], [Unused on Proto2], [UART0, the devkit's serial console.],
)

= The parts, one by one

== ESP32-S3-DevKitC-1 (U1)

+ *Sockets, not solder.* The devkit sits in two 1×22 female headers 25.4 mm apart, matching its J1 and J3 pin rows #rc("devkit", "Header Block"). You can lift it out to reuse it, or swap in another one if it fails.
+ *It powers the whole board.* The devkit takes power from either USB port, from its 5V and G pins, or from its 3V3 and G pins, and these are mutually exclusive #rc("devkit", "Power Supply Options"). Proto2 doesn't add a power input of its own: it takes 5 V from J1 pin 21 for the particle sensor and 3.3 V from pins 1 and 2, the devkit's regulator, for everything else. So never feed 5 V into the 5V pin while USB is plugged in.
+ *The antenna hangs off the top edge.* Espressif suggests placing the module's PCB antenna outside the base board, with its feed point near the board edge #rc("hdg", "§1.4.7"). On Proto2, 5.5 mm of the devkit's antenna end overhangs the top edge. The last 1.6 mm of board under it is a copper-free #kw("keepout")[keep-out], so no ground or track sits under the antenna.
+ *Ground pins are shared.* The devkit joins all of its GND pins internally, so the footprint marks them as one group and Proto2 doesn't need tracks between them.

== PMS5003 particle sensor (J1)

+ *Connector.* An 8-pin, 1.25 mm header carries 5 V, ground, SET, the UART pair and RESET, in the order the manual gives (PIN1 VCC to PIN8 NC) #rc("pms", "Pin Definition, Fig. 2"). Pins 7 and 8 stay unconnected, as the manual asks #rc("pms", "Circuit Attentions 3").
+ *5 V supply.* The sensor's fan needs 5 V: typically 5.0 V, at least 4.5 V and at most 5.5 V #rc("pms", "Technical Index"). It draws up to 100 mA while running and up to 200 µA asleep #rc("pms", "Technical Index"). Proto2 feeds it straight from the devkit's 5V pin on 0.8 mm tracks.
+ *Data connects directly.* The fan needs 5 V, but the sensor's data pins use 3.3 V logic, so a 3.3 V microcontroller needs no level shifter #rc("pms", "Circuit Attentions 1"). Its output is below 0.8 V when low and above 2.7 V when high #rc("pms", "Technical Index"). The ESP32-S3 reads low below 0.25 × 3.3 V = 0.83 V and high above 0.75 × 3.3 V = 2.48 V #rc("esp-ds", "Table 5-4"), so both levels clear the thresholds. The link runs at 9600 baud with no parity and one stop bit #rc("pms", "Appendix I").
+ *C1, 47 µF #kw("bulk")[bulk capacitor].* The fan starts every time the firmware wakes the sensor, once every five minutes. The 5 V comes a long way, through the USB cable and the devkit, and that path has resistance and inductance. C1 sits by the devkit's 5V pin and covers the step until that path catches up. As a rough illustration, a 100 mA step for 100 µs drops C1 by only $Delta V = I Delta t \/ C = 0.1 times 100 times 10^(-6) \/ (47 times 10^(-6)) approx 0.21 "V"$. Espressif makes the same recommendation for its chips: at least 10 µF where power enters a board #rc("hdg", "§1.3.2").

  *Why 47 µF and not more?* At plug-in, every capacitor on the 5 V rail charges at once, which causes #kw("inrush")[inrush current]. USB 2.0 limits a device to 10 µF across VBUS, so the host's supply droops by no more than 330 mV; a device that needs more must limit the surge itself #rc("usb", "§7.2.4.1, Table 7-7"). Proto2 doesn't meet that limit, and neither do most development boards. Hosts cope with it in practice, and 47 µF draws half the charge that the earlier 100 µF did. A product version would need a soft-start circuit.

  *Without it*, the 5 V rail could dip as the fan starts. Below 4.5 V the sensor may reset or report bad data.
+ *C2, 100 nF #kw("decoupling")[decoupling capacitor].* An electrolytic capacitor responds slowly to very fast edges. A small ceramic capacitor beside it handles the fast noise from the fan's motor #rc("aoe", "Ch. 1"). *Without it*, that noise rides along the 5 V track to the devkit.
+ *R3, 10 kΩ #kw("pull-up")[pull-up] on SET (GPIO 8).* SET high or unconnected means "run"; low means "sleep" #rc("pms", "Pin Definition"). The sensor has its own internal pull-ups on SET and RESET #rc("pms", "Circuit Attentions 2"), but while the ESP32-S3 is resetting and booting, GPIO 8 isn't driven at all. R3 holds SET firmly high through that time, even on a long, noisy cable. When the firmware pulls SET low to rest the sensor, R3 draws 3.3 V / 10 kΩ = 0.33 mA, far below the 28 mA a GPIO typically sinks #rc("esp-ds", "Table 5-4").
+ *R4, 10 kΩ pull-up on RESET (GPIO 16).* Low resets the sensor #rc("pms", "Pin Definition"). The firmware doesn't drive it yet, so R4 keeps the sensor out of reset; the wire is there for later. The current arithmetic is the same as for R3.
+ *Warm-up.* After the sensor wakes, its readings need at least 30 seconds to settle #rc("pms", "Circuit Attentions 4"). The firmware discards frames for those first 30 s (`PMS_WARM_UP_MS`).
+ *Placement.* The sensor lies on a marked bed with its vents facing the top edge, away from the devkit's warmth. No top-side copper runs under its metal case.

== OLED screen (J2)

+ *Pin order.* The 4-pin socket reads `GND VCC SCL SDA` from left to right. That's the order printed on the front of common 1.3 in modules, read face-up with the pins along the top, which is how the module lies on the board. Rev B had this row mirrored, which would have swapped 3.3 V and ground; rev C rotates the socket to fix it.
+ *Controller.* The SH1106 talks I²C at up to 400 kHz, at address 0x3C or 0x3D #rc("sh1106", "I²C-bus Interface; f" + sub[SCL]). Its logic runs from 1.65 V to 3.5 V #rc("sh1106", "Features"), and the module takes Proto2's 3.3 V.
+ *Orientation.* The firmware sends A1h and C8h, which reverse the column and row scan from the power-on defaults A0h and C0h #rc("sh1106", "Commands 6 and 13"). We expect this to read upright with the pin header at the top; the first power-up check (§5) confirms it. If yours shows upside down, the firmware's display setup tells you which bytes to swap.
+ *Keep-out.* The module lies flat over a marked area, and no part is placed there.

== SHT30 temperature and humidity sensor (J3)

+ *Supply.* The SHT30 runs from 2.15 V to 5.5 V #rc("sht", "§2.1, Table 3")\; Proto2 gives it 3.3 V.
+ *Address.* It answers at 0x44 with ADDR low and 0x45 with ADDR high #rc("sht", "§3.4, Table 8"). The breakout sets ADDR, and the firmware accepts either.
+ *Its own decoupling.* Sensirion asks for a 100 nF capacitor as close to the sensor as possible #rc("sht", "§3.1"). That belongs on the breakout, right beside the chip; C3 and C4 on Proto2 don't replace it.
+ *Away from heat.* Heat from nearby parts makes the sensor read warm, so Sensirion recommends #kw("thermal")[thermal decoupling] from all heat sources #rc("sht-guide", "Heating"). J3 sits in the bottom middle of the board, 44 mm from the devkit.
+ *Support pins.* Many breakouts have two more pins on the far edge, usually ADDR and ALERT. A 1×2 socket only holds them steady; they aren't connected. The datasheet says an unused ALERT must be left floating #rc("sht", "Table 7").

== I²C pull-ups (R1, R2)

+ *Why they're needed.* I²C lines are #kw("open-drain")[open-drain]: every device can only pull a line low. A pull-up returns it high #rc("sht", "§3.2").
+ *The lowest value allowed.* A device must be able to pull the line down to 0.4 V while sinking at most 3 mA #rc("ti", "Table 2-1, Eq. 1"):
  $ R_p (min) = (V_"CC" - V_"OL")/I_"OL" = (3.3 - 0.4) "V" / (3 "mA") approx 967 Omega $
+ *The highest value allowed.* In 400 kHz Fast-mode, the #kw("rise")[rise time] must stay under 300 ns #rc("ti", "Table 2-1, Eq. 6"):
  $ R_p (max) = t_r / (0.8473 times C_b) $
  We estimate Proto2's #kw("cb")[bus capacitance] generously at 60 pF: about 20 cm of track (SCL 199 mm, SDA 184 mm) and three devices with their module wiring. That gives $R_p (max) approx 300 "ns" \/ (0.8473 times 60 "pF") approx 5.9 "k" Omega$, well within the 400 pF limit #rc("sht", "Table 21").
+ *Why 4.7 kΩ.* It sits between those bounds, with a rise time of about $0.8473 times 4.7 "k" Omega times 60 "pF" approx 240 "ns"$ #rc("ti", "Eq. 5"). Most OLED and SHT30 breakouts carry their own pull-ups, which end up in parallel with R1 and R2. Two 10 kΩ breakout pull-ups bring the total to about 2.4 kΩ; even the worst case of two more 4.7 kΩ resistors gives 1.57 kΩ, still above 967 Ω. If you add a third I²C module, check that the combined value stays above that floor.

== 3.3 V capacitors (C3, C4)

+ *C3, 10 µF bulk, and C4, 100 nF decoupling,* sit where the 3.3 V track branches to the SHT30, the pull-ups and the screen. The OLED draws its current in pulses as it refreshes. These two capacitors supply those pulses locally, so they don't travel back along the track to the devkit's regulator. It's the same pairing of a bulk capacitor and a 100 nF capacitor that Espressif recommends near its chip #rc("hdg", "§1.3.2").
+ *Without them*, the board would most likely still work, because the devkit and the breakouts have capacitors of their own. C3 and C4 are a cheap margin against noise on a 23 cm supply track.

== Buttons (SW1, SW2, SW3)

+ *#kw("active-low")[Active-low] with no resistors.* Each button connects its GPIO to ground. The firmware turns on the chip's internal pull-up, typically 45 kΩ #rc("esp-ds", "Table 5-4"), so a pressed button draws only 3.3 V / 45 kΩ ≈ 73 µA.
+ *Clean levels.* A pressed button holds the pin at 0 V, well below the 0.83 V low threshold #rc("esp-ds", "Table 5-4").
+ *Debouncing in firmware.* The contacts bounce for a few milliseconds. The firmware ignores a new event within 150 ms of the last one, and holding left and right together for 3 s starts pairing.
+ *Four legs, two contacts.* Each 6 × 6 mm switch has two pairs of legs joined inside. Proto2 solders all four for strength.

= The board and its routing

+ *One copper layer.* All tracks are on the bottom and every part is through-hole, so any fab can make it and you can solder it with a basic iron. Even so, we suggest ordering it as a 2-layer board. That gives you #kw("pth")[plated through-holes], and the PMS5003 connector needs them: its pads are 0.8 × 1.3 mm around a 0.5 mm hole, leaving only 0.15 mm of copper on the narrow sides. That lifts easily on an unplated hole.
+ *Track width and clearance.* Signal tracks are 0.3 mm wide with 0.25 mm clearance, so one track fits between two header pins 2.54 mm apart (pad 1.7 mm, gap 0.84 mm ≥ 0.3 + 2 × 0.25 mm). Power tracks are 0.8 mm. A #kw("netclass")[net class] sets these widths for each group of nets.
+ *Plenty of current headroom.* With 35 µm copper on an outer layer and a 10 °C temperature rise, the curve fit for the IPC chart #rc("ipc", "§6.2, Fig. 6-4") gives about 2.0 A for a 0.8 mm track and 1.0 A for a 0.3 mm track. Proto2's biggest load is the particle sensor at up to 100 mA #rc("pms", "Technical Index").
+ *Ground.* A #kw("fill")[ground fill] covers the free bottom copper, and tracks join the ground pins it can't reach. Ground tracks are 0.8 mm wherever the clearance rules allow. Between the devkit's header pins and the 3.3 V track there's only room for 0.3 mm. The particle sensor's return path from J1 to the devkit's ground pin is 31 mm long and about 43 mΩ. At 100 mA, that's a 4.3 mV drop, which the sensor never notices. C1's return is 10 mm of 0.8 mm track, about 6 mΩ. (Copper resistivity 1.72 × 10#super[−8] Ω·m, 35 µm thick.)
+ *Edges and holes.* Copper stays at least 0.5 mm from the board edge. The smallest hole is 0.5 mm, for the PMS5003 connector. Four M3 mounting holes sit 4 mm in from each corner.
+ *Keep-outs.*
  - The strip under the antenna has no copper (§3.1).
  - The PMS5003 bed has no top-side copper under the sensor's metal case.
  - The OLED area has no parts under the module.

= First power-up

+ *Check the PMS5003 cable with a multimeter.* Pin 1 on the sensor must reach pin 1 (5 V) on J1. Some 1.25 mm cables come wired in reverse. That won't damage anything, but the sensor stays silent.
+ *Measure the 5 V at J1 pin 1 with the fan running.* It should be at least 4.5 V #rc("pms", "Technical Index"). A long or thin USB cable can pull it lower.
+ *Read the serial log.* The I²C scan at boot should find 0x3C (OLED) and 0x44 (SHT30).
+ *Look at the screen.* It should read upright with the pins at the top (§3.3).
+ *Watch the status LED on the devkit.* It lights on both v1.0 and v1.1 boards.

= Keywords

Each term below has exactly one meaning in this document.

#for (key, term, def) in keywords [
  #block(above: 0.75em, below: 0.75em)[
    #text(weight: "bold", fill: accent)[#term]#label("kw-" + key) \
    #def
  ]
]

= References

#set par(justify: false)
#for (i, r) in refs.enumerate() [
  #block(above: 0.8em, below: 0.8em, breakable: false)[
    #grid(
      columns: (2.2em, 1fr),
      [\[#(i + 1)\]],
      [
        #r.entry #label("ref-" + r.key) \
        #text(size: 9pt)[_Used here:_ #r.used] \
        #text(size: 8.5pt)[#link(r.url)]
      ],
    )
  ]
]
