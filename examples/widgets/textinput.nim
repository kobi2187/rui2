## TextInput
##
## Typing, click-to-place-caret, drag to select, shift+arrows to extend, and
## Enter to submit. Caret geometry and hit-testing both go through Pango, so
## they agree with the glyphs actually on screen.
##
##   nim c -r -d:useGraphics examples/widgets/textinput.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - TextInput", 520, 320)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

let echoLabel = newLabel(text = "(nothing typed)", fontSize = 15.0).named("echo")
let submitted = newLabel(text = "", fontSize = 14.0).named("submitted")

let input = newTextInput(initialText = "", placeholder = "Type something...",
                         fontSize = 16.0, maxLength = 40).named("input").frame(width = 440, height = 36)

input.onChange = proc(newText: string) =
  echoLabel.text = if newText.len > 0: newText else: "(nothing typed)"
  echoLabel.isDirty = true
  echoLabel.layoutDirty = true

input.onSubmit = proc(text: string) =
  submitted.text = "submitted: " & text
  submitted.isDirty = true
  submitted.layoutDirty = true

root.addChild(newLabel(text = "Click to focus, then type:",
                       fontSize = 14.0).named("t1"))
root.addChild(input)
root.addChild(echoLabel)
root.addChild(submitted)

let capped = newTextInput(initialText = "max 8 chars", maxLength = 8,
                          fontSize = 14.0).named("capped").frame(width = 200, height = 30)
root.addChild(newLabel(text = "maxLength = 8:", fontSize = 14.0).named("t2"))
root.addChild(capped)

# Bullets on screen; never copied, never readable by scripts.
let secret = newPasswordInput(fontSize = 14.0).named("password").frame(width = 200, height = 30)
root.addChild(newLabel(text = "Password:", fontSize = 14.0).named("t3"))
root.addChild(secret)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
