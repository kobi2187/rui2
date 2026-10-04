## Tutorial 1 -- a counter: state, a tree, a binding.
##
##   nim c -r -d:useGraphics examples/tutorial/counter.nim

import rui

# State is a Link: a value that tells whoever shows it when it changes.
let count = newLink(0)

var shown: Label

# `ui:` writes the widget tree the way it reads: a capitalised call is a widget,
# an indented block is its children, and `name =` keeps a handle on one.
let root = ui:
  Center():
    Column(spacing = 12.0, mainAxisSize = MainAxisSize.min):
      shown = Label(text = "", fontSize = 28.0, bold = true)
      Row(spacing = 8.0, mainAxisSize = MainAxisSize.min):
        Button(text = "-", onClick = proc() = count.set(count.get() - 1)).shortcut("Down")
        Button(text = "+", intent = ThemeIntent.Info,
               onClick = proc() = count.set(count.get() + 1)).shortcut("Up")

# Show the link in the label: whenever it changes, this runs and the label
# repaints. Nothing else is needed.
count.bindTo(shown, proc(v: int) = shown.text = "Count: " & $v)

let app = newApp("Counter", 360, 220)
app.setRootWidget(root)
app.run()
