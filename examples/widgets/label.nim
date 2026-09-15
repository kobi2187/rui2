## Label
##
## Text with weight, style, family, alignment, wrapping and Pango markup.
## A Label measures itself, so stacks can arrange labels without hand-set bounds.
##
##   nim c -r -d:useGraphics examples/widgets/label.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Label", 560, 420)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

root.addChild(newLabel(text = "Plain label", fontSize = 16.0).named("plain"))
root.addChild(newLabel(text = "Bold", fontSize = 16.0, bold = true).named("bold"))
root.addChild(newLabel(text = "Italic", fontSize = 16.0, italic = true).named("italic"))
root.addChild(newLabel(text = "Serif family", fontSize = 16.0,
                       fontFamily = "DejaVu Serif").named("serif"))
root.addChild(newLabel(text = "Coloured", fontSize = 16.0,
                       color = Color(r: 40, g: 110, b: 190, a: 255)).named("coloured"))
root.addChild(newLabel(text = "Right aligned", fontSize = 16.0,
                       align = TextAlign.Right).named("right"))
root.addChild(newLabel(
  text = "Markup: <b>bold</b>, <i>italic</i>, " &
         "<span foreground='#c0392b'>red</span>, x<sup>2</sup>",
  fontSize = 16.0, markup = true).named("markup"))
root.addChild(newLabel(
  text = "A wrapping paragraph. Pango breaks the lines itself, so the " &
         "break points respect the font's real advance widths.",
  fontSize = 14.0, wrap = true).named("wrapped"))

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
