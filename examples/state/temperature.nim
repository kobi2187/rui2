## State block: a slider sets Celsius; the handler works out the text to show.
##
##   nim c -r -d:useGraphics examples/state/temperature.nim

import rui
import std/strformat

proc buildUI*(): Widget =
  state:
    celsius: float32 = 20
    summary: string = ""

  proc show(c: float32) =
    celsius.value = c
    summary.value = &"{int(c)} °C  =  {int(c * 9 / 5 + 32)} °F"
  show(celsius.value)

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Temperature", fontSize = 22.0, bold = true)
      Slider(value = -> celsius, onChange = show, minValue = -40, maxValue = 100,
             showValue = false).named("celsius").size(300, 28)
      Label(text = -> summary, fontSize = 18.0).named("summary")

when isMainModule:
  let app = newApp("Temperature", 380, 200)
  app.setRootWidget(buildUI())
  app.run()
