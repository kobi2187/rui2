## The keyboard help overlay: F1 or ? shades the window and lists the keys in
## force (the user's own bindings) plus the application's shortcuts.
##
##   nim c -r -d:useGraphics examples/widgets/help_overlay.nim [theme]
##
## This one opens it at startup; normally the user asks for it. Any key or click
## closes it. A "?" typed into a text field is typing, not a request for help.

import rui
import std/os
let app = newApp("help", 760, 560)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")
app.addHelp("Ctrl+S", "Save the document")
app.addHelp("Ctrl+F", "Find in the document")
let root = ui:
  VStack(spacing = 12.0, padding = 24.0):
    Label(text = "Notes", fontSize = 24.0, bold = true)
    TextInput(placeholder = "Type here...")
    Row(spacing = 8.0):
      Button(text = "Save", intent = ThemeIntent.Info)
      Button(text = "Cancel")
    Checkbox(text = "Remember me", initialChecked = true)
app.setRootWidget(root)
app.showHelp()                  # normally the user presses F1 or ?
app.run()
