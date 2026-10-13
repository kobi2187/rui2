## State block: a name field, a switch and a greeting that follows them.
## State is plain values; a handler updates whatever depends on a change.
##
##   nim c -r -d:useGraphics examples/state/greeter.nim

import rui
import std/strutils

proc buildUI*(): Widget =
  state:
    name: string = "Ada"
    shout: bool = false
    greeting: string = ""

  proc refresh() =
    let text = "Hello, " & (if name.value.len > 0: name.value else: "stranger") & "!"
    greeting.value = if shout.value: text.toUpperAscii() else: text
  refresh()

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Greeter", fontSize = 22.0, bold = true)
      TextInput(text = name.value, placeholder = "Your name",
                onChange = proc (s: string) =
                  name.value = s
                  refresh()).named("name").size(260, 32)
      Switch(text = "Shout", on = shout.value,
             onToggle = proc (on: bool) =
               shout.value = on
               refresh()).named("shout")
      Label(text = greeting.value, fontSize = 18.0).named("greeting")
      Button(text = "Clear", onClick = proc () =
        name.value = ""
        refresh()).named("clear")

when isMainModule:
  let app = newApp("Greeter", 360, 260)
  app.setRootWidget(buildUI())
  app.run()
