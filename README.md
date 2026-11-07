# Open AIQ hardware

PCB designs (KiCad) and the 3D-printed enclosure for the Open AIQ air-quality monitor.
Firmware lives in [open-aiq/device](https://github.com/open-aiq/device); its
[`src/board.rs`](https://github.com/open-aiq/device/blob/main/src/board.rs) is the source of truth for the GPIO map.

## Layout

| Path | Contents |
| --- | --- |
| `pcb/proto2/` | Prototype 2: carrier PCB for the ESP32-S3 devkit with sensor connectors |
| `pcb/smt/` | SMT prototype with the ESP32-S3 module on board |
| `pcb/smt-battery/` | SMT revision with battery, charger and power path |
| `enclosure/` | 3D-printed body (source + STL), shared by the SMT and SMT+battery boards |

Each PCB folder holds the KiCad project, BOM, fabrication outputs (Gerbers, drill, pick-and-place) and a bring-up checklist.

## Roadmap

Planned work is tracked on the [Open AIQ Roadmap](https://github.com/orgs/open-aiq/projects/1) board.
