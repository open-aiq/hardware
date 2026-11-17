// The board's 3D renders as A4 landscape pages, one per view, for the end of
// <board>.pdf. scripts/export.sh compiles it with --root at the repository
// root and these inputs: dir (the board folder), name, title and rev.
#let dir = sys.inputs.at("dir")
#let name = sys.inputs.at("name")
#let title = sys.inputs.at("title", default: name)
#let rev = sys.inputs.at("rev", default: "")

#set document(title: title + " 3D renders")
#set page(paper: "a4", flipped: true, margin: 14mm)
#set text(font: "Libertinus Serif", size: 11pt)

#let views = (
  ("iso", "3D view"),
  ("top", "Top"),
  ("bottom", "Bottom"),
)

#for (i, (view, label)) in views.enumerate() {
  if i > 0 { pagebreak() }
  grid(
    rows: (auto, 1fr),
    row-gutter: 6mm,
    [*#title* #h(1fr) #if rev != "" [Rev #rev · ] #label · 3D render, not to scale],
    align(center + horizon, image("/" + dir + "/renders/" + name + "-" + view + ".png", fit: "contain", width: 100%, height: 100%)),
  )
}
