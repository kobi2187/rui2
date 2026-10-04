## Small controls: Switch, SegmentedControl, Rating, Sparkline, and a Toast.
##
##   nim c -r -d:useGraphics examples/widgets/small_controls.nim [theme]
##
## Click, or Tab to a control and use Space / the arrow keys. The Save button
## shows a toast.

import rui
import std/os

let app = newApp("RUI2 - Small controls", 700, 420)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

var status: Label
let root = ui:
  Padding(padding = EdgeInsets.all(24.0)):
    Column(spacing = 18.0, crossAxisAlignment = CrossAxisAlignment.start):
      Label(text = "Small controls", fontSize = 24.0, bold = true)
      Switch(text = "Notifications", initialOn = true,
             onToggle = proc(on: bool) = status.text = "notifications " & (if on: "on" else: "off"))
      Switch(text = "Dark mode")
      SegmentedControl(options = @["Day", "Week", "Month"], initialSelectedIndex = 1,
                       onSelect = proc(i: int) = status.text = "range " & $i)
      Row(spacing = 12.0):
        Label(text = "Rate it")
        Rating(initialValue = 3, onRate = proc(v: int) = status.text = "rated " & $v)
      Row(spacing = 12.0):
        Label(text = "Last 12 weeks")
        Sparkline(values = @[3.0, 5.0, 4.0, 6.0, 5.5, 8.0, 7.0, 9.0, 8.5, 11.0, 10.0, 12.0])
          .frame(width = 140, height = 32)
      Button(text = "Save", intent = ThemeIntent.Info,
             onClick = proc() = app.toast("Saved")).shortcut("Ctrl+S")
      status = Label(text = "", fontSize = 13.0)

app.setRootWidget(root)
app.run()
