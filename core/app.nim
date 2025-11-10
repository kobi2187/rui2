## RUI Application Core
##
## Main application loop with integrated event processing, layout, and rendering

import types, link, main_loop
import ../managers/event_manager
export event_manager  # Export for users to access eventManager
export main_loop  # Export for frame(), layoutPass(), renderPass()
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
    # renderManager*: RenderManager  # TODO: implement
    # layoutManager*: LayoutManager  # TODO: implement

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
  ## TODO: Route to widgets via hit testing

  case event.kind
  of evWindowResize:
    # Update window config and mark for relayout
    app.window.width = int(event.windowSize.width)
    app.window.height = int(event.windowSize.height)
    app.tree.anyDirty = true
    echo "[Event] Window resized to ", event.windowSize.width, "x", event.windowSize.height

  of evMouseDown, evMouseUp:
    # TODO: Hit testing and widget event routing
    echo "[Event] Mouse ", event.kind, " at ", event.mousePos

  of evKeyDown:
    echo "[Event] Key pressed: ", event.key

  of evChar:
    echo "[Event] Char input: ", event.char

  else:
    discard

# ============================================================================
# Layout Pass
# ============================================================================

proc updateLayoutAndRender(app: App) =
  ## Run layout and render passes if needed
  if app.tree.root != nil:
    # Run the two-pass system from main_loop
    app.tree.root.frame()  # Calls layoutPass() and renderPass()
    app.tree.anyDirty = false

# ============================================================================
# Render Pass
# ============================================================================

when defined(useGraphics):
  proc renderFrame(app: App) =
    ## Render the current frame
    beginDrawing()
    clearBackground(RayWhite)

    # Composite root widget's cached texture to screen
    if app.tree.root != nil and app.tree.root.cachedTexture.isSome:
      let rootTex = app.tree.root.cachedTexture.get()
      # Draw at root's position (typically 0, 0)
      drawTexture(rootTex.texture,
                  app.tree.root.bounds.x.int32,
                  app.tree.root.bounds.y.int32,
                  White)

    # Debug overlay (optional - can be removed later)
    when defined(debugUI):
      drawText("FPS: " & $app.currentFPS, 10'i32, 10'i32, 16'i32, DarkGray)
      drawText("Events: " & $app.eventManager.queueLength, 10'i32, 30'i32, 16'i32, DarkGray)

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

      # 5. Layout and render passes (if tree is dirty)
      app.updateLayoutAndRender()

      # 6. Composite to screen
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

    # 4. Layout and render
    app.updateLayoutAndRender()

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
