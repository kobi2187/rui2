## In-app windows (the optional rui_windows module): several movable,
## resizable, closable windows over one page, all sharing one Store.
##
##   nim c -r -d:useGraphics examples/widgets/windows.nim
##
## Drag a title bar, drag a border, click a window behind to raise it, press
## Tab (it stays in the active window), close with the x or Escape.

import rui, rui_windows

let app = newApp("RUI2 - windows", 900, 600)
app.setTheme("daylight")

let store = newStore()
let name = store.declare("name", "Ada")
let level = store.declare("level", 40.0'f32)
let host = newVStack()

var count = 0
proc spawn() =
  inc count
  let w = newWindow(title = "Window " & $count,
                    x = float32(40 + (count mod 6) * 36),
                    y = float32(80 + (count mod 6) * 30),
                    width = 300, height = 260, closeOnEscape = true)
  w.addChild:
    ui:
      Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.start):
        Label(text = -> "Hello, {name}")
        TextInput(text = -> name, onChange = name.setter).size(220, 30)
        Slider(value = -> level, onChange = level.setter).size(220, 28)
        DatePicker(initialValue = "2026-10-11")
  host.openWindow w

host.addChild:
  ui:
    Column(spacing = 12.0, crossAxisAlignment = CrossAxisAlignment.start):
      Label(text = "The page behind the windows")
      Button(text = "New window", onClick = proc() = spawn())

spawn()
spawn()
app.setRootWidget(host)
app.run()
