## Combined test: definePrimitive + defineWidget working together

import ../core/widget_dsl_v2
import std/options

# ============================================================================
# Primitive Widgets
# ============================================================================

definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0

  render:
    echo "  [Label] \"", widget.text, "\" (fontSize=", widget.fontSize, ")"

definePrimitive(Button):
  props:
    text: string
    disabled: bool = false

  state:
    isPressed: bool

  actions:
    onClick()

  events:
    on_mouse_up:
      if not widget.disabled and widget.onClick.isSome:
        widget.onClick.get()()
        return true
      return false

  render:
    let state = if widget.isPressed.get(): "pressed" else: "normal"
    echo "  [Button] \"", widget.text, "\" (", state, ")"

# ============================================================================
# Composite Widgets
# ============================================================================

defineWidget(VStack):
  props:
    spacing: float = 8.0

  layout:
    var y = widget.bounds.y
    for child in widget.children:
      child.bounds.x = widget.bounds.x
      child.bounds.y = y
      child.bounds.width = widget.bounds.width
      y += child.bounds.height + widget.spacing

  render:
    echo "[VStack] spacing=", widget.spacing, ", children=", widget.children.len

defineWidget(HStack):
  props:
    spacing: float = 8.0

  layout:
    var x = widget.bounds.x
    for child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y
      child.bounds.height = widget.bounds.height
      x += child.bounds.width + widget.spacing

  render:
    echo "[HStack] spacing=", widget.spacing, ", children=", widget.children.len

# ============================================================================
# Test: Building a UI hierarchy
# ============================================================================

when isMainModule:
  echo "=== Testing Combined DSL ===\n"

  var clickCount = 0

  # Create a simple UI
  let vstack = newVStack(spacing = 10.0)

  # Add title label
  let title = newLabel("Welcome to RUI2!", fontSize = 18.0)
  vstack.children.add(title)

  # Add description
  let description = newLabel("Click the buttons below:")
  vstack.children.add(description)

  # Create horizontal stack for buttons
  let hstack = newHStack(spacing = 5.0)

  let btn1 = newButton("Click Me", onClick = proc() =
    clickCount += 1
    echo "    -> Button 1 clicked! Count: ", clickCount
  )

  let btn2 = newButton("Me Too!", onClick = proc() =
    clickCount += 1
    echo "    -> Button 2 clicked! Count: ", clickCount
  )

  hstack.children.add(btn1)
  hstack.children.add(btn2)

  # Add button stack to main stack
  vstack.children.add(hstack)

  # Add footer
  let footer = newLabel("Footer text", fontSize = 12.0)
  vstack.children.add(footer)

  # Render the hierarchy
  echo "Rendering UI hierarchy:\n"
  vstack.render()

  # Simulate button clicks
  echo "\n--- Simulating button clicks ---"
  discard btn1.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 0, y: 0)))
  discard btn2.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 0, y: 0)))
  discard btn1.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 0, y: 0)))

  echo "\n✓ Combined test passed"
  echo "Final click count: ", clickCount
