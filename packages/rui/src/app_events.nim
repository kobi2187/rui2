## Part of app.nim (included, not imported): Input: collecting events, routing them, the help overlay, toasts and the focus rings.

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
    if event.kind in {evKeyDown, evKeyUp, evChar, evMouseDown, evMouseUp, evMouseMove,
                      evMouseWheel}:
      noteInput()            # someone is here: decorative motion that rested wakes
    when perfOn:
      if event.kind in {evKeyDown, evChar, evMouseDown, evMouseUp, evMouseMove,
                        evMouseWheel}:
        perfInput(event.timestamp)
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

# ----------------------------------------------------------------------------
# The keyboard help overlay
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Toasts
# ----------------------------------------------------------------------------

const ToastGap = 8.0'f32
const ToastMargin = 24.0'f32

proc stackToasts(app: App) =
  ## Bottom-centre, newest lowest, each above the one before it.
  var y = app.window.height.float32 - ToastMargin
  for i in countdown(app.toasts.high, 0):
    let t = app.toasts[i].widget
    y -= t.bounds.height
    t.bounds.x = (app.window.width.float32 - t.bounds.width) / 2
    t.bounds.y = y
    t.isDirty = true
    y -= ToastGap

proc toast*(app: App, text: string, intent = ThemeIntent.Default, seconds = 3.0) =
  ## Show `text` over the window for `seconds`, then take it away:
  ##   app.toast("Saved")
  ##   app.toast("Could not connect", intent = ThemeIntent.Danger, seconds = 6)
  let t = newToast(text = text, intent = intent)
  t.layout()
  app.toasts.add (t, getMonoTime() + initDuration(milliseconds = int(seconds * 1000)))
  showOverlay(t)
  app.stackToasts()
  t.repaintAfter(seconds)         # wakes an idle window to remove it
  app.tree.anyDirty = true

proc pruneToasts*(app: App, now = getMonoTime()) =
  ## Remove the toasts whose time is up and close the gaps they leave.
  var kept: seq[tuple[widget: Toast, until: MonoTime]]
  var removed = false
  for entry in app.toasts:
    if entry.until <= now:
      hideOverlay(entry.widget)
      removed = true
    else:
      kept.add entry
  if removed:
    app.toasts = kept
    app.stackToasts()
    app.tree.anyDirty = true

proc addHelp*(app: App, keys, text: string) =
  ## List one of the application's own shortcuts in the help overlay:
  ##   app.addHelp("Ctrl+S", "Save")
  app.helpEntries.add (keys, text)

proc bindShortcut*(app: App, keys: string, text: string,
                   action: proc() {.closure.}) =
  ## A shortcut for the whole application, with no widget behind it: the key
  ## runs `action`, and the help overlay lists it among the notes on its second
  ## row. The chord is checked here, so a typo fails at startup.
  ##
  ##   app.bindShortcut("Ctrl+F", "find", proc() = openFindBar())
  app.appShortcuts.add (chord(keys), text, action)

proc helpVisible*(app: App): bool =
  app.helpOverlay != nil and app.helpOverlay in overlays()

proc showHelp*(app: App) =
  ## Shade the window and list the keys in force. Rebuilt each time, so it
  ## reflects the user's current bindings.
  if app.helpVisible: return
  var notes = app.helpEntries
  for s in app.appShortcuts:
    notes.add (s.chord.display, s.text)
  app.helpOverlay = newHelpOverlay(items = navigationItems(prefs.keys),
                                   notes = notes,
                                   hints = collectHints(app.tree.root))
  app.helpOverlay.bounds = Rect(x: 0, y: 0, width: app.window.width.float32,
                                height: app.window.height.float32)
  showOverlay(app.helpOverlay)
  app.tree.anyDirty = true

proc hideHelp*(app: App) =
  if app.helpVisible:
    hideOverlay(app.helpOverlay)
    app.helpClosedAt = getMonoTime()
    app.tree.anyDirty = true

