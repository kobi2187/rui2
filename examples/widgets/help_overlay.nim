## The keyboard help overlay: F1 or ? shades the window. The general navigation
## keys run along the top (the user's own bindings); every widget that was given
## a hint gets a badge with it beside the widget, wherever it is.
##
##   nim c -r -d:useGraphics examples/widgets/help_overlay.nim [theme]
##
## Three ways to say what a key does:
##   .shortcut("Ctrl+S")    a real key for this widget; its chord is the hint
##   .hint("← → adjust")    any note, shown beside the widget (it binds nothing)
##   app.bindShortcut(...)  a key for the whole app, listed under the top line
##
## This one opens the overlay at startup; normally the user asks for it. Any key
## or click closes it. A "?" typed into a text field is typing, not a request.

import rui
import std/os

var status: Label
let app = newApp("RUI2 - Help overlay", 900, 460)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")
app.bindShortcut("Ctrl+F", "find in the document",
                 proc() = status.text = "find...")      # bound to the app, no widget

let root = ui:
  VStack(spacing = 12.0, padding = 24.0):
    Label(text = "Notes", fontSize = 24.0, bold = true)
    Row(spacing = 8.0):
      Button(text = "Open", onClick = proc() = status.text = "opened").shortcut("Ctrl+O")
      Button(text = "Save", intent = ThemeIntent.Info,
             onClick = proc() = status.text = "saved").shortcut("Ctrl+S")
      Button(text = "Run", onClick = proc() = status.text = "ran").shortcut("F5")
    TextInput(placeholder = "Type here...").hint("Enter to submit")
    Slider(initialValue = 40.0, textLeft = "Volume").hint("← → adjust")
    Checkbox(text = "Remember me", initialChecked = true)
    status = Label(text = "", fontSize = 13.0)

app.setRootWidget(root)
app.showHelp()                   # normally the user presses F1 or ?
app.run()
