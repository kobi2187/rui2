## Integration Test - Full System Test
##
## Tests:
## 1. Link[T] state changes
## 2. Dirty flag propagation
## 3. Layout recalculation
## 4. Render pipeline
## 5. Hit-testing
##
## Scenario: Counter with increment button
## - Click button → counter increments
## - Link change → widget marked dirty
## - Layout recalculates positions
## - Render updates display

import raylib
import ../core/[types, widget_dsl, link]
import ../widgets/button_yaml
import ../widgets/vstack as vstackWidget

# Simple counter store
type CounterStore = ref object
  count*: Link[int]

proc newCounterStore(): CounterStore =
  result = CounterStore()
  result.count = newLink(0)

var debugLog: seq[string]

proc log(msg: string) =
  echo "[DEBUG] ", msg
  debugLog.add(msg)

# Custom Label widget that logs when it's laid out and rendered
defineWidget(DebugLabel):
  props:
    text: string

  init:
    widget.text = "Label"
    widget.bounds.width = 200
    widget.bounds.height = 30

  layout:
    log("DebugLabel.layout() called - text: " & widget.text)

  render:
    log("DebugLabel.render() called - text: " & widget.text)
    when defined(useGraphics):
      # Draw background to see bounds
      drawRectangleLines(
        int32(widget.bounds.x),
        int32(widget.bounds.y),
        int32(widget.bounds.width),
        int32(widget.bounds.height),
        BLUE
      )
      # Draw text
      raylib.drawText(widget.text,
                     int32(widget.bounds.x + 10),
                     int32(widget.bounds.y + 5),
                     20,
                     WHITE)

proc main() =
  initWindow(900, 700, "Integration Test - Link → Dirty → Layout → Render")
  defer: closeWindow()
  setTargetFPS(60)

  # Create store
  let store = newCounterStore()

  log("=== INITIAL SETUP ===")

  # Create UI
  let vstack = vstackWidget.newVStack()
  vstack.bounds = Rect(x: 50, y: 50, width: 400, height: 500)
  vstack.spacing = 16.0
  vstack.padding = EdgeInsets(top: 16, right: 16, bottom: 16, left: 16)
  vstack.justify = Start
  vstack.align = Center

  # Counter display
  let counterLabel = newDebugLabel()
  counterLabel.text = "Count: " & $store.count.value

  # Increment button
  let incrementBtn = newButtonYAML()
  incrementBtn.text = "Increment"
  incrementBtn.bounds.width = 150
  incrementBtn.bounds.height = 50

  # Status label
  let statusLabel = newDebugLabel()
  statusLabel.text = "Status: Ready"

  # Add to vstack
  vstack.addChild(counterLabel)
  vstack.addChild(incrementBtn)
  vstack.addChild(statusLabel)

  log("=== INITIAL LAYOUT ===")
  vstack.layout()

  log("Initial positions:")
  log("  counterLabel: " & $counterLabel.bounds.y)
  log("  incrementBtn: " & $incrementBtn.bounds.y)
  log("  statusLabel: " & $statusLabel.bounds.y)

  var frameCount = 0

  incrementBtn.onClick = proc() =
    log("\n=== BUTTON CLICKED (Frame " & $frameCount & ") ===")

    # 1. Update Link
    log("1. Updating Link[int]: " & $store.count.value & " → " & $(store.count.value + 1))
    store.count.value = store.count.value + 1

    # 2. Mark widgets dirty
    log("2. Marking widgets as dirty")
    counterLabel.isDirty = true
    counterLabel.layoutDirty = true
    statusLabel.isDirty = true

    # 3. Update text (simulates binding)
    counterLabel.text = "Count: " & $store.count.value
    statusLabel.text = "Status: Updated at frame " & $frameCount

    log("3. Text updated")
    log("4. Calling layout()")

    # 4. Recalculate layout
    vstack.layout()

    log("5. Layout complete")
    log("New positions:")
    log("  counterLabel: " & $counterLabel.bounds.y)
    log("  incrementBtn: " & $incrementBtn.bounds.y)
    log("  statusLabel: " & $statusLabel.bounds.y)

  while not windowShouldClose():
    frameCount += 1
    let mousePos = getMousePosition()

    # Update hover state
    incrementBtn.hovered = (
      mousePos.x >= incrementBtn.bounds.x and
      mousePos.x <= incrementBtn.bounds.x + incrementBtn.bounds.width and
      mousePos.y >= incrementBtn.bounds.y and
      mousePos.y <= incrementBtn.bounds.y + incrementBtn.bounds.height
    )

    # Handle clicks
    if isMouseButtonReleased(MouseButton.Left):
      log("\n--- Mouse Click at frame " & $frameCount & " ---")
      let event = GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      )

      log("Calling vstack.handleInput()")
      let handled = vstack.handleInput(event)
      log("Input handled: " & $handled)

    # Render
    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 40, a: 255))

    # Title
    raylib.drawText("Integration Test", 10'i32, 10'i32, 24'i32, WHITE)
    raylib.drawText("Watch console for detailed logs", 10'i32, 40'i32, 16'i32, GRAY)

    # Draw VStack bounds
    drawRectangleLines(
      int32(vstack.bounds.x),
      int32(vstack.bounds.y),
      int32(vstack.bounds.width),
      int32(vstack.bounds.height),
      YELLOW
    )

    # Render widgets
    debugLog.setLen(0)  # Clear frame log
    vstack.render()

    # Show frame log
    var logY = 550
    raylib.drawText("This Frame:", 500'i32, int32(logY), 14'i32, GREEN)
    logY += 20
    for msg in debugLog:
      if logY < 680:
        let shortMsg = if msg.len > 50: msg[0..47] & "..." else: msg
        raylib.drawText(shortMsg, 500'i32, int32(logY), 12'i32, LIGHTGRAY)
        logY += 15

    # Show state
    let stateText = "Counter: " & $store.count.value & " | Frame: " & $frameCount
    raylib.drawText(stateText, 10'i32, 670'i32, 16'i32, YELLOW)

    endDrawing()

when isMainModule:
  main()
