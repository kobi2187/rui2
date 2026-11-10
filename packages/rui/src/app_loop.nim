## Part of app.nim (included, not imported): Scripting support, the main loop (and how it idles), and stats.

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

proc systemClipboard(): Clipboard =
  ## The OS clipboard, through raylib. Only valid once a window exists.
  Clipboard(get: proc(): string = raylib.getClipboardText(),
            put: proc(text: string) = raylib.setClipboardText(text))

proc raylibCursor(shape: CursorShape): MouseCursor =
  case shape
  of csDefault, csArrow: MouseCursor.Arrow
  of csText: MouseCursor.Ibeam
  of csPointer: MouseCursor.PointingHand
  of csCrosshair: MouseCursor.Crosshair
  of csResizeH: MouseCursor.ResizeEw
  of csResizeV: MouseCursor.ResizeNs
  of csMove: MouseCursor.ResizeAll
  of csNotAllowed: MouseCursor.NotAllowed

proc applyCursor(app: App) =
  ## Show the hovered widget's pointer shape. Only calls into the window when
  ## the shape changes, which on most frames it does not.
  let hovered = app.hoverTracker.hovered
  let shape = if hovered == nil: csArrow else: hovered.effectiveCursor
  if shape != app.cursorShown:
    app.cursorShown = shape
    setMouseCursor(raylibCursor(shape))

proc quietRaylibLog() =
  ## raylib prints its start-up report (display, GL, shaders, VRAM...) at INFO.
  ## That is noise in a release build, so only warnings and errors get through;
  ## debug builds keep it. RUI_LOG=trace|debug|info|warning|error|none overrides.
  let level =
    case getEnv("RUI_LOG").toLowerAscii
    of "trace": TraceLogLevel.Trace
    of "debug": TraceLogLevel.Debug
    of "info": TraceLogLevel.Info
    of "warning": TraceLogLevel.Warning
    of "error": TraceLogLevel.Error
    of "none": TraceLogLevel.None
    else:
      when defined(release) or defined(danger): TraceLogLevel.Warning
      else: TraceLogLevel.Info
  setTraceLogLevel(level)

proc openWindow(app: App) =
  quietRaylibLog()
  when defined(ruiShaped):
    if app.shapeWanted:
      # Before the window exists: the method decides its flags (undecorated,
      # and a see-through framebuffer where a compositor can show one).
      app.shaped = prepareShapedWindow(app.shapeSoftEdges, app.shapeClickThrough,
                                       backdrop = currentTheme.canvasColor())
  initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
  if app.pendingWindowPos.isSome:
    let (x, y) = app.pendingWindowPos.get
    setWindowPosition(x.int32, y.int32)
  when defined(ruiShaped):
    if app.shapeWanted: app.applyWindowShape()
  setTargetFPS(app.window.fps.int32)
  # raylib closes the window on Escape by default; here Escape belongs to the
  # widgets -- it cancels a dialog, closes a menu -- and quitting is the app's call.
  setExitKey(KeyboardKey.Null)
  useClipboard(systemClipboard())
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

  perfTime(phEvents):
    # 1. Collect events from this frame's source
    app.collectEvents()

    # 2. Process event patterns (coalescing)
    app.eventManager.update()

    # 3. Process events with time budget
    discard app.eventManager.processEvents(
      app.eventManager.currentBudget,
      proc(event: GuiEvent) =
        when defined(release):
          app.handleEvent(event)
        else:
          let started = getMonoTime()
          app.handleEvent(event)
          app.noteSlowHandler(event, getMonoTime() - started))

  # 4. Poll script commands
  perfTime(phScript):
    app.pollScriptCommands()

  # 5. A popup that opened this frame (a context menu) may want the keyboard.
  let wantsFocus = takeFocusRequest()
  if wantsFocus != nil:
    app.focusManager.setFocus(wantsFocus)

proc stepHeadless*(app: App) =
  ## A frame with the render pass left out: input, routing, layout, hit-test.
  ##
  ## This is the whole pipeline apart from the one part that needs a window, and
  ## it is what makes the frame testable at all -- before the event-source seam,
  ## `run` read raylib directly and there was nothing to call.
  app.pollThemeWatch()
  app.pumpEvents()
  if runPollers():                  # background work and data sources deliver here
    app.tree.anyDirty = true
  if fireDueRepaints():             # what asked to come back (a fade's next step), as `step`
    app.tree.anyDirty = true
  app.refreshLayout()

proc step*(app: App): bool {.discardable.} =
  ## One frame of the pipeline, without the window or the loop around it.
  ## Needs a GL context, because it paints. Returns whether anything was
  ## painted.
  perfTime(phPoll):
    app.pollThemeWatch()
  app.pumpEvents()
  perfTime(phPoll):
    if runPollers():                # a data source brought rows in from its worker
      app.tree.anyDirty = true
    if fireDueRepaints():
      app.tree.anyDirty = true
    app.pruneToasts()
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

