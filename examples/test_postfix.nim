## Test the defineWidget macro with postfix

import ../core/[types, widget_dsl]

when defined(useGraphics):
  import raylib

defineWidget(TestWidget):
  props:
    value*: int

echo "Success!"
