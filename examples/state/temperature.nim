## State block: a slider drives a Celsius value; Fahrenheit is derived from it.
##
##   nim c -r -d:useGraphics examples/state/temperature.nim

import rui
import std/strformat

proc buildUI*(): Widget =
  state:
    celsius: float32 = 20
  let fahrenheit = celsius.derive(proc (c: float32): float32 = c * 9 / 5 + 32)
  let summary = derive(celsius, fahrenheit, proc (c, f: float32): string =
    &"{int(c)} °C  =  {int(f)} °F")

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Temperature", fontSize = 22.0, bold = true)
      Slider(value = -> celsius, onChange = celsius.setter, minValue = -40, maxValue = 100,
             showValue = false).named("celsius").size(300, 28)
      Label(text = -> summary, fontSize = 18.0).named("summary")
      ProgressBar(initialValue = 0).named("bar").size(300, 16)

when isMainModule:
  let app = newApp("Temperature", 380, 240)
  app.setRootWidget(buildUI())
  app.run()
