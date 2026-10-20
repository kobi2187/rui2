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
app.setWindowShape(currentSourcePath().parentDir / "skin.png")

var count = 0
let counter = newLabel(text = "Clicked 0 times").named("counter")
let root = ui:
  Column(spacing = 10.0, padding = EdgeInsets(left: 70, top: 130, right: 150, bottom: 0),
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
