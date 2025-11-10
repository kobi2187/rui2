## App Helper Functions - Forth Style
##
## Small, composable functions for app lifecycle
## Each function does ONE thing clearly

import types
import std/[monotimes, times]
when defined(useGraphics):
  import raylib

# ============================================================================
# Event Collection Predicates
# ============================================================================

when defined(useGraphics):
  proc hasMouseMoved*(): bool =
    ## Check if mouse has moved
    let delta = getMouseDelta()
    delta.x != 0 or delta.y != 0

  proc hasMouseDown*(): bool =
    ## Check if mouse button pressed
    isMouseButtonPressed(Left)

  proc hasMouseUp*(): bool =
    ## Check if mouse button released
    isMouseButtonReleased(Left)

  proc hasMouseWheel*(): bool =
    ## Check if mouse wheel moved
    getMouseWheelMove() != 0

  proc hasKeyPress*(): bool =
    ## Check if key was pressed
    getKeyPressed() != KeyboardKey(0)

  proc hasCharInput*(): bool =
    ## Check if character was input
    getCharPressed().int32 > 0

  proc hasWindowResize*(): bool =
    ## Check if window was resized
    isWindowResized()

# ============================================================================
# Event Creation - Build GuiEvent Objects
# ============================================================================

when defined(useGraphics):
  proc makePoint*(v: Vector2): Point =
    ## Convert Raylib Vector2 to Point
    Point(x: v.x, y: v.y)

  proc makeMouseMoveEvent*(): GuiEvent =
    ## Create mouse move event
    GuiEvent(
      kind: evMouseMove,
      priority: epNormal,
      timestamp: getMonoTime(),
      mousePos: makePoint(getMousePosition())
    )

  proc makeMouseDownEvent*(): GuiEvent =
    ## Create mouse down event
    GuiEvent(
      kind: evMouseDown,
      priority: epHigh,
      timestamp: getMonoTime(),
      mousePos: makePoint(getMousePosition())
    )

  proc makeMouseUpEvent*(): GuiEvent =
    ## Create mouse up event
    GuiEvent(
      kind: evMouseUp,
      priority: epHigh,
      timestamp: getMonoTime(),
      mousePos: makePoint(getMousePosition())
    )

  proc makeMouseWheelEvent*(): GuiEvent =
    ## Create mouse wheel event
    GuiEvent(
      kind: evMouseWheel,
      priority: epNormal,
      timestamp: getMonoTime()
    )

  proc makeKeyDownEvent*(): GuiEvent =
    ## Create key down event
    GuiEvent(
      kind: evKeyDown,
      priority: epHigh,
      timestamp: getMonoTime(),
      key: getKeyPressed()
    )

  proc makeCharEvent*(): GuiEvent =
    ## Create character input event
    GuiEvent(
      kind: evChar,
      priority: epHigh,
      timestamp: getMonoTime(),
      char: char(getCharPressed())
    )

  proc makeSize*(width, height: int32): Size =
    ## Create Size from dimensions
    Size(width: float32(width), height: float32(height))

  proc makeWindowResizeEvent*(): GuiEvent =
    ## Create window resize event
    GuiEvent(
      kind: evWindowResize,
      priority: epNormal,
      timestamp: getMonoTime(),
      windowSize: makeSize(getScreenWidth(), getScreenHeight())
    )

# ============================================================================
# Event Collection - Collect and Add to Manager
# ============================================================================

when defined(useGraphics):
  proc collectMouseEvents*(app: App) =
    ## Collect all mouse events
    if hasMouseMoved():
      app.eventManager.addEvent(makeMouseMoveEvent())

    if hasMouseDown():
      app.eventManager.addEvent(makeMouseDownEvent())

    if hasMouseUp():
      app.eventManager.addEvent(makeMouseUpEvent())

    if hasMouseWheel():
      app.eventManager.addEvent(makeMouseWheelEvent())

  proc collectKeyboardEvents*(app: App) =
    ## Collect all keyboard events
    if hasKeyPress():
      app.eventManager.addEvent(makeKeyDownEvent())

    if hasCharInput():
      app.eventManager.addEvent(makeCharEvent())

  proc collectWindowEvents*(app: App) =
    ## Collect window events
    if hasWindowResize():
      app.eventManager.addEvent(makeWindowResizeEvent())

  proc collectAllEvents*(app: App) =
    ## Collect all events from Raylib
    app.collectMouseEvents()
    app.collectKeyboardEvents()
    app.collectWindowEvents()

