## RUI Application Core
##
## Main application loop with integrated event processing, layout, and rendering

import rui_core
import rui_events
import rui_drawing
import rui_scripting
import rui_hittest
import event_source
import idle_wait
import event_routing
import inspect
import preferences_file
export preferences_file
import system_scheme
export system_scheme
from rui_widgets import HelpOverlay, newHelpOverlay, FocusRing, newFocusRing,
  Toast, newToast
export event_source, event_routing, inspect
export rui_core
export event_manager   # Export for users to access eventManager
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

    # Idling
    idleWhenClean*: bool
      ## Skip drawing and presenting frames in which nothing was painted, and
      ## sleep instead. On by default; off gives the old always-present loop.
    idleRefresh*: Duration
      ## Present at least this often even when idle, so a window uncovered by
      ## another one does not show garbage on a compositor-less desktop.
    lastPresent: MonoTime
    idleRecentlyPolled: bool      # see idleUntilNextFrame
    indicatorShown: bool
    cursorShown: CursorShape
    overlaysSeen: int

    # Toasts: transient messages stacked at the bottom of the window
    toasts: seq[tuple[widget: Toast, until: MonoTime]]

    # Keyboard help (F1 or ?)
    helpEntries*: seq[HelpEntry]
      ## Shortcuts the application adds to the overlay (`app.addHelp`).
    appShortcuts: seq[tuple[chord: Chord, text: string, action: proc() {.closure.}]]
      ## Shortcuts bound to the application itself, not to a widget.
    helpOverlay*: HelpOverlay
    helpClosedAt: MonoTime

    # Keyboard navigation highlight
    keyboardMode*: bool
      ## The user is driving by keyboard: show where focus is. Set by any key
      ## press, cleared by a mouse press -- the "focus-visible" rule, so clicking
      ## a button does not draw a navigation ring round it.
    widgetRing*, groupRing*: FocusRing

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
    idleRefresh: initDuration(seconds = 1),

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

proc ringRect(target: Rect, gap: float32): Rect =
  Rect(x: target.x - gap, y: target.y - gap,
       width: target.width + gap * 2, height: target.height + gap * 2)

proc placeRing(ring: var FocusRing, group: bool, target: Widget, gap: float32,
               show: bool) =
  ## Show `ring` round `target`, or take it away. Creating it lazily keeps an
  ## app that is only ever driven by the mouse from paying for either.
  if not show or target == nil or not target.visible or target.bounds.width <= 0:
    if ring != nil and ring in overlays():
      hideOverlay(ring)
    return
  if ring == nil:
    ring = newFocusRing(group = group)
  let want = ringRect(target.bounds, gap)
  if ring.bounds != want:
    ring.bounds = want
    ring.isDirty = true
  if ring notin overlays():
    showOverlay(ring)

proc syncFocusRings*(app: App) =
  ## Put the rings where focus is: firm round the focused widget, softer round
  ## the container it is moving about in. Only while the keyboard is driving;
  ## the widget's own focus look is unaffected.
  if app.helpVisible:
    # Widgets move and appear while help is up (and before the first layout):
    # keep the badges on what is really there.
    let hints = collectHints(app.tree.root)
    if hints != app.helpOverlay.hints:
      app.helpOverlay.hints = hints
      app.helpOverlay.isDirty = true
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

proc pressFocused*(app: App, event: GuiEvent): bool =
  ## Space or Enter on a focused button-like control presses it, as a click
  ## would. Only the controls where a click means "do your one thing" -- not,
  ## say, a Slider, where a click at the middle would jump the value.
  if event.kind != evKeyDown or not (event.key in {KeyboardKey.Space, KeyboardKey.Enter}):
    return false
  let focused = app.focusManager.focusedWidget
  if focused == nil or focused.takesText or not focused.enabled:
    return false
  case focused.getTypeName()
  of "Button", "Checkbox", "RadioButton", "Hyperlink", "IconButton", "ToolButton":
    focused.activate()
    app.tree.anyDirty = true
    true
  else:
    false

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
  case event.kind
  of evWindowResize:
    app.handleWindowResize(event)

  of evMouseDown, evMouseUp, evMouseMove, evMouseWheel, evFileDrop:
    if app.router.routePointer(event):
      app.tree.anyDirty = true

  of evKeyDown, evChar:
    if not app.router.routeKeyboard(app.tree.root, event):
      if not app.pressFocused(event):
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
  for overlay in overlays():
    overlay.layoutPass()

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

