## Theme states
##
## Each basic control in every state a theme draws -- normal, hovered, pressed,
## focused and disabled -- one row per control, so the states can be compared
## across themes at a glance:
##
##   nim c -r -d:useGraphics examples/widgets/theme_states.nim [theme]
##
## The states are set on the widgets directly (hovered, pressed, focused) because
## a screenshot cannot move the pointer or the keyboard. Each row is laid out by
## layout primitives only.

import rui
import std/os

let app = newApp("RUI2 - Theme states", 1120, 600)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "beos")

const stateNames = ["normal", "hovered", "pressed", "focused", "disabled"]

proc setState(w: Widget, state: string) =
  ## Put a widget into one of the named states. Disabled is set by the constructor.
  case state
  of "hovered": w.hovered = true
  of "pressed":
    w.hovered = true
    w.pressed = true
  of "focused": w.focused = true
  else: discard

proc stateRow(label: string, make: proc(disabled: bool): Widget): Widget =
  let row = newRow(spacing = 14.0)
  row.addChild(newLabel(text = label))
  for state in stateNames:
    let w = make(state == "disabled")
    w.setState(state)
    row.addChild(w)
  row

let header = newRow(spacing = 14.0)
header.addChild(newLabel(text = "control"))
for state in stateNames:
  header.addChild(newLabel(text = state, bold = true))

let page = newVStack(spacing = 14.0, padding = 16.0)
page.addChild(header)
page.addChild(stateRow("Button", proc(d: bool): Widget = newButton(text = "Button", disabled = d)))
page.addChild(stateRow("Primary", proc(d: bool): Widget = newButton(text = "Primary", intent = ThemeIntent.Info, disabled = d)))
page.addChild(stateRow("Checkbox", proc(d: bool): Widget = newCheckbox(text = "Off", disabled = d)))
page.addChild(stateRow("Switch", proc(d: bool): Widget = newSwitch(text = "Off", disabled = d)))
page.addChild(stateRow("Text field", proc(d: bool): Widget = newTextInput(initialText = "Ada", disabled = d)))
page.addChild(stateRow("Combo box", proc(d: bool): Widget = newComboBox(items = @["Team"], initialSelectedIndex = 0, disabled = d)))
page.addChild(stateRow("Slider", proc(d: bool): Widget =
  let slider = newSlider(initialValue = 40.0, disabled = d)
  slider.bounds.width = 130.0
  slider))
page.addChild(stateRow("Segmented", proc(d: bool): Widget = newSegmentedControl(options = @["Day", "Week"], initialSelectedIndex = 1, disabled = d)))

app.setRootWidget(page)
app.run()
