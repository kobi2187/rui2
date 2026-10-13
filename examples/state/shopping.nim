## State block: a list in state. Add items from a field; the list and the count
## follow it. `items` is a Link holding a seq, so assigning a new seq repaints.
##
##   nim c -r -d:useGraphics examples/state/shopping.nim

import rui
import std/strformat

proc buildUI*(): Widget =
  state:
    items: seq[string] = @[]
    draft: string = ""
  let count = items.derive(proc (xs: seq[string]): string = &"{xs.len} item(s)")

  proc add() =
    if draft.value.len > 0:
      items.value = items.value & draft.value
      draft.value = ""

  ui:
    VStack(spacing = 10.0, padding = 20.0):
      Label(text = "Shopping list", fontSize = 22.0, bold = true)
      HStack(spacing = 8.0):
        TextInput(text = -> draft, onChange = draft.setter, placeholder = "Add an item",
                  onSubmit = proc (t: string) = add()).named("draft").size(220, 32)
        Button(text = "Add", onClick = add).named("add")
      ListBox(items = -> items, visibleRows = 6).named("list").size(300, 150)
      Label(text = -> count).named("count")
      Button(text = "Clear", onClick = proc () = items.value = @[]).named("clear")

when isMainModule:
  let app = newApp("Shopping", 380, 420)
  app.setRootWidget(buildUI())
  app.run()
