## Baby Step Example 01: Link[T] Basic Functionality
##
## What this tests: Link[T] value storage and change notification
## Expected behavior: Green window with counter that increments on spacebar
## How to verify:
##   1. Window opens with green background
##   2. Counter displays initial value (0)
##   3. Press spacebar → counter increments
##   4. Console shows "Value changed: N → N+1"
##
## Status: ✅ READY TO TEST

import raylib
import ../../core/[types, link]

proc main() =
  # Setup window
  initWindow(400, 300, "Test: Link[T] Basic")
  setTargetFPS(60)
  defer: closeWindow()

  # Create a Link with initial value
  let counter = newLink(0)

  # Set up onChange callback for logging
  counter.setOnChange proc(old, new: int) =
    echo "Value changed: ", old, " → ", new

  echo "Link created: ", counter
  echo "Initial value: ", counter.value
  echo ""
  echo "Instructions:"
  echo "  - Press SPACE to increment counter"
  echo "  - Press ESC to quit"
  echo ""

  # Main loop
  while not windowShouldClose():
    # Input handling
    if isKeyPressed(KEY_SPACE):
      counter.value += 1
      echo "  Counter is now: ", counter.value

    if isKeyPressed(KEY_R):
      counter.value = 0
      echo "  Counter reset to 0"

    # Render
    beginDrawing()
    clearBackground(RAYGREEN)

    # Title
    drawText("Link[T] Basic Test", 10, 10, 20, WHITE)
    drawText("(Green = Test Mode)", 10, 35, 16, LIGHTGRAY)

    # Instructions
    drawText("Press SPACE to increment", 10, 70, 18, WHITE)
    drawText("Press R to reset", 10, 95, 18, WHITE)

    # Counter display (large)
    let counterText = "Counter: " & $counter.value
    drawText(counterText, 10, 140, 32, YELLOW)

    # Debug info
    drawText("Dependent widgets: " & $counter.dependentCount, 10, 200, 16, WHITE)
    drawText("(0 because we're not using widgets yet)", 10, 220, 14, LIGHTGRAY)

    # Status
    drawText("✓ Link[T] is working!", 10, 260, 18, GREEN)

    endDrawing()

echo "Starting Link[T] basic test..."
main()
echo "Test completed."