proc helpKeyPressed(app: App, event: GuiEvent): bool =
  ## Whether this key press asks for help. A key that is really typing (the "?"
  ## chord) is left to a text field that has focus.
  if event.kind != evKeyDown or not prefs.keys.matches(showHelp, event):
    return false
  let focused = app.focusManager.focusedWidget
  not (focused != nil and focused.takesText and (event.key, event.mods).isTyping)

# ----------------------------------------------------------------------------
# The focus rings: where the keyboard is, at both levels
# ----------------------------------------------------------------------------

const RingGap = 3.0'f32
const GroupGap = 6.0'f32

proc placeRing(ring: var FocusRing, group: bool, target: Widget, gap: float32,
               show: bool) =
  ## Show `ring` round `target`, or take it away. Creating it lazily keeps an
  ## app that is only ever driven by the mouse from paying for either.
  if ring == nil:
    if not show or not target.onPage: return
    ring = newFocusRing(group = group)
  ring.followWidget(target, gap, show)

proc windowOutline*(app: App): Path =
  ## The window's edge, in window coordinates, clockwise from its top-left:
  ## a shaped window's traced outline (-d:ruiShaped), else its rectangle.
  when defined(ruiShaped):
    if app.shapeOutline.isSome: return app.shapeOutline.get
  rectPath(Rect(x: 0, y: 0, width: app.window.width.float32,
                height: app.window.height.float32))

