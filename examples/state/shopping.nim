## State block: a list in state. Add items from a field; the handlers keep the
## list and the count in step. `items` is a Link holding a seq, so assigning a
## new seq repaints the list.
##
##   nim c -r -d:useGraphics examples/state/shopping.nim

import rui
import std/strformat

proc buildUI*(): Widget =
  state:
    items: seq[string] = @[]
    draft: string = ""
    count: string = "0 item(s)"

  proc setItems(xs: seq[string]) =
    items.value = xs
    count.value = &"{xs.len} item(s)"

  proc add() =
    if draft.value.len > 0:
      setItems(items.value & draft.value)
      draft.value = ""

  ui:
    VStack(spacing = 10.0, padding = 20.0):
      Label(text = "Shopping list", fontSize = 22.0, bold = true)
      HStack(spacing = 8.0):
        TextInput(text = -> draft, placeholder = "Add an item",
                  onChange = draft.setter,
                  onSubmit = proc (t: string) = add()).named("draft").size(220, 32)
        Button(text = "Add", onClick = add).named("add")
      ListBox(items = -> items, visibleRows = 6).named("list").size(300, 150)
      Label(text = -> count).named("count")
      Button(text = "Clear", onClick = proc () = setItems(@[])).named("clear")

when isMainModule:
  let app = newApp("Shopping", 380, 420)
  app.setRootWidget(buildUI())
  app.run()
