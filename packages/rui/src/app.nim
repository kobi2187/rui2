## RUI Application Core
##
## Main application loop with integrated event processing, layout, and rendering

import rui_core
import rui_events
import rui_drawing
import rui_scripting
import rui_hittest
import event_source
import event_routing
import inspect
export event_source, event_routing, inspect
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

    # Where input comes from, and where it goes. Both are fields rather than
    # hardcoded calls, which is what lets a test run a frame without a window.
    eventSource*: EventSource
    router*: EventRouter

    # Per-frame hook
    onFrame*: proc() {.closure.}
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
    shouldClose: false,

    eventSource: newRaylibEventSource()
  )
  # The router borrows the three collaborators rather than owning them, so
  # `app.focusManager` and `app.router.focus` are the same object -- code that
  # reaches for either sees the same focus.
  result.router = newEventRouter(result.hitTestSystem, result.focusManager,
                                 result.hoverTracker)
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

proc injectKey(app: App, keyName: string): bool =
  ## Synthesise a key press at whatever currently has focus. **Test-only** --
  ## reached from `enableScripting` under -d:ruiTestKeys and nowhere else.
  var key: KeyboardKey
  try:
    key = parseEnum[KeyboardKey](keyName)
  except ValueError:
    return false
  let event = GuiEvent(kind: evKeyDown, key: key, timestamp: getMonoTime())
  result = app.focusManager.handleKeyboardEvent(event, app.tree.root)
  if result:
    app.tree.anyDirty = true

proc dirtyCount(widget: Widget): int =
  ## How many widgets in this subtree still want a repaint or a relayout.
  ## Zero means the frame has settled.
  if widget == nil:
    return 0
  if widget.isDirty or widget.layoutDirty:
    result = 1
  for child in widget.children:
    result += child.dirtyCount

proc inspectSettle(app: App): string =
  ## How much is still pending. The harness polls this instead of sleeping.
  ##
  ## Deliberately *not* a command that blocks until clean: settling needs
  ## frames to run, and the script poll happens inside a frame, so a blocking
  ## wait would deadlock against the thing it is waiting for. Returning the
  ## count and letting the caller poll costs a few lines instead of
  ## cross-frame pending state, and removes the fixed sleeps either way.
  let pending = app.tree.root.dirtyCount
  $pending & (if pending == 0: " settled" else: " pending")

proc inspectAt(app: App, args: string): Option[string] =
  ## `hit <x> <y>`: what a click there would land on.
  let parts = args.splitWhitespace()
  if parts.len < 3:
    return none(string)
  try:
    some($inspectHit(app.hitTestSystem, parseFloat(parts[1]).float32,
                     parseFloat(parts[2]).float32))
  except ValueError:
    none(string)

proc answerInspect(app: App, selector, what: string): Option[string] =
  ## The one place an inspector is added: a case arm, not another verb.
  if what == "tree":
    return some(inspectTree(app.tree.root))
  if what == "settle":
    return some(app.inspectSettle)
  if what.startsWith("hit"):
    return app.inspectAt(what)

  let widget = app.tree.findWidget(selector)
  if widget.isNone:
    return none(string)
  case what
  of "visible": some($inspectVisible(widget.get()))
  else: none(string)

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
  # Inspection is a TEST-ONLY affordance too, compiled in with -d:ruiInspect.
  #
  # A separate flag from ruiTestKeys on purpose: these are read-only queries
  # about the framework -- where a widget lands after clipping, which frame it
  # last repainted on, what sits under a point -- and carry none of the
  # objection that input emulation does. Different risk, different switch, so a
  # harness can have one without the other.
  when defined(ruiInspect):
    app.scriptManager.onInspect = proc(selector, what: string): Option[string] =
      app.answerInspect(selector, what)

  when defined(ruiTestKeys):
    app.scriptManager.onKey = proc(keyName: string): bool =
      app.injectKey(keyName)

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

proc collectEvents(app: App) =
  ## Ask this frame's event source what happened, and queue it.
  ##
  ## Which source is a field, so a test can hand the pipeline a list of events
  ## and run a frame with no window at all. This used to read raylib directly
  ## from here, which is why the frame pipeline had no headless tests.
  for event in app.eventSource.poll():
    app.eventManager.addEvent(event)

