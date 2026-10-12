## The gallery: every widget on screen, in tabs.
##
##   nim c -r -d:useGraphics examples/gallery/gallery.nim [theme] [--tab N]
##   nim c -r -d:useGraphics -d:ruiInspect -d:ruiTestKeys examples/gallery/gallery.nim \
##       --script DIR              # scripting + visual probe (tools/gallery_probe.sh)
##
## With `--script DIR` the app listens for commands in DIR (commands.txt) and
## answers in responses.txt; see docs/visual-testing.md. `--live` starts the
## Live tab's ticker on its own.

import rui
import std/[os, strutils, monotimes, times]
import gallery_ui

var theme = "daylight"
var scriptDir = ""
var startTab = 0
var startLive = false
var only = -1
var i = 1
while i <= paramCount():
  let a = paramStr(i)
  case a
  of "--script": inc i; scriptDir = paramStr(i)
  of "--tab": inc i; startTab = parseInt(paramStr(i))
  of "--live": startLive = true
  of "--only": inc i; only = parseInt(paramStr(i)); startTab = only
  else: theme = a
  inc i

let app = newApp("RUI2 - Gallery", 1000, 720)
app.setTheme(theme)
let gallery = buildGallery(only)
gallery.tabs.activeTab = startTab
if startLive: gallery.live.running.value = true
app.onFrame = proc() = gallery.stepLive()
app.setRootWidget(gallery.root)
if scriptDir.len > 0:
  app.enableScripting(scriptDir)
  app.setScriptPollInterval(0.0)
app.run()
