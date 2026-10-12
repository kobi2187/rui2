## An app whose UI is a .yui file: load it, give it handlers, run.
##
##   nim c -r -d:useGraphics examples/widgets/yui_app.nim [file.yui]
##
## The file (examples/yui/settings.yui) names its state, binds widgets to it
## and refers to actions as `save/0`; this program supplies the actions.

import rui
import std/[os, json, tables]

let path = if paramCount() >= 1: paramStr(1) else: "examples/yui/settings.yui"
let store = newStore()

var actions: YuiActions
actions["save/0"] = proc (args: JsonNode) =
  echo "saved: ", store.format("{name}, notifications={notifications}, volume={volume}")
actions["reset/0"] = proc (args: JsonNode) =
  store.set("name", "")
  store.set("volume", 0)
  store.set("notifications", false)

let doc = loadYui(path, store, actions)
for warning in doc.warnings: stderr.writeLine "yui: " & warning

let app = newApp(doc.title, doc.width, doc.height)
app.setRootWidget(doc.root)
app.run()
