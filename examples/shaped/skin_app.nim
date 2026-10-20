## A non-rectangular RUI app: the window is the shape of skin.png.
##
##   nim c -r examples/shaped/skin_app.nim      (skin_app.nims adds -d:ruiShaped)
##
## The method is chosen when the window opens -- see-through with soft edges
## where a compositor runs, clipped by the OS where not -- and printed. Drag
## the background to move the window; the buttons keep their clicks.

import rui
import std/os

let app = newApp("RUI2 - Shaped", 420, 420)
app.setTheme("midnight")
app.setWindowShape(currentSourcePath().parentDir / "skin.png")   # the window takes its size
app.placeShape(60, 40)       # the visible shape's corner, not the window's (the skin has a margin)

var count = 0
let counter = newLabel(text = "Clicked 0 times").named("counter")
let root = ui:
  # Laid out in the shape's box (the skin stops short of the window's corner),
  # so the padding counts from the shape, not the window.
  Column(spacing = 10.0, padding = EdgeInsets(left: 50, top: 120, right: 130, bottom: 0),
         crossAxisAlignment = CrossAxisAlignment.start):
    Label(text = "A shaped window", bold = true)
    Label(text = "Drag me to move")
    Embed(counter)
    Row(spacing = 8.0):
      Button(text = "Click me", onClick = proc() =
        inc count
        counter.text = "Clicked " & $count & " times").named("clickBtn")
      Button(text = "Close", onClick = proc() = app.shouldClose = true).named("closeBtn")

app.setRootWidget(root)
app.enableScripting(getAppDir() / "script")
app.run()
