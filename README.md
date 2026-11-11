# Open AIQ hardware

PCB designs (KiCad) for the Open AIQ air-quality monitor.
Firmware lives in [open-aiq/device](https://github.com/open-aiq/device); its
[`src/board.rs`](https://github.com/open-aiq/device/blob/main/src/board.rs) is the source of truth for the GPIO map.

## Layout

| Path | Contents |
| --- | --- |
| `pcb/proto2/` | Prototype 2: carrier PCB for the ESP32-S3 devkit with sensor connectors |
| `lib/` | Our own symbols and footprints, shared by every board |
| `scripts/` | `export.sh`, which builds a board's outputs from the command line |

Each PCB folder holds the KiCad project, the schematic and assembly PDFs, and
the fabrication outputs (Gerbers and BOM) under `fab/`. Its README
covers the parts, the pin map and what to check before you build.

Still to come: an SMT board with the ESP32-S3 module on it (in progress on the
`smt` branch), a battery-powered revision, and a 3D-printed enclosure.

## Working in KiCad

Everything here is a normal KiCad 10 project, and the KiCad files are the source
of truth. Open `pcb/<board>/<board>.kicad_pro` and edit the schematic and board
as you would any other design.

- **Libraries need no setup.** Our own symbols and footprints live in
  [`lib/`](lib), and each project finds them through `${KIPRJMOD}`. A part we've
  adapted, like the ESP32-S3 module with JLCPCB-sized vias, is saved there under
  its own name, so *Update footprints from library* keeps our changes.
- **Rules live in the project.** Net classes (wider power tracks), clearances and
  via sizes are set in *Board Setup*, so DRC is ready to go. The board opens
  with zero ERC and DRC messages. If you see one, it's new.
- **Outputs come from a jobset.** Open `<board>.kicad_jobset` from the project
  window (or *File → Jobsets*) and run it. It checks ERC and DRC, then writes the
  schematic PDF, an assembly drawing with every reference designator, Gerbers,
  drill files, the BOM and, for the SMT board, placement and JLCPCB BOM files.
- **The command line runs the same jobset.** From the repo root,
  `scripts/export.sh pcb/<board>` runs it with `kicad-cli`, then adds what KiCad
  doesn't make on its own: a zipped Gerber set, a JLCPCB-format placement file
  and 3D renders.

Please commit your KiCad edits and the regenerated outputs together, so the PDFs
and fab files always match the design.

## Roadmap

Planned work is tracked on the [Open AIQ Roadmap](https://github.com/orgs/open-aiq/projects/1) board.