# ============================================================================
# Event Handling
# ============================================================================

template traceEvent(args: varargs[untyped]) =
  ## Per-event tracing, compiled out entirely unless built with `-d:ruiTrace`.
  ##
  ## These used to be bare `echo`s inside `handleEvent`, which runs per event
  ## under a time budget -- a held key or a window drag turned into a stream of
  ## writes to stdout in the hot path, in every application built on the library.
  when defined(ruiTrace):
    echo args

proc handleWindowResize(app: App, event: GuiEvent) =
  app.window.width = int(event.windowSize.width)
  app.window.height = int(event.windowSize.height)
  discard resizeRoot(app.tree.root, event.windowSize)
  app.tree.anyDirty = true
  traceEvent "[Event] Window resized to ", event.windowSize.width, "x",
             event.windowSize.height

proc handleEvent(app: App, event: GuiEvent) =
  ## Route one event. The work is in event_routing.nim; this is the three-way
  ## split between window, pointer and keyboard, and the dirty bookkeeping.
  case event.kind
  of evWindowResize:
    app.handleWindowResize(event)

  of evMouseDown, evMouseUp, evMouseMove, evMouseWheel:
    if app.router.routePointer(event):
      app.tree.anyDirty = true

  of evKeyDown, evChar:
    if not app.router.routeKeyboard(app.tree.root, event):
      traceEvent "[Event] Keyboard event not handled: ", event.kind

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

proc refreshLayout*(app: App) =
  ## The layout pass, and the two tree walks that depend on it.
  ##
  ## No GL: laying out, hit-testing and the scripting registry are all plain
  ## tree work. Only the render pass needs a window, which is why this is
  ## separate -- it is the whole frame minus the one part that cannot run
  ## headless.
  if app.tree.root == nil:
    return

  # Does anything actually need laying out this frame? Asked before layoutPass,
  # because it clears the flags it checks.
  let layoutWillRun = app.tree.root.layoutDirty or
                      app.tree.root.anyChildLayoutDirty()
  app.tree.root.layoutPass()

  # Both of these walk the whole tree, and both only have anything to do when
  # bounds moved or a widget appeared -- so they are gated on layout having
  # run. They used to happen unconditionally on every frame, outside the dirty
  # guard, 60 times a second whether or not anything had changed. Measured at
  # 53.5us for a 201-widget tree, growing linearly with the tree.
  if not layoutWillRun:
    return
  app.rebuildHitTestTree()
  # Re-register so scripting selectors can find widgets by stringId. This has
  # to follow layout because a widget can be added during it.
  app.tree.registerWidgetRecursive(app.tree.root)

proc updateLayoutAndRender(app: App) =
  ## Lay out, then paint whatever is dirty into the widget textures.
  if app.tree.root == nil:
    return
  app.refreshLayout()
  if app.tree.root.isDirty or app.tree.root.anyChildDirty():
    app.tree.root.renderPass()
  app.tree.anyDirty = false

# ============================================================================
# Render Pass
# ============================================================================

