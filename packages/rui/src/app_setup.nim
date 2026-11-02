## Part of app.nim (included, not imported): Creating the App, its theme, what it reports, and its text cache.

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
  ## Create a new RUI application.
  ##
  ## The user's preferences (keys, motion, scroll speed, ...) are read here,
  ## once: they belong to the person at the keyboard and are the same in every
  ## RUI app. A file with mistakes is reported on stderr and degrades only the
  ## settings that are wrong.
  let (userPrefs, problems) = loadPreferences()
  applyPreferences(userPrefs)
  for problem in problems:
    stderr.writeLine "rui: preferences: " & problem
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
    probe: nil,
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
    idleWhenClean: true,
    idleRefresh: DurationZero,

    eventSource: newRaylibEventSource()
  )
  # The router borrows the three collaborators rather than owning them, so
  # `app.focusManager` and `app.router.focus` are the same object -- code that
  # reaches for either sees the same focus.
  result.router = newEventRouter(result.hitTestSystem, result.focusManager,
                                 result.hoverTracker)
  wakeHook = wakeMainLoop
  if getEnv("RUI_NO_PARTIAL").len > 0:
    partialRepaint = false        # repaint whole widgets only: to compare against
  # A widget disposed while focused, hovered or under the pointer must not stay
  # referenced from here (the last App created owns the hook).
  let focus = result.focusManager
  let hover = result.hoverTracker
  onDispose = proc(gone: Widget) =
    if focus.focusedWidget != nil and focus.focusedWidget.isWithin(gone):
      focus.clearFocus()
    if hover.hovered != nil and hover.hovered.isWithin(gone):
      discard hover.setHover(nil)
    if pointerCapture() != nil and pointerCapture().isWithin(gone):
      releasePointer()
    if pointerWidget() != nil and pointerWidget().isWithin(gone):
      setPointer(nil, pointerPos())
  # ThemeManager already set "light" as default and updated the global.

proc setStore*(app: App, store: Store) =
  ## Set the application store
  app.store = store

proc rootRect(app: App): Rect =
  ## Where the root widget is laid out: the window, or -- for a shaped window
  ## whose shape stops short of the window's corner -- the shape's box.
  when defined(ruiShaped):
    if app.shapeContent.isSome: return app.shapeContent.get
  Rect(x: 0, y: 0, width: app.window.width.float32, height: app.window.height.float32)

proc resetUi*() =
  ## Every piece of the UI's global state back to a fresh start (rui_core
  ## ui_state.nim lists it): no popups, overlays, timers, pointer captures or
  ## frozen pages, the default theme. For an app replacing its whole UI, and
  ## for tests.
  resetUiState()
  resetDrawingState()

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
  root.bounds = app.rootRect
  root.layoutDirty = true
  root.isDirty = true
  app.tree.anyDirty = true
  app.tree.isDirty = true

proc injectKey(app: App, keyName: string): bool =
  ## Synthesise a key press at whatever currently has focus. **Test-only** --
  ## reached from `enableScripting` under -d:ruiTestKeys and nowhere else.
  ## Takes a chord as well as a bare key: "Tab", "Shift+Tab", "Ctrl+Z".
  let chord = parseKeyChord(keyName)
  if chord.isNone:
    return false
  let event = GuiEvent(kind: evKeyDown, key: chord.get.key,
                       mods: chord.get.mods, timestamp: getMonoTime())
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
  animationsEnabled = false   # a script reads settled values, not mid-fade ones
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
    app.probe = newVisualProbe(scriptDir / "shots")
    app.probe.rectOf = proc(selector: string): Option[tuple[x, y, w, h: int]] =
      if selector == "*":
        return some((0, 0, getScreenWidth().int, getScreenHeight().int))
      let widget = app.tree.findWidget(selector)
      if widget.isNone: return none(tuple[x, y, w, h: int])
      let r = widget.get().visibleRect
      some((r.x.int, r.y.int, r.width.int, r.height.int))
    app.probe.resizeTo = proc(width, height: int) =
      setWindowSize(width.int32, height.int32)
      if app.tree.root != nil:
        app.tree.root.layoutDirty = true
        app.tree.root.isDirty = true
    app.scriptManager.onVisual = proc(selector, what: string): VisualReply =
      app.probe.answer(selector, what)

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

