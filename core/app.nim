## RUI Application Core
##
## Main application loop with integrated event processing, layout, and rendering

import types
import ../managers/event_manager_refactored
import ../managers/focus_manager
import ../drawing_primitives/primitives/text_cache
import ../drawing_primitives/theme_sys_core
export types                      # Export types (re-export what we import)
export event_manager_refactored   # Export for users to access eventManager
export focus_manager              # Export focus manager
export text_cache     # Export text cache types
export theme_sys_core # Export theme types
when defined(useGraphics):
  import raylib
import std/[monotimes, times, os]

# ============================================================================
# Application State
# ============================================================================

type
  App* = ref object
    # Core state
    tree*: WidgetTree
    store*: Store
    window*: WindowConfig

    # Managers (exported for testing)
    eventManager*: EventManager
    focusManager*: FocusManager

    currentFocusWidget: Widget
    currentFocusLayout: Widget

    # Theme and rendering
    currentTheme*: Theme
    textCache*: TextCache

    # Frame timing
    lastFrameTime: MonoTime
    frameCount: int
    fpsUpdateTime: MonoTime
    currentFPS: float

    # Scripting support
    scriptingEnabled*: bool
    scriptDir*: string
    lastScriptPoll: MonoTime

    # Control
    shouldClose*: bool

# Global app instance (for convenience - can also be passed explicitly)
var app*: App

# ============================================================================
# Initialization
# ============================================================================

proc newApp*(title = "RUI Application",
             width = 800,
             height = 600,
             fps = 60,
             resizable = true,
             minWidth = 320,
             minHeight = 240): App =
  ## Create a new RUI application
  result = App(
    tree: WidgetTree(
      root: nil,
      anyDirty: false,
      widgetMap: initTable[WidgetId, Widget]()
    ),
    store: nil,
    window: WindowConfig(
      width: width,
      height: height,
      title: title,
      fps: fps,
      resizable: resizable,
      minWidth: minWidth,
      minHeight: minHeight
    ),
    eventManager: newEventManager(defaultBudget = initDuration(milliseconds = 8)),
    focusManager: newFocusManager(),
    currentTheme: newTheme("Default"),
    textCache: TextCache(
      measurements: initTable[MeasurementKey, TextMetrics](),
      textures: initTable[RenderKey, TextureCacheEntry](),
      maxTextureMemoryMB: 100,
      maxEntries: 1000,
      currentMemoryBytes: 0
    ),
    lastFrameTime: getMonoTime(),
    frameCount: 0,
    fpsUpdateTime: getMonoTime(),
    currentFPS: 0.0,

    scriptingEnabled: false,
    scriptDir: "",
    lastScriptPoll: getMonoTime(),
    shouldClose: false
  )

proc setStore*(app: App, store: Store) =
  ## Set the application store
  app.store = store

proc setRootWidget*(app: App, root: Widget) =
  ## Set the root widget
  app.tree.root = root
  app.tree.anyDirty = true

proc enableScripting*(app: App, scriptDir: string) =
  ## Enable scripting system with specified directory
  app.scriptingEnabled = true
  app.scriptDir = scriptDir
  if not dirExists(scriptDir):
    createDir(scriptDir)

# ============================================================================
# Theme Management
# ============================================================================

proc setTheme*(app: App, theme: Theme) =
  ## Change the application theme
  ## This invalidates the text cache since colors/fonts may have changed
  app.currentTheme = theme
  # clearCache(app.textCache)  # Clear cache since theme affects rendering
  app.tree.anyDirty = true   # Trigger re-render
  app.tree.isDirty = true

proc getTheme*(app: App): Theme =
  ## Get the current theme
  app.currentTheme

# ============================================================================
# Text Cache Management
# ============================================================================

proc clearTextCache*(app: App) =
  ## Clear the text rendering cache
  clearCache(app.textCache)

proc getTextCacheStats*(app: App): auto =
  ## Get text cache statistics
  getCacheStats(app.textCache)

proc printTextCacheStats*(app: App) =
  ## Print text cache statistics for debugging
  printCacheStats(app.textCache)

