## RUI Application Core
##
## Main application loop with integrated event processing, layout, and rendering

import rui_core
import rui_events
import rui_drawing
import rui_scripting
import rui_hittest
export rui_core
export event_manager_refactored   # Export for users to access eventManager
export focus_manager              # Export focus manager
export hover_tracker              # Export hover tracker
export theme_sys_core # Export theme types
export theme_manager  # Export theme manager
export script_manager # Export script manager
export hittest_system # Export hit test system
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
    hoverTracker*: HoverTracker
    scriptManager*: ScriptManager
    hitTestSystem*: HitTestSystem

    # Internal state
    currentFocusLayout: Widget       # Internal: layout container with focus

    # Theme and rendering
    themeManager*: ThemeManager
    # No `currentTheme` field: it was written on construction and on every
    # setTheme and read by nothing. The apparent read in renderFrame is the
    # *global* currentTheme from theme_sys_core -- Nim has no implicit self, so
    # a bare name there was never the field. Read the theme with `app.getTheme`
    # or the global; there is no third answer to "what theme is current".

    # Frame timing
    # Exported: examples, overlays and perf tooling read these from outside
    # this module, and an unexported field is invisible there even though
    # app.nim's own FPS overlay can see it.
    lastFrameTime*: MonoTime
    frameCount*: int
    fpsUpdateTime*: MonoTime
    currentFPS*: float

    # Scripting support (deprecated - use scriptManager)
    scriptingEnabled*: bool
    scriptDir*: string
    lastScriptPoll: MonoTime

    # Per-frame hook
    onFrame*: Option[proc() {.closure.}]
      ## Called once per frame, before events are collected.
      ##
      ## For work the event stream cannot deliver: window file drops
      ## (DragDropArea.pollFileDrops), animation ticks, polling an external
      ## source. Widgets must not reach for raylib inside `render` to do this --
      ## render only runs on frames where the widget is dirty, and it runs
      ## inside a render texture with the widget's origin shifted to (0, 0).

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
    hoverTracker: newHoverTracker(),
    scriptManager: nil,  # Created when scripting is enabled
    hitTestSystem: newHitTestSystem(),
    themeManager: newThemeManager(),  # Registers built-in themes, sets light as default
    lastFrameTime: getMonoTime(),
    frameCount: 0,
    fpsUpdateTime: getMonoTime(),
    currentFPS: 0.0,

    scriptingEnabled: false,
    scriptDir: "",
    lastScriptPoll: getMonoTime(),
    shouldClose: false
  )
  # ThemeManager already set "light" as default and updated the global.

proc setStore*(app: App, store: Store) =
  ## Set the application store
  app.store = store

proc setRootWidget*(app: App, root: Widget) =
  ## Set the root widget and trigger initial layout + render.
  ##
  ## The root is sized to the window here. Callers should not have to do it by
  ## hand: a root left at its default zero size makes every padded container
  ## compute a negative child width, which the hit-test interval tree rejects
  ## with "start must be <= fin".
  app.tree.root = root
  if app.tree.widgetsByStringId.len == 0:
    app.tree.widgetsByStringId = initTable[string, Widget]()
  app.tree.registerWidgetRecursive(root)
  # A different root is a different focus chain, and swapping it does not go
  # through addChild, so the structure version would not notice on its own.
  app.focusManager.markDirty()
  app.hoverTracker.clear()
  root.bounds = Rect(x: 0, y: 0,
                     width: app.window.width.float32,
                     height: app.window.height.float32)
  root.layoutDirty = true
  root.isDirty = true
  app.tree.anyDirty = true
  app.tree.isDirty = true

