## Dialogs
##
## MessageBox and FileDialog as modals, FilePicker embedded in the page.
##
## The two modals size their bounds to the whole screen. That is not laziness:
## renderPass draws every widget into a render texture sized to its own bounds,
## so a dialog sized to its panel could not dim anything around itself.
##
##   nim c -r -d:useGraphics examples/widgets/dialogs.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, sets, strutils]

let app = newApp("RUI2 - Dialogs", 680, 560)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")
let summary = newLabel(text = "no dialog result yet", fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

# MessageBox ---------------------------------------------------------------
let confirm = newMessageBox(title = "Confirm", message = "Discard changes?",
                            messageType = mbQuestion,
                            buttons = mbYesNoCancel).named("confirm")
confirm.onClose = some(proc(res: MessageBoxResult) {.closure.} =
  report("messagebox -> " & $res))

let askBtn = newButton(text = "Show MessageBox").named("askBtn")
askBtn.onClick = some(proc() {.closure.} = confirm.show())
root.addChild(askBtn)

# FileDialog ---------------------------------------------------------------
let picker = newFileDialog(title = "Open a Nim file", mode = fdOpen,
                           filters = @["*.nim"], initialPath = ".",
                           dialogWidth = 600.0,
                           dialogHeight = 400.0).named("fileDialog")
picker.onSelect = some(proc(files: seq[string]) {.closure.} =
  report("filedialog -> " & files.join(", ")))
picker.onCancel = some(proc() {.closure.} = report("filedialog cancelled"))

let openBtn = newButton(text = "Show FileDialog").named("openBtn")
openBtn.onClick = some(proc() {.closure.} = picker.show())
root.addChild(openBtn)

# FilePicker: not modal, just a widget -------------------------------------
root.addChild(newLabel(text = "Embedded FilePicker (double-click a folder to enter):",
                       fontSize = 14.0).named("t1"))
let embedded = newFilePicker(mode = fpOpen, filters = @["*.nim"],
                             initialPath = ".", multiSelect = true).named("embedded")
embedded.bounds = Rect(x: 0, y: 0, width: 600, height: 260)
embedded.onSelect = some(proc(paths: HashSet[string]) {.closure.} =
  var picked: seq[string] = @[]
  for p in paths:
    picked.add(extractFilename(p))
  report("picker -> " & picked.join(", ")))
embedded.onPathChange = some(proc(path: string) {.closure.} =
  report("picker path -> " & path))
root.addChild(embedded)

# Modals are drawn last so they sit on top of everything else.
root.addChild(confirm)
root.addChild(picker)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
