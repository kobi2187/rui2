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
import visual
export visual
import preferences_file
export preferences_file
import system_scheme
export system_scheme
from rui_widgets import HelpOverlay, newHelpOverlay, hints, `hints=`, FocusRing, newFocusRing,
  Toast, newToast, MenuBar, findMenuBar, openFromKeyboard,
  Effect, Decoration, syncDecorations, adornPath
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
import std/[monotimes, times, os, options]
when defined(ruiShaped):
  # Non-rectangular windows (packages/rui_shaped), only when asked for: an app
  # built without -d:ruiShaped carries none of it.
  import rui_shaped
  export rui_shaped

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
    probe*: VisualProbe           # screen read-back and frame timings (-d:ruiInspect)
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

    themeWatch: ThemeWatch           # the theme file being hot-reloaded, if any
    themeWatchChecked: MonoTime

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
    pendingWindowPos: Option[(int, int)]   # placeWindow before the window exists
    when defined(ruiShaped):
      shaped*: ShapedWindow          # the method this machine got (-d:ruiShaped)
      shapeWanted: bool
      shapeSoftEdges, shapeClickThrough: bool
      shapeSkinPath: string          # a PNG: its alpha is the shape, its pixels the look
      shapeSkin: Option[Texture2D]   # none before closeWindow: a texture outliving the GL context crashes
      shapeFunc: proc(x, y: float32): float32 {.closure.}
      shapeDrag: DragMove
      pendingShapePos: Option[(int, int)]  # placeShape before the shape is known
      shapeContent: Option[Rect]       # where the root is laid out (contentArea)
      shapeOutline: Option[Path]       # the shape's edge, traced (window coordinates)

    # Idling
    idleWhenClean*: bool
      ## Skip drawing and presenting frames in which nothing was painted, and
      ## sleep instead. On by default; off gives the old always-present loop.
    idleRefresh*: Duration
      ## Present at least this often even when idle; 0 (the default) never.
      ## A window uncovered on a compositor-less desktop is redrawn when the OS
      ## says so (event_source `windowExposed`), so an idle window costs nothing.
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

# The App's work, one file per job, included in this order (one module, so
# nothing outside sees the split):
include app_setup        # creating the App, its theme, accessors, text cache
include app_events       # input: collecting, routing, help, toasts, focus rings
include app_layout       # the layout pass, hit-test rebuild, script registry
include app_compositing  # painting textures, compositing root, overlays, glass
include app_loop         # scripting, the main loop and idling, stats