proc drawScriptingIndicator() =
  ## An orange frame and a corner label while a script is driving the app.
  ##
  ## Not decoration: a scripted window looks exactly like a hand-driven one, and
  ## somebody watching a test run needs to know which they are looking at before
  ## they reach for the mouse and fight it.
  const
    scriptColor = Color(r: 255, g: 165, b: 0, a: 200)
    indicatorText = "SCRIPTING"
  let screenWidth = getScreenWidth()
  let screenHeight = getScreenHeight()

  for inset in 0'i32 .. 3'i32:
    drawRectangleLines(inset, inset, screenWidth - inset * 2,
                       screenHeight - inset * 2, scriptColor)

  let textWidth = measureText(indicatorText, 14'i32)
  let textX = screenWidth - textWidth - 10
  drawRectangle(textX - 5, 3'i32, textWidth + 10, 20,
                Color(r: 0, g: 0, b: 0, a: 150))
  drawText(indicatorText, textX, 5'i32, 14'i32, scriptColor)

proc compositeRoot(app: App) =
  if app.tree.root != nil and app.tree.root.cachedTexture.isSome:
    drawRenderTexture(app.tree.root.cachedTexture.get(),
                      app.tree.root.bounds.x, app.tree.root.bounds.y)

proc beingScripted(app: App): bool =
  app.scriptManager != nil and app.scriptManager.isBeingScripted()

proc renderFrame(app: App) =
  ## Composite the root's cached texture to the screen.
  ##
  ## The whole tree is already painted by this point -- renderPass built each
  ## widget's texture and composited them upward -- so this is one blit plus
  ## whatever the window itself draws over it.
  beginDrawing()
  # The window surround follows the active theme rather than a hardcoded
  # RayWhite, so a dark theme does not leave a light border around the UI.
  clearBackground(currentTheme.canvasColor())

  app.compositeRoot()
  if app.beingScripted:
    drawScriptingIndicator()

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

proc openWindow(app: App) =
  initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
  setTargetFPS(app.window.fps.int32)
  if not app.window.resizable:
    return
  setWindowState(flags(WindowResizable))
  if app.window.minWidth > 0 and app.window.minHeight > 0:
    setWindowMinSize(app.window.minWidth.int32, app.window.minHeight.int32)

proc announce(app: App) =
  echo "RUI Application Started"
  echo "  Window: ", app.window.width, "x", app.window.height
  echo "  Target FPS: ", app.window.fps
  echo "  Resizable: ", app.window.resizable
  if app.window.resizable:
    echo "  Min size: ", app.window.minWidth, "x", app.window.minHeight
  echo "  Event budget: ", app.eventManager.defaultBudget.inMilliseconds, "ms"
  echo ""

proc pumpEvents*(app: App) =
  ## Everything a frame does before it touches the tree's geometry: the
  ## per-frame hook, collection, coalescing, routing, and the script poll.
  ##
  ## No GL. Exported so a test can drive input by hand -- fill a
  ## ListEventSource, pump, assert.
  # 0. Per-frame hook, before anything reads input state for this frame
  if app.onFrame != nil:
    app.onFrame()

  # 1. Collect events from this frame's source
  app.collectEvents()

  # 2. Process event patterns (coalescing)
  app.eventManager.update()

  # 3. Process events with time budget
  discard app.eventManager.processEvents(
    app.eventManager.currentBudget,
    proc(event: GuiEvent) = app.handleEvent(event))

  # 4. Poll script commands
  app.pollScriptCommands()

proc stepHeadless*(app: App) =
  ## A frame with the render pass left out: input, routing, layout, hit-test.
  ##
  ## This is the whole pipeline apart from the one part that needs a window, and
  ## it is what makes the frame testable at all -- before the event-source seam,
  ## `run` read raylib directly and there was nothing to call.
  app.pumpEvents()
  app.refreshLayout()

proc step*(app: App) =
  ## One frame of the pipeline, without the window or the loop around it.
  ## Needs a GL context, because it paints.
  app.pumpEvents()
  app.updateLayoutAndRender()

proc countFrame(app: App) =
  ## FPS is frames in the last whole second rather than a rolling average,
  ## which is what makes the number stand still long enough to read.
  app.frameCount += 1
  let now = getMonoTime()
  if (now - app.fpsUpdateTime) >= initDuration(seconds = 1):
    app.currentFPS = float(app.frameCount)
    app.frameCount = 0
    app.fpsUpdateTime = now

proc run*(app: App, maxFrames: int = -1) =
  ## Run the main application loop.
  ##
  ## `maxFrames` > 0 stops after that many frames and closes the window. That
  ## is what automated tests and screenshot capture want; Stage B removed the
  ## old headless mode on purpose, and this is the graphics-only equivalent --
  ## a real window, really rendered, for a bounded number of frames.
  app.openWindow()
  defer: closeWindow()
  app.announce()

  var framesRun = 0
  while not windowShouldClose() and not app.shouldClose:
    if maxFrames > 0 and framesRun >= maxFrames:
      break
    inc framesRun

    let frameStart = getMonoTime()
    app.step()
    app.renderFrame()       # 6. Composite to screen
    app.countFrame()
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
