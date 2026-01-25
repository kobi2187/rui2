## RadioGroup Widget - RUI2
##
## A container widget that manages a group of radio buttons.
## Only one radio button can be selected at a time.
## Ported from Hummingbird to RUI2's defineWidget DSL.

import ../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

defineWidget(RadioGroup):
  props:
    options: seq[string] = @[]
    initialSelected: int = 0
    spacing: float = 24.0
    disabled: bool = false

  state:
    selectedIndex: int

  actions:
    onSelect(index: int)

  layout:
    # Arrange radio buttons vertically
    var y = widget.bounds.y
    for i in 0 ..< widget.options.len:
      if i < widget.children.len:
        widget.children[i].bounds.x = widget.bounds.x
        widget.children[i].bounds.y = y
        widget.children[i].bounds.width = widget.bounds.width
        widget.children[i].bounds.height = 20
        y += widget.spacing

  render:
    when defined(useGraphics):
      # Render each radio button
      var selectedIdx = widget.selectedIndex

      for i, option in widget.options:
        if GuiRadioButton(
          Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y + float32(i) * widget.spacing,
            width: 20,
            height: 20
          ),
          option.cstring,
          selectedIdx == i
        ):
          # Update selected index
          widget.selectedIndex = i
          if widget.onSelect.isSome:
            widget.onSelect.get()(i)
    else:
      # Non-graphics mode: just echo
      echo "RadioGroup:"
      for i, option in widget.options:
        let marker = if widget.selectedIndex == i: "●" else: "○"
        echo "  ", marker, " ", option