proc enableScripting*(app: App, scriptDir: string) =
  ## Enable scripting system with specified directory
  app.scriptingEnabled = true
  app.scriptDir = scriptDir
  if not dirExists(scriptDir):
    createDir(scriptDir)

  # Create script manager
  app.tree.widgetsByStringId = initTable[string, Widget]()  # Ensure initialized
  app.scriptManager = newScriptManager(scriptDir, app.tree)

  # Key injection is a TEST-ONLY affordance, compiled in with -d:ruiTestKeys.
  #
  # The scripting subsystem is deliberately semantic: a script addresses a
  # control by id and operates it directly -- `agree invoke`, `progress write
  # value=40` -- rather than emulating the keyboard or the mouse. That is the
  # whole point of it, and it is why a script does not care where focus happens
  # to be or what a widget's key bindings are.
  #
  # Driving the focus machinery end-to-end is the one thing that genuinely needs
  # a real key press, so the capability exists for tools/ui_test.sh and is
  # absent from an ordinary build. Without the flag `onKey` stays nil and the
  # `key` command reports that the host has not wired it up.
  when defined(ruiTestKeys):
    app.scriptManager.onKey = proc(keyName: string): bool =
      var key: KeyboardKey
      try:
        key = parseEnum[KeyboardKey](keyName)
      except ValueError:
        return false
      let event = GuiEvent(kind: evKeyDown, key: key, timestamp: getMonoTime())
      result = app.focusManager.handleKeyboardEvent(event, app.tree.root)
      if result:
        app.tree.anyDirty = true

proc setScriptPollInterval*(app: App, seconds: float64) =
  ## How often the app checks for a script command file. The 1s default is fine
  ## interactively but makes automated test runs crawl; a harness can drop this
  ## to e.g. 0.05.
  if app.scriptManager != nil:
    app.scriptManager.setPolling(seconds)

proc disableScripting*(app: App) =
  ## Disable scripting system
  if app.scriptManager != nil:
    app.scriptManager.disable()
  app.scriptingEnabled = false

# ============================================================================
# Theme Management
# ============================================================================

proc setTheme*(app: App, theme: Theme) =
  ## Change the application theme by Theme object.
  ##
  ## Setting the tree-level flags is not enough on its own: frame() gates the
  ## render pass on the *root widget's* flags, and composites read theme props
  ## inside layout(), so every widget has to be marked or the switch does not
  ## reach the screen.
  app.themeManager.setTheme(theme)
  app.tree.anyDirty = true
  app.tree.isDirty = true
  app.tree.root.markSubtreeDirty()

proc setTheme*(app: App, name: string) =
  ## Change the application theme by name (must be registered in themeManager)
  app.themeManager.setTheme(name)
  app.tree.anyDirty = true
  app.tree.isDirty = true
  app.tree.root.markSubtreeDirty()

proc getTheme*(app: App): Theme =
  ## Get the current theme
  app.themeManager.current

# ============================================================================
# Current State Accessors (Query Managers)
# ============================================================================

proc currentWidget*(app: App): Widget =
  ## Get the widget currently under the mouse cursor
  ## Returns nil if no widget is under the cursor
  ## Queries hitTestSystem with current mouse position
  let mousePos = getMousePosition()
  return app.hitTestSystem.getWidgetAt(mousePos.x, mousePos.y)
proc currentFocusedWidget*(app: App): Widget =
  ## Get the widget that currently has keyboard focus
  ## Returns nil if no widget has focus
  ## Queries focusManager for current focus
  app.focusManager.getFocusedWidget()

# ============================================================================
# Text Cache Management
# ============================================================================

# These used to operate on an `App.textCache` field that nothing ever wrote to,
# so `clearTextCache` cleared an always-empty table and `getTextCacheStats`
# always reported zeros while the real glyph cache kept its contents. They act on
# the live cache in pango_text now, which is the one that actually holds glyphs.

proc clearTextCache*(app: App) =
  ## Drop every cached glyph texture.
  pango_text.clearTextCache()

proc getTextCacheStats*(app: App): TextureCacheStats =
  ## Entry count, memory use, hits and misses for the glyph cache.
  textCacheStats()

proc printTextCacheStats*(app: App) =
  ## Print glyph cache statistics for debugging.
  let s = textCacheStats()
  echo "Glyph cache:   ", s.entries, " entries, ", s.memoryBytes div 1024,
       " KiB, ", s.hits, " hits / ", s.misses, " misses"
  echo "Measure cache: ", s.measureEntries, " entries, ",
       s.measureHits, " hits / ", s.measureMisses, " misses"

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
      timestamp: getMonoTime(),
      wheelDelta: wheelMove
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

template traceEvent(args: varargs[untyped]) =
  ## Per-event tracing, compiled out entirely unless built with `-d:ruiTrace`.
  ##
  ## These used to be bare `echo`s inside `handleEvent`, which runs per event
  ## under a time budget — a held key or a window drag turned into a stream of
  ## writes to stdout in the hot path, in every application built on the library.
  when defined(ruiTrace):
    echo args

