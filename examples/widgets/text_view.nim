## A long text, scrolled: TextView over a file, read only as far as it is shown.
##
## The wheel, Up/Down, PageUp/PageDown and Home/End scroll by lines; the scroll
## bar jumps to a paragraph. The status line shows where the top of the view is
## -- a text position, what a reader saves to reopen at the same place.
##
##   nim c -r -d:useGraphics examples/widgets/text_view.nim [theme] [file.txt]
##
## Without a file it writes a long sample one to the temp directory.

import rui
import std/os

let app = newApp("RUI2 - TextView", 720, 560)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "forest")

proc textPath(): string =
  if paramCount() >= 2: return paramStr(2)
  result = getTempDir() / "rui_text_view_sample.txt"
  if not fileExists(result):
    var text = ""
    for chapter in 1 .. 2000:
      text.add "Chapter " & $chapter & "\n\n"
      text.add "Only the lines on the screen are wrapped and drawn, and only the " &
               "paragraphs they come from are read from the file, in the background. " &
               "The rest of this long file is never loaded until it is scrolled to.\n\n"
    writeFile(result, text)

var status: Label
var view: TextView

let root = ui:
  Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch,
         padding = EdgeInsets.all(12.0)):
    status = Label(text = "paragraph 1").named("status")
    Expanded():
      view = TextView(source = newLinesSource(textPath()), fontSize = 18.0,
                      fontFamily = "Serif",
                      onScroll = proc(top: TextPos) =
                        status.text = "paragraph " & $(top.row + 1) &
                                      ", line " & $(top.line + 1)).named("text")

app.setRootWidget(root)
app.focusManager.setFocus(view)
app.start()
