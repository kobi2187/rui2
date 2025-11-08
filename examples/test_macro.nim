## Test the defineWidget macro with minimal example

import ../core/[types, widget_dsl]

when defined(useGraphics):
  import raylib

defineWidget(SimpleWidget):
  props:
    value: int

  init:
    widget.value = 42

echo "Macro expanded successfully!"
