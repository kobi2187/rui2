## The keyboard help overlay: F1 or ? shades the window; the general navigation
## keys run along the top (the user's own bindings), and each widget that has a
## shortcut gets a badge with its keys beside it.
##
##   nim c -r -d:useGraphics examples/widgets/help_overlay.nim [theme]
##
## Shortcuts are real: Ctrl+S, Ctrl+O and F5 press their buttons. This one opens
## the overlay at startup; normally the user asks for it. Any key or click closes
## it. A "?" typed into a text field is typing, not a request for help.

import rui
import std/os

let app = newApp("RUI2 - Help overlay", 900, 420)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")
app.addHelp("Ctrl+F", "find in the document")        # a shortcut with no widget

var status: Label
let root = ui:
  VStack(spacing = 12.0, padding = 24.0):
    Label(text = "Notes", fontSize = 24.0, bold = true)
    Row(spacing = 8.0):
      Button(text = "Open", onClick = proc() = status.text = "opened").shortcut("Ctrl+O")
      Button(text = "Save", intent = ThemeIntent.Info,
             onClick = proc() = status.text = "saved").shortcut("Ctrl+S")
      Button(text = "Run", onClick = proc() = status.text = "ran").shortcut("F5")
    TextInput(placeholder = "Type here...")
    Checkbox(text = "Remember me", initialChecked = true)
    status = Label(text = "", fontSize = 13.0)

app.setRootWidget(root)
app.showHelp()                   # normally the user presses F1 or ?
app.run()
