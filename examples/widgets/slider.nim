## Slider and ProgressBar
##
## A slider drives a progress bar through a Link, showing one-way binding.
##
##   nim c -r -d:useGraphics examples/widgets/slider.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Slider and ProgressBar", 520, 320)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

# One Link, two widgets: the slider writes it, the readout and the bar read it.
let amount = newLink(35.0)

let readout = newLabel(text = "", fontSize = 18.0).named("readout")
amount.bindTo(readout, proc(v: float) = readout.text = "Value: " & $v.int & "%")

let bar = newProgressBar(initialValue = 35.0, maxValue = 100.0).named("bar")
amount.bindTo(bar, proc(v: float) = bar.value = v)

let slider = newSlider(initialValue = 35.0'f32, minValue = 0.0'f32,
                       maxValue = 100.0'f32).named("slider")
slider.onChange = some(proc(v: float32) {.closure.} = amount.set(v.float))

root.addChild(readout)
root.addChild(slider)
root.addChild(bar)

let row = newHStack(spacing = 8.0).named("row")
for (caption, delta, id) in [("-10", -10.0, "minus"), ("+10", 10.0, "plus")]:
  let step = delta
  let b = newButton(text = caption).named(id)
  b.onClick = some(proc() {.closure.} =
    amount.set(max(0.0, min(100.0, amount.get() + step))))
  row.addChild(b)
root.addChild(row)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
