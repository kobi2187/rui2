## TextArea
##
## Multi-line text editing: Enter inserts a newline, Up and Down move by line,
## and the shared text engine measures and draws it.
##
##   nim c -r -d:useGraphics examples/widgets/textarea.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/os

let app = newApp("RUI2 - TextArea", 520, 420)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

var notes: TextArea
var echoLabel: Label

let root = ui:
  VStack(spacing = 12.0, padding = 20.0):
    Label(text = "Notes — Enter makes a new line", fontSize = 16.0)
    notes = TextArea(initialText = "First line\nSecond line",
                     visibleLines = 8, fontSize = 14.0)
    Label(text = "Single-line, for comparison — Enter submits:", fontSize = 12.0)
    TextInput(initialText = "one line only", fontSize = 14.0)
    echoLabel = Label(text = "", fontSize = 12.0)

root.stringId = "root"
notes.stringId = "notes"
echoLabel.stringId = "echo"

notes.onChange = proc(t: string) =
  echoLabel.text = $lineStarts(t).len & " lines, " & $t.len & " characters"
  echoLabel.layoutDirty = true
  echoLabel.markDirtyToRoot()

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
