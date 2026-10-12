## Pickers and friends: DatePicker, TimePicker, ColorPicker, Autocomplete,
## RangeSlider, SearchInput, Icon and a Dialog.
##
##   nim c -r -d:useGraphics examples/widgets/pickers.nim [theme]

import rui
import std/os

let app = newApp("RUI2 - Pickers", 760, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

let due = newLink("2026-10-11")
let alarm = newLink("07:30")
let accent = newLink("#3366cc")

var dialog: Dialog
let root = ui:
  Stack():
    Padding(padding = EdgeInsets.all(24.0)):
      Column(spacing = 14.0, crossAxisAlignment = CrossAxisAlignment.start):
        Label(text = "Pickers", fontSize = 24.0, bold = true)
        Row(spacing = 12.0):
          Label(text = "Due")
          DatePicker(value = <-> due)
          Label(text = -> "{due}")
        Row(spacing = 12.0):
          Label(text = "Alarm")
          TimePicker(value = <-> alarm)
          Label(text = -> "{alarm}")
        Row(spacing = 12.0):
          Label(text = "Accent")
          ColorPicker(value = <-> accent)
          Label(text = -> "{accent}")
        Row(spacing = 12.0):
          Label(text = "City")
          Autocomplete(suggestions = @["Berlin", "Bern", "Bergen", "Bremen", "Hamburg"],
                       placeholder = "Type ber...").size(200, 32)
        Row(spacing = 12.0):
          Label(text = "Price")
          RangeSlider(initialLow = 20, initialHigh = 70).size(240, 28)
        Row(spacing = 12.0):
          SearchInput(initialText = "clear me").size(240, 32)
          Icon(glyph = "⚙", size = 22, onClick = proc() = dialog.show())
    dialog = Dialog(title = "Settings", dialogWidth = 320):
      Column(spacing = 10.0):
        Label(text = "A dialog holds any widgets.")
        Checkbox(text = "Remember me")
        Button(text = "Close", onClick = proc() = dialog.close())

app.setRootWidget(root)
app.run()
