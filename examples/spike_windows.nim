## SPIKE: several windows in one app, one shared Store.
##
##   nim c -r -d:useGraphics examples/spike_windows.nim            # 3 windows
##   nim c -r -d:useGraphics examples/spike_windows.nim churn      # open/close, prints RSS
##   nim c -r -d:useGraphics examples/spike_windows.nim idle       # 5 windows, then idle

import rui
import std/[os, strutils, strformat]

let app = newApp("RUI2 - windows spike", 900, 600)
app.setTheme("daylight")

let store = newStore()
let name = store.declare("name", "Ada")
let level = store.declare("level", 40.0'f32)
let host = newVStack()

proc content(): Widget =
  ui:
    Column(spacing = 6.0, crossAxisAlignment = CrossAxisAlignment.start):
      Label(text = -> "Hello, {name}")
      TextInput(text = <-> name).size(200, 30)
      Slider(value = <-> level).size(200, 28)
      DatePicker(initialValue = "2026-10-11")

var counter = 0
proc spawn(x, y: float32): Window =
  inc counter
  result = newWindow(title = "Window", x = x, y = y, width = 280, height = 250)
  result.addChild content()
  host.openWindow result

proc rss(): int =
  for line in readFile("/proc/self/status").splitLines:
    if line.startsWith("VmRSS:"): return parseInt(line.splitWhitespace()[1])

let mode = if paramCount() >= 1: paramStr(1) else: ""
host.addChild newLabel(text = "page behind the windows")

if mode == "churn" or mode == "steady":
  var open: seq[Window]
  var frame = 0
  app.onFrame = proc() =
    inc frame
    if mode == "churn" or frame == 1:
      open.add spawn(float32(20 + frame mod 300), float32(40 + frame mod 200))
      if frame == 1:
        for i in 0 ..< 2: open.add spawn(float32(60 + i * 50), 60)
    if open.len > 3:
      closeWindow(open[0])
      open.delete(0)
    if frame mod 100 == 0:
      echo &"frame {frame}  windows {open.len}  overlays {overlays().len}  " &
           &"links {name.dependentCount}+{level.dependentCount}  rss {rss()} kB  nim {getOccupiedMem() div 1024} kB  map {app.tree.widgetMap.len}"
  app.setRootWidget(host)
  app.run(maxFrames = 800)
else:
  let n = (case mode
           of "idle": 5
           of "bare": 0
           of "one": 1
           else: 3)
  for i in 0 ..< n: discard spawn(float32(30 + i * 60), float32(30 + i * 45))
  app.setRootWidget(host)
  app.run()