when defined(useGraphics):
  proc setWindowSize*(app: App, width, height: int) =
    ## Programmatically resize the window
    setWindowSize(width.int32, height.int32)
    app.window.width = width
    app.window.height = height
    app.tree.anyDirty = true  # Trigger relayout

  proc setWindowResizable*(app: App, resizable: bool) =
    ## Enable or disable window resizing
    if resizable:
      setWindowState(flags(WindowResizable))
    else:
      clearWindowState(flags(WindowResizable))
    app.window.resizable = resizable

# ============================================================================
# Event Collection (Raylib Integration)
# ============================================================================

when defined(useGraphics):
  proc collectRaylibEvents(app: App) =
    ## Collect events from Raylib and add to event manager

    # Mouse events
    let mousePos = getMousePosition()

    # Mouse movement (replaceable - will be coalesced)
    if getMouseDelta().x != 0 or getMouseDelta().y != 0:
      app.eventManager.addEvent(GuiEvent(
        kind: evMouseMove,
        priority: epNormal,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    # Mouse buttons (ordered - sequence matters)
    if isMouseButtonPressed(Left):
      app.eventManager.addEvent(GuiEvent(
        kind: evMouseDown,
        priority: epHigh,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    if isMouseButtonReleased(Left):
      app.eventManager.addEvent(GuiEvent(
        kind: evMouseUp,
        priority: epHigh,
        timestamp: getMonoTime(),
        mousePos: Point(x: mousePos.x, y: mousePos.y)
      ))

    # Mouse wheel (throttled)
    let wheelMove = getMouseWheelMove()
    if wheelMove != 0:
      app.eventManager.addEvent(GuiEvent(
        kind: evMouseWheel,
        priority: epNormal,
        timestamp: getMonoTime()
      ))

    # Keyboard events (ordered - CRITICAL for text input)
    # Note: Raylib processes these in order already
    let key = getKeyPressed()
    if key != KeyboardKey(0):
      app.eventManager.addEvent(GuiEvent(
        kind: evKeyDown,
        priority: epHigh,
        timestamp: getMonoTime(),
        key: key
      ))

    # Character input for text
    let charPressed = getCharPressed()
    if charPressed.int32 > 0:
      app.eventManager.addEvent(GuiEvent(
        kind: evChar,
        priority: epHigh,
        timestamp: getMonoTime(),
        char: char(charPressed)
      ))

    # Window events
    if isWindowResized():
      app.eventManager.addEvent(GuiEvent(
        kind: evWindowResize,
        priority: epNormal,
        timestamp: getMonoTime(),
        windowSize: Size(
          width: float32(getScreenWidth()),
          height: float32(getScreenHeight())
        )
      ))

# ============================================================================
# Event Handling
# ============================================================================

proc handleEvent(app: App, event: GuiEvent) =
  ## Handle a single event
  ## Routes events to appropriate widgets via hit-testing and focus manager

  case event.kind
  of evWindowResize:
    # Update window config and mark for relayout
    app.window.width = int(event.windowSize.width)
    app.window.height = int(event.windowSize.height)
    app.tree.anyDirty = true
    echo "[Event] Window resized to ", event.windowSize.width, "x", event.windowSize.height

  of evMouseDown:
    # Hit-test to find widget under mouse and request focus
    # TODO: Build hit-test system in layout pass
    # let widgets = app.hitTestSystem.findWidgetsAt(event.mousePos.x, event.mousePos.y)
    # if widgets.len > 0:
    #   let topWidget = widgets[0]  # Already sorted by z-index
    #   app.focusManager.requestFocus(topWidget)
    #   topWidget.handleInput(event)
    echo "[Event] Mouse down at ", event.mousePos

  of evMouseUp:
    # Route to widget under mouse
    # TODO: Implement with hit-testing
    echo "[Event] Mouse up at ", event.mousePos

  of evKeyDown, evChar:
    # Route keyboard events through focus manager
    if app.tree.root != nil:
      let handled = app.focusManager.handleKeyboardEvent(event, app.tree.root)
      if not handled:
        echo "[Event] Keyboard event not handled: ", event.kind
    else:
      echo "[Event] No root widget - keyboard event ignored"

  else:
    discard

# ============================================================================
# Layout Pass
# ============================================================================

proc updateLayout(app: App) =
  ## Run layout pass if needed
  if app.tree.anyDirty and app.tree.root != nil:
    echo "[Layout] Running layout pass (tree is dirty)"
    # TODO: Implement layout manager
    # app.layoutManager.layout(app.tree.root)
    app.tree.anyDirty = false

# ============================================================================
# Render Pass
# ============================================================================

when defined(useGraphics):
  proc renderFrame(app: App) =
    ## Render the current frame
    beginDrawing()
    clearBackground(RayWhite)

    # TODO: Implement render manager
    # app.renderManager.render(app.tree.root)

    # For now, just draw placeholder
    if app.tree.root != nil:
      drawText("RUI Application Running", 10'i32, 10'i32, 20'i32, DarkGray)
      drawText("FPS: " & $app.currentFPS, 10'i32, 40'i32, 16'i32, Green)
      drawText("Events in queue: " & $app.eventManager.queueLength, 10'i32, 60'i32, 16'i32, Blue)

    endDrawing()

# ============================================================================
# Scripting Support
# ============================================================================

proc pollScriptCommands(app: App) =
  ## Poll for script commands (called once per second)
  if not app.scriptingEnabled:
    return

  let now = getMonoTime()
  if (now - app.lastScriptPoll) >= initDuration(seconds = 1):
    # TODO: Read commands from script directory
    # processScriptCommands(app)
    app.lastScriptPoll = now

# ============================================================================
# Main Loop
# ============================================================================

when defined(useGraphics):
  proc run*(app: App) =
    ## Run the main application loop

    # Initialize window
    initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
    setTargetFPS(app.window.fps.int32)

    # Configure window resizability
    if app.window.resizable:
      setWindowState(flags(WindowResizable))
      # Set minimum window size if specified
      if app.window.minWidth > 0 and app.window.minHeight > 0:
        setWindowMinSize(app.window.minWidth.int32, app.window.minHeight.int32)

    defer: closeWindow()

    echo "RUI Application Started"
    echo "  Window: ", app.window.width, "x", app.window.height
    echo "  Target FPS: ", app.window.fps
    echo "  Resizable: ", app.window.resizable
    if app.window.resizable:
      echo "  Min size: ", app.window.minWidth, "x", app.window.minHeight
    echo "  Event budget: ", app.eventManager.defaultBudget.inMilliseconds, "ms"
    echo ""

    # Main loop
    while not windowShouldClose() and not app.shouldClose:
      let frameStart = getMonoTime()

      # 1. Collect events from Raylib
      app.collectRaylibEvents()

      # 2. Process event patterns (coalescing)
      app.eventManager.update()

      # 3. Process events with time budget
      let eventsProcessed = app.eventManager.processEvents(
        app.eventManager.currentBudget,
        proc(event: GuiEvent) = app.handleEvent(event)
      )

      # 4. Poll script commands (once per second)
      app.pollScriptCommands()

      # 5. Layout pass (if tree is dirty)
      app.updateLayout()

      # 6. Render frame
      app.renderFrame()

      # Update FPS counter
      app.frameCount += 1
      let now = getMonoTime()
      if (now - app.fpsUpdateTime) >= initDuration(seconds = 1):
        app.currentFPS = float(app.frameCount)
        app.frameCount = 0
        app.fpsUpdateTime = now

      app.lastFrameTime = frameStart

proc runHeadless*(app: App, frames: int = -1) =
  ## Run without graphics (for testing)
  echo "RUI Application Started (Headless Mode)"
  echo "  Event budget: ", app.eventManager.defaultBudget.inMilliseconds, "ms"
  echo ""

  var frameCount = 0
  while (frames < 0 or frameCount < frames) and not app.shouldClose:
    # 1. Process event patterns
    app.eventManager.update()

    # 2. Process events
    let eventsProcessed = app.eventManager.processEvents(
      app.eventManager.currentBudget,
      proc(event: GuiEvent) = app.handleEvent(event)
    )

    # 3. Poll scripts
    app.pollScriptCommands()

    # 4. Layout
    app.updateLayout()

    inc frameCount

    # Sleep to simulate frame timing
    sleep(16)  # ~60 FPS

# ============================================================================
# Debug/Stats
# ============================================================================

proc getStats*(app: App): string =
  ## Get application statistics
  result = "RUI Application Stats:\n"
  result &= "  FPS: " & $app.currentFPS & "\n"
  result &= "  Frame count: " & $app.frameCount & "\n"
  result &= "\n"
  result &= app.eventManager.getStats()
