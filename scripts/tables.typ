// The board's BOM and placement (CPL) files as A4 tables, for <board>.pdf.
// scripts/export.sh compiles it with --root at the repository root and these
// inputs: title, rev, and bom and cpl (CSV paths from the root; either may be
// empty). Columns that are empty on every row are left out.
#let title = sys.inputs.at("title", default: "")
#let rev = sys.inputs.at("rev", default: "")
#let bom = sys.inputs.at("bom", default: "")
#let cpl = sys.inputs.at("cpl", default: "")

#set document(title: title + " BOM and placement")
#set page(paper: "a4", margin: 14mm)
#set text(font: "Libertinus Serif", size: 9pt)
#set par(justify: false)
#set table(
  stroke: (x, y) => (bottom: if y == 0 { 0.8pt } else { 0.3pt + luma(200) }),
  inset: (x: 5pt, y: 4pt),
)
#show table.cell.where(y: 0): set text(weight: "bold")

#let sheet(path, label, note) = {
  let rows = csv("/" + path)
  let head = rows.first()
  let body = rows.slice(1)
  let keep = range(head.len()).filter(i => body.any(r => r.at(i, default: "").trim() != ""))
  // Long columns share the spare width; long names may wrap after _ : / and -
  let widths = keep.map(i => if body.any(r => r.at(i, default: "").len() > 24) { 1fr } else { auto })
  let cell(t) = t.replace(regex("([_:/-])"), m => m.text + "\u{200B}")
  grid(
    rows: (auto, auto),
    row-gutter: 5mm,
    [*#title* #h(1fr) #if rev != "" [Rev #rev · ] #label],
    [
      #text(size: 8.5pt, fill: luma(90), note)
      #v(2mm)
      #table(
        columns: widths,
        table.header(..keep.map(i => head.at(i))),
        ..body.map(r => keep.map(i => cell(r.at(i, default: "")))).flatten(),
      )
    ],
  )
}

#let pages = ()
#if bom != "" {
  pages.push(sheet(bom, "Bill of materials", [From #raw(bom.split("/").last()).]))
}
#if cpl != "" {
  pages.push(sheet(cpl, "Component placement (CPL)", [From #raw(cpl.split("/").last()). Positions are part centres in KiCad's page coordinates, in mm; rotation is in degrees.]))
}
#pages.join(pagebreak())