proc shouldPresent(app: App, painted: bool, now: MonoTime): bool =
  ## Whether this frame has to reach the screen. Painting is the usual reason;
  ## the others are the scripting indicator appearing or going, and the idle
  ## refresh.
  if painted or not app.idleWhenClean:
    return true
  if app.probe != nil and app.probe.wantPresent:
    return true
  let indicator = app.beingScripted
  if indicator != app.indicatorShown:
    app.indicatorShown = indicator
    return true
  if windowExposed:                   # the OS lost the window's contents
    windowExposed = false
    return true
  app.idleRefresh > DurationZero and now - app.lastPresent >= app.idleRefresh

proc idleUntilNextFrame(app: App, frameStart: MonoTime) =
  ## An idle frame: no drawing and no buffer swap. endDrawing normally polls
  ## input and then waits out the frame, partly by busy-waiting, which is why
  ## an unchanged window used to cost a steady slice of a core.
  ##
  ## Idle frames alternate. The first polls (which also rotates raylib's
  ## pressed/released state, so a click is seen once) and lets the next step
  ## read what arrived. The second, finding nothing new, blocks until input, a
  ## repaint timer or the idle refresh; whatever wakes it is read by the step
  ## after, before the next poll rotates it away.
  if app.idleRecentlyPolled:
    app.idleRecentlyPolled = false
    let now = getMonoTime()
    # Scripting reads command files once per frame, and an `onFrame` hook asked
    # to run every frame: both keep the frame period. Otherwise the loop sleeps
    # until something happens, and an idle window costs nothing.
    let cap = if app.scriptManager != nil or app.onFrame != nil:
                some(initDuration(nanoseconds = 1_000_000_000 div max(1, app.window.fps)))
              else: none(Duration)
    perfTime(phIdle):
      let refresh = if app.idleRefresh > DurationZero: app.lastPresent + app.idleRefresh
                    else: now + initDuration(hours = 24)      # no periodic refresh
      blockForEvents(idleWaitFor(now, nextRepaint(), refresh, cap))
  else:
    app.idleRecentlyPolled = true
    perfTime(phIdle):
      pollInputEvents()

let profileFrames = getEnv("RUI_PROFILE").len > 0
  ## `RUI_PROFILE=1 ./app` prints one line per presented frame to stderr:
  ## how long the step (events, layout, painting widgets) and the present took,
  ## and how many events the frame handled. For finding where a lag lives.

proc run*(app: App, maxFrames: int = -1) =
  ## Run the main application loop.
  ##
  ## `maxFrames` > 0 stops after that many frames and closes the window. That
  ## is what automated tests and screenshot capture want; Stage B removed the
  ## old headless mode on purpose, and this is the graphics-only equivalent --
  ## a real window, really rendered, for a bounded number of frames.
  ##
  ## `RUI_FIT_CHECK=<file>` does the same and writes what does not fit the
  ## screen (fit_check.nim).
  ##
  ## `RUI_LAYOUT_DUMP=<file>` instead lays the tree out once without a window,
  ## writes the geometry of every widget to the file and returns: the snapshot
  ## that `tools/layout_snapshot.sh` diffs to catch layout drift.
  let dump = getEnv("RUI_LAYOUT_DUMP")
  if dump.len > 0:
    app.stepHeadless()
    writeFile(dump, inspectTree(app.tree.root))
    return
  # `RUI_FIT_CHECK=<file>`: the same headless layout, checked for what does not
  # fit the screen (fit_check.nim), as JSON. tools/fit_check.sh uses it with
  # RUI_WINDOW_SIZE to try an app on many phones.
  let fit = getEnv("RUI_FIT_CHECK")
  if fit.len > 0:
    app.stepHeadless()
    writeFile(fit, $fitReport(app.tree.root, app.rootRect))
    return
  app.openWindow()
  defer:
    # Textures are freed through the GL context, which closeWindow tears down:
    # released afterwards they crash (SIGSEGV in `=destroy`).
    if app.tree.root != nil: freeTextureTree(app.tree.root)
    for overlay in overlays(): freeTextureTree(overlay)
    thawAll()                         # a modal's frozen picture is a texture too
    stopBackground()                  # finish and deliver queued jobs, stop the thread
    clearTextCache()                  # glyph textures are global, freed the same way
    when defined(ruiShaped):
      app.shapeSkin = none(Texture2D)   # a GPU texture too: unloaded now, not after
    closeWindow()
  app.announce()

  var framesRun = 0
  while not windowShouldClose() and not app.shouldClose:
    if maxFrames > 0 and framesRun >= maxFrames:
      break
    inc framesRun

    let frameStart = getMonoTime()
    when defined(ruiShaped):
      if app.shapeWanted: app.dragByBackground()
    let painted = app.step()
    let stepped = getMonoTime()
    app.applyCursor()
    if app.shouldPresent(painted, frameStart):
      app.renderFrame()       # 6. Composite to screen
      if app.probe != nil:
        app.probe.notePresented((stepped - frameStart).inMicroseconds.int,
                                (getMonoTime() - stepped).inMicroseconds.int, painted)
      if profileFrames:
        stderr.writeLine "frame: step " & $((stepped - frameStart).inMicroseconds) &
          "us, present " & $((getMonoTime() - stepped).inMicroseconds) &
          "us, painted " & $painted
      app.lastPresent = frameStart
      app.countFrame()
      app.idleRecentlyPolled = false
      when perfOn: perfEndFrame(true)
    else:
      app.idleUntilNextFrame(frameStart)
      when perfOn: perfEndFrame(false)
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
