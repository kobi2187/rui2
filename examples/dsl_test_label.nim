## Test definePrimitive macro with simple Label widget

import ../core/widget_dsl_v2

# Test 1: Simple Label (no state, no actions, no events)
definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0

  render:
    echo "Rendering Label: ", widget.text, " (fontSize=", widget.fontSize, ")"

# Test usage
when isMainModule:
  echo "=== Testing Label Widget ==="

  # Create label with default fontSize
  let label1 = newLabel("Hello World")
  echo "Created label1: text='", label1.text, "', fontSize=", label1.fontSize
  label1.render()

  # Create label with custom fontSize
  let label2 = newLabel("Big Text", fontSize = 24.0)
  echo "\nCreated label2: text='", label2.text, "', fontSize=", label2.fontSize
  label2.render()

  echo "\n✓ Label test passed"