proc watchTheme*(app: App, path: string) =
  ## Use the theme in `path` and keep it live: save the file (or a theme file it
  ## extends, beside it) and the running app restyles itself within a second. A
  ## file with a mistake is reported on stderr and leaves the last good theme in
  ## place. For authors; ship `app.setTheme("...")` as usual.
  let theme = app.themeManager.loadFromFile(path)
  app.setTheme(theme)
  app.themeWatch = watchTheme(path)
  app.themeWatchChecked = getMonoTime()

proc pollThemeWatch*(app: App, now = getMonoTime()) =
  ## The hot-reload check, at most twice a second.
  if app.themeWatch == nil or app.tree.root == nil: return
  if now - app.themeWatchChecked < initDuration(milliseconds = 500): return
  app.themeWatchChecked = now
  let before = app.themeWatch.lastError
  let fresh = app.themeManager.reloaded(app.themeWatch)
  if fresh.isSome:
    app.setTheme(fresh.get)
  elif app.themeWatch.lastError.len > 0 and app.themeWatch.lastError != before:
    stderr.writeLine "rui: theme reload failed, keeping the last good one: " &
                     app.themeWatch.lastError

proc useThemes*(app: App, light, dark: string) =
  ## Declare the application's light and dark themes (by registered name) and
  ## start on the one the user wants: their `colorScheme` preference, or the
  ## operating system's when that is `system`. The author chooses the looks;
  ## the user chooses which of them to see.
  ##
  ##   app.useThemes(light = "daylight", dark = "midnight")
  let scheme = effectiveScheme(prefs.colorScheme,
    if prefs.colorScheme == schemeSystem: detectSystemScheme() else: schemeLight)
  app.setTheme(if scheme == schemeDark: dark else: light)

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