proc adornWindow*(app: App, effect: Effect, path = none(Path), inset = 0.0'f32): Decoration {.discardable.} =
  ## Draw `effect` round the window: along `path` if given (your own points,
  ## window coordinates), else the window's outline -- a shaped window's
  ## traced edge. `inset` keeps it inside, for a hard-edged (OS-clipped) shape.
  adornPath(cast[pointer](app), path.get(app.windowOutline), effect, inset)

proc syncFocusRings*(app: App) =
  ## Put the rings where focus is: firm round the focused widget, softer round
  ## the container it is moving about in. Only while the keyboard is driving;
  ## the widget's own focus look is unaffected.
  if app.helpVisible:
    # Widgets move and appear while help is up (and before the first layout):
    # keep the badges on what is really there.
    let marks = collectHints(app.tree.root)
    app.helpOverlay.hints = marks        # a prop: setting it repaints when it changed
  let focused = app.focusManager.focusedWidget
  let group = app.focusManager.activeGroup
  let navigating = app.keyboardMode and not app.helpVisible
  placeRing(app.widgetRing, false, focused, RingGap, navigating)
  placeRing(app.groupRing, true, group, GroupGap,
            navigating and group != nil and group != focused)

proc activate*(widget: Widget) =
  ## Press a widget as if it had been clicked: a press and a release at its
  ## middle, offered to it and its ancestors like any pointer event.
  let at = Point(x: widget.bounds.x + widget.bounds.width / 2,
                 y: widget.bounds.y + widget.bounds.height / 2)
  discard widget.dispatchBubbling(GuiEvent(kind: evMouseDown, mousePos: at))
  discard widget.dispatchBubbling(GuiEvent(kind: evMouseUp, mousePos: at))
  widget.markDirtyToRoot()

proc handleShortcut*(app: App, event: GuiEvent): bool =
  ## A key press that is some widget's `.shortcut`: activate that widget. A
  ## shortcut that is really typing is left to a text field with focus.
  if event.kind != evKeyDown or app.helpVisible:
    return false
  let focused = app.focusManager.focusedWidget
  if focused != nil and focused.takesText and (event.key, event.mods).isTyping:
    return false
  let target = findShortcut(app.tree.root, event.key, event.mods)
  if target != nil:
    target.activate()
    app.tree.anyDirty = true
    return true
  for s in app.appShortcuts:
    if s.chord.key == event.key and s.chord.mods == event.mods:
      if s.action != nil:
        s.action()
      app.tree.anyDirty = true
      return true
  false

proc handleHelp*(app: App, event: GuiEvent): bool =
  ## Help takes over the keyboard and pointer while it is up: any key or click
  ## closes it, and the character that key would have typed is swallowed too.
  if app.helpVisible:
    case event.kind
    of evKeyDown, evMouseDown:
      app.hideHelp()
      return true
    of evChar, evMouseUp, evMouseMove, evMouseWheel:
      return true
    else:
      return false
  if event.kind == evChar and getMonoTime() - app.helpClosedAt < initDuration(milliseconds = 60):
    return true                    # the "?" that just closed it, arriving as text
  if app.helpKeyPressed(event):
    app.showHelp()
    return true
  false

proc handleWindowResize(app: App, event: GuiEvent) =
  app.window.width = int(event.windowSize.width)
  app.window.height = int(event.windowSize.height)
  if app.helpVisible:
    app.helpOverlay.bounds = Rect(x: 0, y: 0, width: event.windowSize.width,
                                  height: event.windowSize.height)
    app.helpOverlay.isDirty = true
  discard resizeRoot(app.tree.root, event.windowSize)
  app.tree.anyDirty = true
  traceEvent "[Event] Window resized to ", event.windowSize.width, "x",
             event.windowSize.height

proc handleMenuKeys(app: App, event: GuiEvent): bool =
  ## F10 opens the window's menu bar at its first menu; Alt+letter at the
  ## menu whose title starts with that letter -- the desktop convention, when
  ## nothing focused wanted the key first.
  if event.kind != evKeyDown or app.tree.root == nil:
    return false
  let isF10 = event.key == KeyboardKey.F10 and event.mods == {}
  let k = ord(event.key)
  let altLetter = event.mods == {kmAlt} and k >= ord('A') and k <= ord('Z')
  if not (isF10 or altLetter):
    return false
  let bar = findMenuBar(app.tree.root)
  if bar == nil:
    return false
  result = bar.openFromKeyboard(if altLetter: chr(k) else: '\0')
  if result:
    app.tree.anyDirty = true

const SlowHandler = initDuration(milliseconds = 200)
var slowWarned: seq[pointer]

proc noteSlowHandler(app: App, event: GuiEvent, took: Duration) =
  ## Debug builds: an event whose handling held the UI thread so long that the
  ## window visibly froze is reported once per widget, with the cure. (Work
  ## that blocks belongs in runInBackground.)
  if took < SlowHandler: return
  let w = if event.kind in {evKeyDown, evChar}: app.focusManager.focusedWidget
          else: pointerWidget()
  let key = cast[pointer](w)
  if key in slowWarned: return
  slowWarned.add key
  let who = if w == nil: "the app"
            else: w.getTypeName & (if w.stringId.len > 0: " \"" & w.stringId & "\"" else: "")
  stderr.writeLine "[rui] handling a ", event.kind, " on ", who, " held the UI thread for ",
    took.inMilliseconds, " ms: the window could not redraw or take input meanwhile. ",
    "Move slow work into runInBackground(work, done)."

proc handleEvent(app: App, event: GuiEvent) =
  ## Route one event. The work is in event_routing.nim; this is the three-way
  ## split between window, pointer and keyboard, and the dirty bookkeeping.
  if app.handleHelp(event):
    return
  if app.handleShortcut(event):
    return
  if event.kind == evKeyDown:
    app.keyboardMode = true
  elif event.kind == evMouseDown:
    app.keyboardMode = false
  keyboardDriving = app.keyboardMode
  case event.kind
  of evWindowResize:
    app.handleWindowResize(event)

  of evMouseDown, evMouseUp, evMouseMove, evMouseWheel, evFileDrop:
    if app.router.routePointer(event):
      app.tree.anyDirty = true

  of evKeyDown, evChar:
    if not app.router.routeKeyboard(app.tree.root, event):
      if not app.handleMenuKeys(event):
        traceEvent "[Event] Keyboard event not handled: ", event.kind

  else:
    discard
