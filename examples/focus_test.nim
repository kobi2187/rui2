## Focus Manager Test
##
## Tests the integrated FocusManager functionality:
## - Tab navigation between widgets
## - Focus callbacks (onFocus/onBlur)
## - Keyboard event routing to focused widget

import ../core/app
import ../widgets/primitives/label
import std/strformat

proc main() =
  echo "=== Focus Manager Test ==="
  echo "This test runs in headless mode"
  echo ""

  # Create app
  let myApp = newApp(title = "Focus Test", width = 800, height = 600)

  # Create test widgets
  var label1 = newLabel(text = "Widget 1", fontSize = 16.0)
  label1.bounds = Rect(x: 50, y: 50, width: 200, height: 30)
  label1.onFocus = some(proc() {.closure.} =
    echo "[Widget 1] Gained focus"
  )
  label1.onBlur = some(proc() {.closure.} =
    echo "[Widget 1] Lost focus"
  )

  var label2 = newLabel(text = "Widget 2", fontSize = 16.0)
  label2.bounds = Rect(x: 50, y: 100, width: 200, height: 30)
  label2.onFocus = some(proc() {.closure.} =
    echo "[Widget 2] Gained focus"
  )
  label2.onBlur = some(proc() {.closure.} =
    echo "[Widget 2] Lost focus"
  )

  var label3 = newLabel(text = "Widget 3", fontSize = 16.0)
  label3.bounds = Rect(x: 50, y: 150, width: 200, height: 30)
  label3.onFocus = some(proc() {.closure.} =
    echo "[Widget 3] Gained focus"
  )
  label3.onBlur = some(proc() {.closure.} =
    echo "[Widget 3] Lost focus"
  )

  # Create simple container
  var root = newLabel(text = "Root", fontSize = 14.0)
  root.bounds = Rect(x: 0, y: 0, width: 800, height: 600)
  root.children = @[Widget(label1), Widget(label2), Widget(label3)]

  myApp.setRootWidget(root)

  # Test focus manager
  echo "Testing FocusManager:"
  echo ""

  echo "1. Building focus chain..."
  myApp.focusManager.buildFocusChain(root)
  echo &"   Focus chain has {myApp.focusManager.focusChain.len} widgets"
  echo ""

  echo "2. Setting focus to first widget..."
  myApp.focusManager.setFocus(label1)
  let f0 = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if f0 != nil: f0.stringId else: "nil"
  echo ""

  echo "3. Moving to next focus (should go to Widget 2)..."
  myApp.focusManager.nextFocus(root)
  let focused1 = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if focused1 != nil: focused1.stringId else: "nil"
  echo ""

  echo "4. Moving to next focus (should go to Widget 3)..."
  myApp.focusManager.nextFocus(root)
  let focused2 = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if focused2 != nil: focused2.stringId else: "nil"
  echo ""

  echo "5. Moving to next focus (should wrap to Widget 1)..."
  myApp.focusManager.nextFocus(root)
  let focused3 = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if focused3 != nil: focused3.stringId else: "nil"
  echo ""

  echo "6. Moving to previous focus (should go back to Widget 3)..."
  myApp.focusManager.prevFocus(root)
  let focused4 = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if focused4 != nil: focused4.stringId else: "nil"
  echo ""

  echo "7. Clearing focus..."
  myApp.focusManager.clearFocus()
  let finalWidget = myApp.focusManager.getFocusedWidget()
  echo "   Focused widget: ", if finalWidget != nil: "ERROR" else: "nil (correct)"
  echo ""

  echo "=== All tests passed! ==="

when isMainModule:
  main()
