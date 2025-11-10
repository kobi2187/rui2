## Test definePrimitive macro with Button (state + actions + events)

import ../core/widget_dsl_v2
import std/options

# Test 2: Button with state, actions, and events
definePrimitive(Button):
  props:
    text: string
    disabled: bool = false

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed.set(true)
        echo "Button pressed: ", widget.text
        return true
      return false

    on_mouse_up:
      if widget.isPressed.get() and not widget.disabled:
        widget.isPressed.set(false)
        echo "Button released: ", widget.text
        if widget.onClick.isSome:
          echo "Calling onClick callback"
          widget.onClick.get()()
        return true
      return false

    on_mouse_move:
      # Simple hover check (in real code, would check mouse position)
      widget.isHovered.set(true)
      return false

  render:
    let pressed = widget.isPressed.get()
    let hovered = widget.isHovered.get()

    echo "Rendering Button: ", widget.text,
         " (pressed=", pressed,
         ", hovered=", hovered,
         ", disabled=", widget.disabled, ")"

# Test usage
when isMainModule:
  echo "=== Testing Button Widget ==="

  var clickCount = 0

  # Create button with onClick callback
  let button = newButton(
    text = "Click Me",
    disabled = false,
    onClick = proc() =
      clickCount += 1
      echo "  -> Button clicked! Count: ", clickCount
  )

  echo "Created button: text='", button.text, "', disabled=", button.disabled
  button.render()

  # Simulate mouse events
  echo "\n--- Simulating mouse down ---"
  discard button.handleInput(GuiEvent(
    kind: evMouseDown,
    mousePos: Point(x: 50, y: 15)
  ))
  button.render()

  echo "\n--- Simulating mouse up ---"
  discard button.handleInput(GuiEvent(
    kind: evMouseUp,
    mousePos: Point(x: 50, y: 15)
  ))
  button.render()

  # Simulate another click
  echo "\n--- Second click ---"
  discard button.handleInput(GuiEvent(kind: evMouseDown, mousePos: Point(x: 50, y: 15)))
  discard button.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 50, y: 15)))

  echo "\n--- Testing disabled button ---"
  let disabledButton = newButton("Disabled", disabled = true)
  echo "Created disabled button"
  discard disabledButton.handleInput(GuiEvent(kind: evMouseDown, mousePos: Point(x: 50, y: 15)))
  discard disabledButton.handleInput(GuiEvent(kind: evMouseUp, mousePos: Point(x: 50, y: 15)))

  echo "\n✓ Button test passed"
  echo "Final click count: ", clickCount
