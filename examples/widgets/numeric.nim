## Numeric input
##
## Spinner, NumberInput and ScrollBar: stepping, typed entry with validation,
## and scroll position.
##
##   nim c -r -d:useGraphics examples/widgets/numeric.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, strutils]

let app = newApp("RUI2 - Numeric input", 560, 420)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 14.0, padding = 20.0).named("root")
let summary = newLabel(text = "", fontSize = 15.0).named("summary")
root.addChild(summary)

var spinValue = 5.0'f32
var numValue = 0.0'f32
var scrollValue = 0.0'f32

proc refresh() =
  summary.text = "spinner=" & formatFloat(spinValue, ffDecimal, 1) &
                 "  number=" & formatFloat(numValue, ffDecimal, 2) &
                 "  scroll=" & formatFloat(scrollValue, ffDecimal, 0)
  summary.isDirty = true
  summary.layoutDirty = true

# Spinner: click the up/down gutter on the right to step.
root.addChild(newLabel(text = "Spinner (click the arrows):",
                       fontSize = 14.0).named("t1"))
let spin = newSpinner(initialValue = 5.0, minValue = 0.0, maxValue = 10.0,
                      step = 0.5, decimals = 1).named("spin")
spin.onChange = proc(value: float32) =
  spinValue = value
  refresh()
root.addChild(spin)

# NumberInput: click the text area to type, Enter commits, Escape reverts.
root.addChild(newLabel(text = "NumberInput (click, type, Enter):",
                       fontSize = 14.0).named("t2"))
let num = newNumberInput(initialValue = 0.0, minValue = -50.0, maxValue = 50.0,
                         step = 1.0, decimals = 2).named("num")
num.onChange = proc(value: float32) =
  numValue = value
  refresh()
num.onValidationError = proc(input: string) =
  summary.text = "not a number: " & input
  summary.isDirty = true
root.addChild(num)

# ScrollBar: drag the thumb, or use the wheel.
root.addChild(newLabel(text = "ScrollBar (drag or scroll):",
                       fontSize = 14.0).named("t3"))
let bar = newScrollBar(initialValue = 0.0, minValue = 0.0, maxValue = 100.0,
                       pageSize = 20.0, vertical = false).named("bar")
bar.bounds = Rect(x: 0, y: 0, width: 300, height: 12)
bar.onChange = proc(value: float32) =
  scrollValue = value
  refresh()
root.addChild(bar)

refresh()

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