proc dispatchBubbling(widget: Widget, event: GuiEvent): bool =
  ## Offer the event to the hit widget, then to each ancestor in turn until one
  ## handles it.
  ##
  ## Composite widgets build themselves out of primitives -- a Button is a
  ## Rectangle plus a Label -- and hit-testing lands on the innermost of those.
  ## Those primitives declare no event handlers, so without bubbling the click
  ## stopped at the Rectangle and the Button's onClick never fired.
  var w = widget
  while w != nil:
    if w.handleInput(event):
      return true
    w = w.parent
  false

proc handleEvent(app: App, event: GuiEvent) =
  ## Handle a single event
  ## Routes events to appropriate widgets via hit-testing and focus manager

  case event.kind
  of evWindowResize:
    # Update window config, resize the root to match, and mark for relayout
    app.window.width = int(event.windowSize.width)
    app.window.height = int(event.windowSize.height)
    if app.tree.root != nil:
      app.tree.root.bounds.width = event.windowSize.width
      app.tree.root.bounds.height = event.windowSize.height
      app.tree.root.layoutDirty = true
      app.tree.root.isDirty = true
    app.tree.anyDirty = true
    traceEvent "[Event] Window resized to ", event.windowSize.width, "x", event.windowSize.height

  of evMouseDown:
    # Hit-test to find widget under mouse and request focus
    let widget = app.hitTestSystem.getWidgetAt(event.mousePos.x, event.mousePos.y)
    if widget != nil:
      app.focusManager.requestFocus(widget)
      discard widget.dispatchBubbling(event)
      widget.markDirtyToRoot()   # press state changed -> repaint up to root
      app.tree.anyDirty = true

  of evMouseUp:
    # Route to widget under mouse
    let widget = app.hitTestSystem.getWidgetAt(event.mousePos.x, event.mousePos.y)
    if widget != nil:
      discard widget.dispatchBubbling(event)
      widget.markDirtyToRoot()
      app.tree.anyDirty = true

  of evMouseMove:
    # Update hover state: clear old, set new.
    #
    # The clearing half used to be missing -- this only ever set `hovered = true`
    # and nothing anywhere set it back, so every widget the pointer had ever
    # touched stayed lit. hoverTracker owns the transition now, and reports
    # whether one happened so a still pointer costs nothing.
    let widget = app.hitTestSystem.getWidgetAt(event.mousePos.x, event.mousePos.y)
    let previous = app.hoverTracker.hovered
    if app.hoverTracker.setHover(widget):
      if previous != nil:
        previous.markDirtyToRoot()   # the widget being left has to repaint too
      if widget != nil:
        widget.markDirtyToRoot()
      app.tree.anyDirty = true
    if widget != nil:
      discard widget.dispatchBubbling(event)

  of evMouseWheel:
    # Route wheel to widget under mouse
    let widget = app.hitTestSystem.getWidgetAt(event.mousePos.x, event.mousePos.y)
    if widget != nil:
      discard widget.dispatchBubbling(event)
      widget.markDirtyToRoot()   # e.g. scroll offset changed
      app.tree.anyDirty = true

  of evKeyDown, evChar:
    # Route keyboard events through focus manager
    if app.tree.root != nil:
      let handled = app.focusManager.handleKeyboardEvent(event, app.tree.root)
      if not handled:
        traceEvent "[Event] Keyboard event not handled: ", event.kind
    else:
      traceEvent "[Event] No root widget - keyboard event ignored"

  else:
    discard

# ============================================================================
# Layout Pass
# ============================================================================

proc rebuildHitTestTree(app: App) =
  ## Rebuild the hit-test system from the current widget tree
  ## Called after layout pass when widget bounds have been updated
  app.hitTestSystem.clear()
  if app.tree.root != nil:
    proc insertAll(widget: Widget) =
      if widget.visible:
        app.hitTestSystem.insertWidget(widget)
        for child in widget.children:
          insertAll(child)
    insertAll(app.tree.root)

