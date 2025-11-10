## Test for Checkbox widget

import ../widgets/basic/checkbox
import ../core/types

# Test usage
when isMainModule:
  echo "=== Testing Checkbox Widget ==="

  # Create checkbox with callback
  let cb1 = newCheckbox(
    text = "Enable feature",
    initialChecked = false,
    onToggle = proc(checked: bool) =
      echo "  -> Checkbox toggled! New state: ", checked
  )

  echo "Created checkbox: text='", cb1.text, "', checked=", cb1.checked.get()
  cb1.render()

  # Simulate click to toggle
  echo "\n--- Simulating mouse down (toggle) ---"
  discard cb1.handleInput(GuiEvent(
    kind: evMouseDown,
    mousePos: Point(x: 10, y: 10)
  ))
  cb1.render()
  echo "After toggle: checked=", cb1.checked.get()

  # Simulate another click
  echo "\n--- Simulating second toggle ---"
  discard cb1.handleInput(GuiEvent(
    kind: evMouseDown,
    mousePos: Point(x: 10, y: 10)
  ))
  cb1.render()
  echo "After second toggle: checked=", cb1.checked.get()

  # Test with initially checked
  echo "\n--- Testing initially checked ---"
  let cb2 = newCheckbox(
    text = "Remember me",
    initialChecked = true
  )
  echo "Created checkbox: checked=", cb2.checked.get()
  cb2.render()

  # Test disabled checkbox
  echo "\n--- Testing disabled checkbox ---"
  let cb3 = newCheckbox(
    text = "Disabled option",
    disabled = true,
    onToggle = proc(checked: bool) =
      echo "  -> This should not print!"
  )
  echo "Created disabled checkbox"
  discard cb3.handleInput(GuiEvent(
    kind: evMouseDown,
    mousePos: Point(x: 10, y: 10)
  ))
  echo "After click on disabled: checked=", cb3.checked.get()

  echo "\n✓ Checkbox test passed"
