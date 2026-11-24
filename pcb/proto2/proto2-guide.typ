// Proto2: one-page hand assembly guide, for proto2.pdf.
// scripts/export.sh compiles it with --root at the repository root and the
// inputs title and rev. Keep it to one A4 page.
#let title = sys.inputs.at("title", default: "Proto2")
#let rev = sys.inputs.at("rev", default: "")

#set document(title: title + " hand assembly guide")
#set page(paper: "a4", margin: (x: 14mm, y: 12mm))
#set text(font: "Libertinus Serif", size: 9.5pt)
#set par(justify: false, leading: 0.55em, spacing: 0.75em)
#set enum(spacing: 0.75em)
#show heading: set text(size: 11pt)
#show heading: set block(above: 0.9em, below: 0.5em)

#grid(
  rows: (auto),
  [*#title* #h(1fr) #if rev != "" [Rev #rev · ] Hand assembly guide],
)
#v(1mm)
#line(length: 100%, stroke: 0.5pt)

#align(center, image("renders/proto2-top.png", height: 75mm))

Every part goes in from the top and is soldered underneath, where the tracks
are. We solder the lowest parts first, so the board rests flat on them
when you turn it over. The silkscreen names every part, and the BOM and
placement pages that follow list where each one sits.

= Solder, lowest first

+ *R1 and R2, 4.7 kΩ resistors* (under the OLED). Bend the legs close to the
  body for the 7.62 mm pitch and lay them flat. Either way round works. On
  4-band parts, 4.7 kΩ is yellow-violet-red; if yours have five bands,
  measure them.
+ *SW1–SW3, buttons.* They click into place and only fit with the legs lined
  up with the holes. Either of those two ways round works.
+ *C1–C4, capacitors* (between the devkit sockets). They lie flat: push the
  legs through, then fold the body down over the outline drawn beside its
  pads, so the devkit clears them. C2 and C4 (100 nF ceramic) go either way
  round. C1 (47 µF) and C3 (10 µF) are electrolytic and have a polarity: the
  long leg (+) goes in the square pad by the `+`, and the stripe on the can
  sits over the striped side of the outline.
+ *J3 and J6, SHT30 sockets* (a 1×4 and a 1×2), *J2, OLED socket* (1×4), and *J1,
  PMS5003 socket* (1×4). Solder one pin, check the socket stands square, then
  do the rest.
+ *J4 and J5, the two 1×22 devkit sockets.* Plug the devkit into both, set it on the
  board, and solder the four end pins. That lines the sockets up. Then take
  the devkit out and solder the rest.

= Before you plug anything in

- Look over the bottom for solder bridges, and check 5 V and 3.3 V aren't
  shorted to ground with a multimeter.
- On a clone devkit, bridge the `IN-OUT` pad next to its 5V pin, or the
  PMS5003 gets no power.
- Hold the OLED face-up with its pins along the top: its labels should read
  `GND VCC SCL SDA`, like the socket. Some modules swap GND and VCC.

= Fit the modules

The devkit's USB end faces the bottom edge and its antenna hangs past the top.
The OLED goes in face-up and lies over its box. The SHT30 reads
`SDA SCL GND VIN`. The PMS5003's 4-wire cable plugs into J1 so its pins read
`TX RX VCC GND`, like the socket, and the sensor sits on its bed, vents to the top edge, held with
four M2 screws from below or foam tape. Then work through _First power-up_ in
the README.