proc updateLayoutAndRender(app: App): bool =
  ## Lay out, then paint whatever is dirty into the widget textures. Returns
  ## whether anything was painted -- which is what decides if the frame needs
  ## presenting at all.
  if app.tree.root == nil:
    return false
  app.refreshLayout()
  app.syncFocusRings()
  # What the window shows: anything wholly outside it is not painted until it
  # scrolls into view.
  renderView = some(Rect(x: 0, y: 0, width: getScreenWidth().float32,
                         height: getScreenHeight().float32))
  if app.tree.root.isDirty or app.tree.root.anyChildDirty():
    app.tree.root.renderPass()
    result = true
  for overlay in overlays():
    if overlay.isDirty or overlay.anyChildDirty():
      overlay.renderPass()
      result = true
  # Showing or hiding an overlay repaints no texture, but the screen changes.
  if overlayVersion() != app.overlaysSeen:
    app.overlaysSeen = overlayVersion()
    result = true
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
  ## Widget textures hold premultiplied colour (see main_loop), so they reach
  ## the screen through the premultiplied blend too.
  compositingTextures:
    if app.tree.root != nil and app.tree.root.cachedTexture.isSome:
      drawRenderTexture(app.tree.root.cachedTexture.get(),
                        app.tree.root.bounds.x, app.tree.root.bounds.y)
    # Then the overlay layer, in the order shown, above the whole tree.
    for overlay in overlays():
      if overlay.visible and overlay.cachedTexture.isSome:
        drawRenderTexture(overlay.cachedTexture.get(),
                          overlay.bounds.x, overlay.bounds.y)

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

proc openWindow(app: App) =
  initWindow(app.window.width.int32, app.window.height.int32, app.window.title)
  setTargetFPS(app.window.fps.int32)
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

proc step*(app: App): bool {.discardable.} =
  ## One frame of the pipeline, without the window or the loop around it.
  ## Needs a GL context, because it paints. Returns whether anything was
  ## painted.
  app.pumpEvents()
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
  let indicator = app.beingScripted
  if indicator != app.indicatorShown:
    app.indicatorShown = indicator
    return true
  now - app.lastPresent >= app.idleRefresh

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
    # Scripting reads command files once per frame, so it keeps the frame period.
    let cap = if app.scriptManager != nil:
                some(initDuration(nanoseconds = 1_000_000_000 div max(1, app.window.fps)))
              else: none(Duration)
    blockForEvents(idleWaitFor(now, nextRepaint(), app.lastPresent + app.idleRefresh, cap))
  else:
    app.idleRecentlyPolled = true
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
  ## `RUI_LAYOUT_DUMP=<file>` instead lays the tree out once without a window,
  ## writes the geometry of every widget to the file and returns: the snapshot
  ## that `tools/layout_snapshot.sh` diffs to catch layout drift.
  let dump = getEnv("RUI_LAYOUT_DUMP")
  if dump.len > 0:
    app.stepHeadless()
    writeFile(dump, inspectTree(app.tree.root))
    return
  app.openWindow()
  defer: closeWindow()
  app.announce()

  var framesRun = 0
  while not windowShouldClose() and not app.shouldClose:
    if maxFrames > 0 and framesRun >= maxFrames:
      break
    inc framesRun

    let frameStart = getMonoTime()
    let painted = app.step()
    let stepped = getMonoTime()
    app.applyCursor()
    if app.shouldPresent(painted, frameStart):
      app.renderFrame()       # 6. Composite to screen
      if profileFrames:
        stderr.writeLine "frame: step " & $((stepped - frameStart).inMicroseconds) &
          "us, present " & $((getMonoTime() - stepped).inMicroseconds) &
          "us, painted " & $painted
      app.lastPresent = frameStart
      app.countFrame()
      app.idleRecentlyPolled = false
    else:
      app.idleUntilNextFrame(frameStart)
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
