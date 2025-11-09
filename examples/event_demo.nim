## Comprehensive Event Demonstration
##
## This program demonstrates ALL event types and their handling:
## - Mouse move, clicks, wheel
## - Keyboard input
## - Window resize
## - Event coalescing, debouncing, throttling
## - Event counters and statistics

import raylib
import ../core/types
import ../widgets/basic/label
import ../widgets/containers/vstack
import ../managers/event_manager
import std/[strformat, monotimes, times]

type
  EventStats = object
    mouseMove: int
    mouseMoveCoalesced: int
    mouseDown: int
    mouseUp: int
    mouseWheel: int
    keyDown: int
    keyUp: int
    charInput: int
    windowResize: int
    resizeDebounced: int
    lastMousePos: Point
    lastKey: KeyboardKey
    lastChar: char
    lastWindowSize: Size
    hoveredWidget: string

proc main() =
  initWindow(1200, 800, "RUI Event System Demonstration")
  defer: closeWindow()
  setTargetFPS(60)

  # Create event manager with default configs
  let eventMgr = newEventManager()

  # Statistics tracking
  var stats = EventStats()
  var frameCount = 0

  # Create UI layout
  let root = newVStack()
  root.bounds = Rect(x: 20, y: 20, width: 960, height: 760)
  root.spacing = 10.0

  # Labels for displaying event info
  let titleLabel = newLabel()
  titleLabel.text = "RUI Event System - Live Event Monitor"
  titleLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 30)

  let mouseMoveLabel = newLabel()
  mouseMoveLabel.text = "Mouse Move: 0 (coalesced: 0)"
  mouseMoveLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let mousePosLabel = newLabel()
  mousePosLabel.text = "Mouse Position: (0, 0)"
  mousePosLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let mouseClickLabel = newLabel()
  mouseClickLabel.text = "Mouse Down: 0 | Mouse Up: 0"
  mouseClickLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let mouseWheelLabel = newLabel()
  mouseWheelLabel.text = "Mouse Wheel: 0 (throttled)"
  mouseWheelLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let keyDownLabel = newLabel()
  keyDownLabel.text = "Key Down: 0 | Key Up: 0 (ordered)"
  keyDownLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let lastKeyLabel = newLabel()
  lastKeyLabel.text = "Last Key: None"
  lastKeyLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let charInputLabel = newLabel()
  charInputLabel.text = "Char Input: 0 | Last Char: None"
  charInputLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let resizeLabel = newLabel()
  resizeLabel.text = "Window Resize: 0 (debounced: 0)"
  resizeLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let windowSizeLabel = newLabel()
  windowSizeLabel.text = "Window Size: 1000 x 800"
  windowSizeLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let hoverLabel = newLabel()
  hoverLabel.text = "Hovered: None"
  hoverLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let queueLabel = newLabel()
  queueLabel.text = "Event Queue: 0 pending"
  queueLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  let instructionsLabel = newLabel()
  instructionsLabel.text = "Instructions: Move mouse, click, scroll, type, resize window"
  instructionsLabel.bounds = Rect(x: 0, y: 0, width: 960, height: 25)

  # Add to layout
  root.addChild(titleLabel)
  root.addChild(mouseMoveLabel)
  root.addChild(mousePosLabel)
  root.addChild(mouseClickLabel)
  root.addChild(mouseWheelLabel)
  root.addChild(keyDownLabel)
  root.addChild(lastKeyLabel)
  root.addChild(charInputLabel)
  root.addChild(resizeLabel)
  root.addChild(windowSizeLabel)
  root.addChild(hoverLabel)
  root.addChild(queueLabel)
  root.addChild(instructionsLabel)

  root.layout()

  # Interactive test zones
  let zone1 = Rect(x: 50, y: 400, width: 200, height: 150)
  let zone2 = Rect(x: 300, y: 400, width: 200, height: 150)
  let zone3 = Rect(x: 550, y: 400, width: 200, height: 150)

  # Track raw event counts (before coalescing)
  var rawMouseMoveCount = 0
  var rawResizeCount = 0

  # Event handler
  proc handleEvent(event: GuiEvent) =
    case event.kind
    of evMouseMove:
      inc stats.mouseMoveCoalesced
      stats.lastMousePos = event.mousePos

      # Update hover state
      stats.hoveredWidget = "None"
      if event.mousePos.x >= zone1.x and event.mousePos.x <= zone1.x + zone1.width and
         event.mousePos.y >= zone1.y and event.mousePos.y <= zone1.y + zone1.height:
        stats.hoveredWidget = "Zone 1 (Red)"
      elif event.mousePos.x >= zone2.x and event.mousePos.x <= zone2.x + zone2.width and
           event.mousePos.y >= zone2.y and event.mousePos.y <= zone2.y + zone2.height:
        stats.hoveredWidget = "Zone 2 (Green)"
      elif event.mousePos.x >= zone3.x and event.mousePos.x <= zone3.x + zone3.width and
           event.mousePos.y >= zone3.y and event.mousePos.y <= zone3.y + zone3.height:
        stats.hoveredWidget = "Zone 3 (Blue)"

    of evMouseDown:
      inc stats.mouseDown

    of evMouseUp:
      inc stats.mouseUp

    of evMouseWheel:
      inc stats.mouseWheel

    of evKeyDown:
      inc stats.keyDown
      stats.lastKey = event.key

    of evKeyUp:
      inc stats.keyUp

    of evChar:
      inc stats.charInput
      stats.lastChar = event.char

    of evWindowResize:
      inc stats.resizeDebounced
      stats.lastWindowSize = event.windowSize

    else:
      discard

  # Main loop
  var lastWindowWidth = 1000
  var lastWindowHeight = 800

  while not windowShouldClose():
    inc frameCount

    # Collect raw events
    let mousePos = getMousePosition()
    if mousePos.x != stats.lastMousePos.x or mousePos.y != stats.lastMousePos.y:
      inc rawMouseMoveCount
      inc stats.mouseMove
      eventMgr.addEvent(GuiEvent(
        kind: evMouseMove,
        priority: epNormal,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    # Mouse button events
    if isMouseButtonPressed(MouseButton.Left):
      eventMgr.addEvent(GuiEvent(
        kind: evMouseDown,
        priority: epHigh,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    if isMouseButtonReleased(MouseButton.Left):
      eventMgr.addEvent(GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    # Mouse wheel
    let wheelMove = getMouseWheelMove()
    if wheelMove != 0.0:
      eventMgr.addEvent(GuiEvent(
        kind: evMouseWheel,
        priority: epNormal,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    # Keyboard events
    let key = getKeyPressed()
    if int(key) != 0:
      eventMgr.addEvent(GuiEvent(
        kind: evKeyDown,
        priority: epHigh,
        timestamp: getMonoTime(),
        key: key
      ))

    let charPressed = getCharPressed()
    if charPressed != 0:
      eventMgr.addEvent(GuiEvent(
        kind: evChar,
        priority: epHigh,
        timestamp: getMonoTime(),
        char: char(charPressed)
      ))

    # Window resize detection
    let currentWidth = getScreenWidth()
    let currentHeight = getScreenHeight()
    if currentWidth != lastWindowWidth or currentHeight != lastWindowHeight:
      inc rawResizeCount
      eventMgr.addEvent(GuiEvent(
        kind: evWindowResize,
        priority: epNormal,
        timestamp: getMonoTime(),
        windowSize: Size(width: float32(currentWidth), height: float32(currentHeight))
      ))
      lastWindowWidth = currentWidth
      lastWindowHeight = currentHeight

    # Update event manager (handles coalescing, debouncing, throttling)
    eventMgr.update()

    # Process events with time budget
    let budget = initDuration(milliseconds = 8)
    let processed = eventMgr.processEvents(budget, handleEvent)

    # Update labels
    mouseMoveLabel.text = &"Mouse Move: {stats.mouseMove} raw events → {stats.mouseMoveCoalesced} coalesced (saved {stats.mouseMove - stats.mouseMoveCoalesced})"
    mousePosLabel.text = &"Mouse Position: ({stats.lastMousePos.x:.0f}, {stats.lastMousePos.y:.0f})"
    mouseClickLabel.text = &"Mouse Down: {stats.mouseDown} | Mouse Up: {stats.mouseUp} (ordered, no coalescing)"
    mouseWheelLabel.text = &"Mouse Wheel: {stats.mouseWheel} events (throttled at 50ms)"
    keyDownLabel.text = &"Key Down: {stats.keyDown} | Key Up: {stats.keyUp} (ordered, preserved)"
    lastKeyLabel.text = &"Last Key: {stats.lastKey}"
    charInputLabel.text = &"Char Input: {stats.charInput} | Last Char: '{stats.lastChar}'"
    resizeLabel.text = &"Window Resize: {rawResizeCount} raw events → {stats.resizeDebounced} debounced (350ms quiet)"
    windowSizeLabel.text = &"Window Size: {int(stats.lastWindowSize.width)} x {int(stats.lastWindowSize.height)}"
    hoverLabel.text = &"Hovered: {stats.hoveredWidget}"
    queueLabel.text = &"Event Queue: {eventMgr.queueLength()} pending | Processed: {processed} this frame"

    # Render
    beginDrawing()
    clearBackground(raylib.Color(r: 30, g: 30, b: 40, a: 255))

    # Draw labels
    root.render()

    # Draw interactive zones
    drawRectangle(int32(zone1.x), int32(zone1.y), int32(zone1.width), int32(zone1.height),
                  if stats.hoveredWidget == "Zone 1 (Red)": raylib.Color(r: 255, g: 100, b: 100, a: 255)
                  else: raylib.Color(r: 150, g: 50, b: 50, a: 255))
    drawText("Zone 1", int32(zone1.x + 60), int32(zone1.y + 65), 20, WHITE)

    drawRectangle(int32(zone2.x), int32(zone2.y), int32(zone2.width), int32(zone2.height),
                  if stats.hoveredWidget == "Zone 2 (Green)": raylib.Color(r: 100, g: 255, b: 100, a: 255)
                  else: raylib.Color(r: 50, g: 150, b: 50, a: 255))
    drawText("Zone 2", int32(zone2.x + 60), int32(zone2.y + 65), 20, WHITE)

    drawRectangle(int32(zone3.x), int32(zone3.y), int32(zone3.width), int32(zone3.height),
                  if stats.hoveredWidget == "Zone 3 (Blue)": raylib.Color(r: 100, g: 100, b: 255, a: 255)
                  else: raylib.Color(r: 50, g: 50, b: 150, a: 255))
    drawText("Zone 3", int32(zone3.x + 60), int32(zone3.y + 65), 20, WHITE)

    # Draw instructions for zones
    drawText("Hover and click these zones!", 50, 365, 18, YELLOW)

    # Draw event pattern info box
    let infoX = 50'i32
    let infoY = 580'i32
    drawRectangleLines(infoX, infoY, 900'i32, 180'i32, LIGHTGRAY)
    drawText("Event Patterns & Optimizations:", int32(infoX + 10), int32(infoY + 10), 18, YELLOW)
    drawText("- Mouse Move: REPLACEABLE (only last event per frame matters)", int32(infoX + 20), int32(infoY + 40), 14, WHITE)
    drawText("- Mouse Clicks: ORDERED (exact sequence preserved, no coalescing)", int32(infoX + 20), int32(infoY + 60), 14, WHITE)
    drawText("- Keyboard: ORDERED (critical for text input, sequence matters)", int32(infoX + 20), int32(infoY + 80), 14, WHITE)
    drawText("- Mouse Wheel: THROTTLED (rate limited to 50ms interval)", int32(infoX + 20), int32(infoY + 100), 14, WHITE)
    drawText("- Window Resize: DEBOUNCED (waits for 350ms quiet period)", int32(infoX + 20), int32(infoY + 120), 14, WHITE)
    drawText("- Time Budget: 8ms per frame (maintains 60 FPS, defers excess events)", int32(infoX + 20), int32(infoY + 140), 14, LIGHTGRAY)

    # FPS counter
    drawText(&"FPS: {getFPS()}", 10, 10, 20, GREEN)

    endDrawing()

when isMainModule:
  main()