when defined(ruiShaped):
  proc settleContent(app: App, rects: seq[ShapeRect], contentArea: Option[Rect]) =
    ## Decide where the widgets go (rui_shaped's contentArea, or the app's own
    ## rect) and move the root there if it is already set.
    let r = if contentArea.isSome: contentArea.get
            else:
              let c = rects.boundingBox.contentArea(app.window.width, app.window.height)
              Rect(x: c.x.float32, y: c.y.float32, width: c.w.float32, height: c.h.float32)
    app.shapeContent = some(r)
    if app.tree.root != nil:
      app.tree.root.bounds = r
      app.tree.root.layoutDirty = true
      app.tree.root.isDirty = true

  proc setWindowShape*(app: App, skinPng: string, softEdges = true, clickThrough = true,
                       fitWindow = true, contentArea = none(Rect)) =
    ## Make the window the shape of `skinPng`: its alpha is the outline, its
    ## pixels are drawn behind the widgets. Call before `run`. The method
    ## (see-through, OS-clipped, or a plain rectangle where neither works) is
    ## chosen when the window opens, from what the machine can do; the window
    ## is undecorated and a fixed size, and dragging its background moves it.
    ## `fitWindow`: the window takes the skin's size, whatever newApp was given.
    ## The widgets are laid out in the window when the shape reaches its
    ## bottom-right corner, else in the shape's box (see contentArea);
    ## `contentArea` sets that rect (window coordinates) instead -- a round
    ## skin's safe area, say.
    app.shapeWanted = true
    app.shapeSkinPath = skinPng
    app.shapeSoftEdges = softEdges
    app.shapeClickThrough = clickThrough
    app.window.resizable = false
    # The skin's size and outline are known now, on the CPU, with no window:
    # layout (and a headless layout dump) sees the same content rect as the app.
    let skin = loadImage(skinPng)
    if skin.width <= 0: return
    if fitWindow:
      app.window.width = skin.width
      app.window.height = skin.height
    let colors = loadImageColors(skin)
    var m = AlphaMask(width: skin.width, height: skin.height,
                      alpha: newSeq[uint8](skin.width * skin.height))
    for i in 0 ..< m.alpha.len: m.alpha[i] = colors[i].a
    app.settleContent(m.toRects, contentArea)
    let mask = m
    let traced = traceOutlines(mask.width, mask.height,
                               proc(x, y: int): float32 = mask.at(x, y).float32 / 255)
    if traced.len > 0: app.shapeOutline = some(traced[0])

  proc setWindowShape*(app: App, inside: proc(x, y: float32): float32 {.closure.},
                       softEdges = true, clickThrough = true, contentArea = none(Rect)) =
    ## A procedural shape: `inside` gives 0 outside .. 1 inside for a point of
    ## the window. The app draws the look itself (a background widget, a
    ## shader); outside the shape stays see-through or clipped.
    app.shapeWanted = true
    app.shapeFunc = inside
    app.shapeSoftEdges = softEdges
    app.shapeClickThrough = clickThrough
    app.window.resizable = false
    app.settleContent(rectsFromFunc(app.window.width, app.window.height, inside, step = 2),
                      contentArea)
    let traced = traceOutlines(app.window.width, app.window.height,
                               proc(x, y: int): float32 = inside(x.float32 + 0.5, y.float32 + 0.5))
    if traced.len > 0: app.shapeOutline = some(traced[0])

  proc reshapeWindow*(app: App, inside: proc(x, y: float32): float32 {.closure.}, step = 3) =
    ## Change a procedural shape while running (an animated outline). The
    ## click region is sampled every `step` pixels; an unchanged shape is not
    ## resent.
    app.shapeFunc = inside
    app.shaped.setShape(app.window.width, app.window.height, inside, step)

  proc contentBounds*(app: App): Rect =
    ## Where the widgets are laid out, in window coordinates: the whole
    ## window, the shape's box, or the app's contentArea.
    app.rootRect

  proc shapeBounds*(app: App): Rect =
    ## Where the visible shape is on the screen: its bounding box, which in a
    ## skin with a transparent margin is not the window's rectangle. For
    ## snapping, docking or keeping it on screen.
    let box = app.shaped.shapeBox
    let p = getWindowPosition()
    Rect(x: p.x + box.x.float32, y: p.y + box.y.float32,
         width: box.w.float32, height: box.h.float32)

  proc placeShape*(app: App, x, y: int) =
    ## Put the visible shape's top-left corner at (x, y) on the screen -- not
    ## the window's, which sits a skin's margin further out. Before `run` it
    ## takes effect when the window opens.
    if not isWindowReady():
      app.pendingShapePos = some((x, y))
      return
    let box = app.shaped.shapeBox
    setWindowPosition(int32(x - box.x), int32(y - box.y))

  proc applyWindowShape(app: App) =
    ## After the window opens: learn what it got, give it its shape, load the skin.
    app.shaped.confirm()
    if app.shapeSkinPath.len > 0:
      var img = loadImage(app.shapeSkinPath)
      app.shaped.setShape(img)
      # The compositor blends premultiplied colour: a straight-alpha skin would
      # leave a light fringe along its soft edges.
      imageAlphaPremultiply(img)
      app.shapeSkin = some(loadTextureFromImage(img))
    elif app.shapeFunc != nil:
      app.shaped.setShape(app.window.width, app.window.height, app.shapeFunc, step = 1)
    echo "  Window shape: ", app.shaped.describe()
    if app.pendingShapePos.isSome:
      let (x, y) = app.pendingShapePos.get
      app.pendingShapePos = none((int, int))
      app.placeShape(x, y)

  proc dragByBackground(app: App) =
    ## A press on the background -- nothing that takes a click itself -- and a
    ## drag move the window: it has no title bar to be moved by.
    let m = getMousePosition()
    var allow = false
    if isMouseButtonPressed(MouseButton.Left):
      var hit = overlayAt(m.x, m.y)
      if hit == nil: hit = app.hitTestSystem.getWidgetAt(m.x, m.y)
      allow = hit == nil or focusTargetFor(hit) == nil
    app.shapeDrag.update(app.shaped, allowStart = allow)
else:
  template setWindowShape*(app: App, args: varargs[untyped]) =
    {.error: "setWindowShape needs the rui_shaped package: build with -d:ruiShaped".}
  template reshapeWindow*(app: App, args: varargs[untyped]) =
    {.error: "reshapeWindow needs the rui_shaped package: build with -d:ruiShaped".}
  template placeShape*(app: App, args: varargs[untyped]) =
    {.error: "placeShape needs the rui_shaped package: build with -d:ruiShaped".}
  template shapeBounds*(app: App): untyped =
    {.error: "shapeBounds needs the rui_shaped package: build with -d:ruiShaped".}

proc placeWindow*(app: App, x, y: int) =
  ## Put the window's top-left corner at (x, y) on the screen. Before `run`
  ## it takes effect when the window opens. (For a shaped window, placeShape
  ## places the visible shape instead.)
  if isWindowReady(): setWindowPosition(x.int32, y.int32)
  else: app.pendingWindowPos = some((x, y))

proc setWindowResizable*(app: App, resizable: bool) =
  ## Enable or disable window resizing
  if resizable:
    setWindowState(flags(WindowResizable))
  else:
    clearWindowState(flags(WindowResizable))
  app.window.resizable = resizable
