## State block: a name field, a switch and two labels that follow them.
##
##   nim c -r -d:useGraphics examples/state/greeter.nim

import rui
import std/strutils

proc buildUI*(): Widget =
  state:
    name: string = "Ada"
    shout: bool = false
  # A value computed from state: recomputed when either input changes.
  let greeting = derive(name, shout, proc (n: string, s: bool): string =
    let text = "Hello, " & (if n.len > 0: n else: "stranger") & "!"
    if s: text.toUpperAscii() else: text)

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Greeter", fontSize = 22.0, bold = true)
      TextInput(text = -> name, onChange = name.setter, placeholder = "Your name").named("name").size(260, 32)
      Switch(text = "Shout", on = -> shout, onToggle = shout.setter).named("shout")
      Label(text = -> greeting, fontSize = 18.0).named("greeting")
      Button(text = "Clear", onClick = proc () = name.value = "").named("clear")

when isMainModule:
  let app = newApp("Greeter", 360, 260)
  app.setRootWidget(buildUI())
  app.run()