proc updateLayoutAndRender(app: App) =
  ## Run layout and render passes if needed
  if app.tree.root != nil:
    # Does anything actually need laying out this frame? Asked before frame(),
    # because frame() clears the flags it checks.
    let layoutWillRun = app.tree.root.layoutDirty or
                        app.tree.root.anyChildLayoutDirty()

    # Run the two-pass system from main_loop
    app.tree.root.frame()  # Calls layoutPass() and renderPass()

    # Both of these walk the whole tree, and both only have anything to do when
    # bounds moved or a widget appeared -- so they are gated on layout having
    # run. They used to happen unconditionally on every frame: frame() guards
    # the layout and render passes on the dirty flags, but these two sat outside
    # that guard and ran 60 times a second whether or not anything had changed.
    # Measured at 53.5us for a 201-widget tree, growing linearly with the tree.
    if layoutWillRun:
      # Bounds are up to date now, so the hit-test trees can be rebuilt.
      app.rebuildHitTestTree()

      # Re-register so scripting selectors can find widgets by stringId. This
      # has to follow layout because a widget can be added during it.
      app.tree.registerWidgetRecursive(app.tree.root)

    app.tree.anyDirty = false

# ============================================================================
# Render Pass
# ============================================================================

proc renderFrame(app: App) =
  ## Render the current frame
  beginDrawing()
  # The window surround follows the active theme rather than a hardcoded
  # RayWhite, so a dark theme does not leave a light border around the UI.
  clearBackground(currentTheme.canvasColor())

  # Composite root widget's cached texture to screen
  if app.tree.root != nil and app.tree.root.cachedTexture.isSome:
    # Draw at root's position (typically 0, 0); borrow, no copy
    drawRenderTexture(app.tree.root.cachedTexture.get(),
                      app.tree.root.bounds.x,
                      app.tree.root.bounds.y)

  # Visual indicator when being scripted
  if app.scriptManager != nil and app.scriptManager.isBeingScripted():
    let borderWidth = 4'i32
    let screenWidth = getScreenWidth()
    let screenHeight = getScreenHeight()
    let scriptColor = Color(r: 255, g: 165, b: 0, a: 200)  # Orange with transparency

    # Draw border around entire window
    drawRectangleLines(0, 0, screenWidth, screenHeight, scriptColor)
    drawRectangleLines(1, 1, screenWidth - 2, screenHeight - 2, scriptColor)
    drawRectangleLines(2, 2, screenWidth - 4, screenHeight - 4, scriptColor)
    drawRectangleLines(3, 3, screenWidth - 6, screenHeight - 6, scriptColor)

    # Optional: Draw indicator text in top-right corner
    let indicatorText = "SCRIPTING"
    let textWidth = measureText(indicatorText, 14'i32)
    let textX = screenWidth - textWidth - 10
    let textY = 5'i32
    # Background for text
    drawRectangle(textX - 5, textY - 2, textWidth + 10, 20, Color(r: 0, g: 0, b: 0, a: 150))
    # Text
    drawText(indicatorText, textX, textY, 14'i32, scriptColor)

  # Debug overlay (optional - can be removed later)
  when defined(debugUI):
    drawText("FPS: " & $app.currentFPS, 10'i32, 10'i32, 16'i32, DarkGray)
    drawText("Events: " & $app.eventManager.queueLength, 10'i32, 30'i32, 16'i32, DarkGray)

  endDrawing()

# ============================================================================
# Scripting Support
# ============================================================================

proc pollScriptCommands(app: App) =
  ## Poll for script commands
  ## The script manager handles its own timing
  if app.scriptManager != nil:
    app.scriptManager.poll()

# ============================================================================
# Main Loop
# ============================================================================

proc run*(app: App, maxFrames: int = -1) =
  ## Run the main application loop.
  ##
  ## `maxFrames` > 0 stops after that many frames and closes the window. That
  ## is what automated tests and screenshot capture want; Stage B removed the
  ## old headless mode on purpose, and this is the graphics-only equivalent --
  ## a real window, really rendered, for a bounded number of frames.

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
  var framesRun = 0
  while not windowShouldClose() and not app.shouldClose:
    if maxFrames > 0 and framesRun >= maxFrames:
      break
    inc framesRun
    let frameStart = getMonoTime()

    # 0. Per-frame hook, before anything reads input state for this frame
    if app.onFrame.isSome:
      app.onFrame.get()()

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