# ============================================================================
# Frame Timing Helpers
# ============================================================================

proc shouldUpdateFPS*(app: App): bool =
  ## Check if one second has passed for FPS update
  let now = getMonoTime()
  (now - app.fpsUpdateTime) >= initDuration(seconds = 1)

proc updateFPSCounter*(app: var App) =
  ## Update FPS counter after one second
  let now = getMonoTime()
  app.currentFPS = float(app.frameCount)
  app.frameCount = 0
  app.fpsUpdateTime = now

proc incrementFrameCount*(app: var App) =
  ## Increment frame counter
  app.frameCount += 1

proc recordFrameTime*(app: var App, time: MonoTime) =
  ## Record last frame time
  app.lastFrameTime = time

# ============================================================================
# Scripting Helpers
# ============================================================================

proc shouldPollScripts*(app: App): bool =
  ## Check if one second has passed for script polling
  if not app.scriptingEnabled:
    return false
  let now = getMonoTime()
  (now - app.lastScriptPoll) >= initDuration(seconds = 1)

proc updateScriptPollTime*(app: var App) =
  ## Update last script poll time
  app.lastScriptPoll = getMonoTime()

# ============================================================================
# Layout and Rendering Checks
# ============================================================================

proc needsLayout*(app: App): bool =
  ## Check if widget tree needs layout update
  app.tree.anyDirty and app.tree.root != nil

proc hasRootWidget*(app: App): bool =
  ## Check if app has a root widget
  app.tree.root != nil

proc markLayoutClean*(app: var App) =
  ## Mark layout as no longer dirty
  app.tree.anyDirty = false

# ============================================================================
# Main Loop Predicates
# ============================================================================

when defined(useGraphics):
  proc shouldContinue*(app: App): bool =
    ## Check if main loop should continue
    not windowShouldClose() and not app.shouldClose

proc shouldClose*(app: App): bool =
  ## Check if app should close
  app.shouldClose

# ============================================================================
# Window Initialization
# ============================================================================

when defined(useGraphics):
  proc initializeWindow*(app: App) =
    ## Initialize Raylib window
    initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
    setTargetFPS(app.window.fps.int32)

  proc configureWindowResize*(app: App) =
    ## Configure window resizability
    if app.window.resizable:
      setWindowState(flags(WindowResizable))
      if app.window.minWidth > 0 and app.window.minHeight > 0:
        setWindowMinSize(app.window.minWidth.int32, app.window.minHeight.int32)

  proc printWindowInfo*(app: App) =
    ## Print window configuration info
    echo "RUI Application Started"
    echo "  Window: ", app.window.width, "x", app.window.height
    echo "  Target FPS: ", app.window.fps
    echo "  Resizable: ", app.window.resizable
    if app.window.resizable:
      echo "  Min size: ", app.window.minWidth, "x", app.window.minHeight
    echo "  Event budget: ", app.eventManager.defaultBudget.inMilliseconds, "ms"
    echo ""

# ============================================================================
# Frame Processing Steps
# ============================================================================

when defined(useGraphics):
  proc processFrameEvents*(app: App): int =
    ## Process all events in this frame
    app.eventManager.processEvents(
      app.eventManager.currentBudget,
      proc(event: GuiEvent) = app.handleEvent(event)
    )

proc runLayoutPass*(app: var App) =
  ## Run layout pass if needed
  if app.needsLayout:
    # TODO: Implement layout manager
    app.markLayoutClean()

when defined(useGraphics):
  proc renderFrame*(app: App) =
    ## Render current frame
    beginDrawing()
    clearBackground(RayWhite)

    # TODO: Implement render manager

    # Placeholder rendering
    if app.hasRootWidget:
      drawText("RUI Application Running", 10'i32, 10'i32, 20'i32, DarkGray)
      drawText("FPS: " & $app.currentFPS, 10'i32, 40'i32, 16'i32, Green)
      drawText("Events: " & $app.eventManager.queueLength, 10'i32, 60'i32, 16'i32, Blue)

    endDrawing()

proc updateFPSIfNeeded*(app: var App) =
  ## Update FPS counter if one second has passed
  app.incrementFrameCount()
  if app.shouldUpdateFPS():
    app.updateFPSCounter()

proc pollScriptsIfNeeded*(app: var App) =
  ## Poll script commands if enabled and one second has passed
  if app.shouldPollScripts():
    # TODO: Implement script polling
    app.updateScriptPollTime()
