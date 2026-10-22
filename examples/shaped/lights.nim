## Christmas lights round a shaped window: the skin's outline is traced (in
## order, clockwise from its top-left) and the lights run along it.
##
##   nim c -r examples/shaped/lights.nim      (lights.nims adds -d:ruiShaped)
##
## `app.windowOutline` is that traced path, in window coordinates; pass your
## own points instead with `adornWindow(effect, path = some(newPath(...)))`.
## Without a compositor the window is clipped by the OS with hard edges, so
## the lights sit a few pixels inside it (`inset`).

import rui
import std/[os, options]

let app = newApp("RUI2 - Lights", 420, 420)
app.setTheme("midnight")
app.setWindowShape(currentSourcePath().parentDir / "skin.png")
app.placeShape(60, 40)

let root = ui:
  Column(spacing = 10.0, padding = EdgeInsets(left: 50, top: 120, right: 130, bottom: 0),
         crossAxisAlignment = CrossAxisAlignment.start):
    Label(text = "Lights along the outline", bold = true)
    Label(text = "Drag me to move")
    Button(text = "Close", onClick = proc() = app.shouldClose = true).named("closeBtn")

app.adornWindow(leds(spacing = 18), inset = 7)
echo "  Outline: ", app.windowOutline.points.len, " points, ",
     int(app.windowOutline.length), " px round"
app.setRootWidget(root)
app.run()
