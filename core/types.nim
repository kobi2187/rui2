## Core type definitions for RUI
##
## This file contains the fundamental types used throughout the framework.

import std/[tables, sets, hashes, options, times, monotimes, json]
export sets, tables, options, json  # Export for use in other modules

when defined(useGraphics):
  import raylib
  export raylib.Color, raylib.KeyboardKey
else:
  # Stub types when graphics not available
  type
    Texture2D* = object
    Color* = object
    KeyboardKey* = object

# Size type - define locally for now
type Size* = object
  width*, height*: float32

# ============================================================================
# Basic Types
# ============================================================================

type
  WidgetId* = distinct int  # Internal numeric ID for fast lookups

  Rect* = object
    x*, y*: float32
    width*, height*: float32

  Point* = object
    x*, y*: float32

  EdgeInsets* = object
    top*, right*, bottom*, left*: float32

# Flutter-style EdgeInsets helpers
proc edgeInsets*(all: float32): EdgeInsets =
  ## EdgeInsets.all(value) - Same padding on all sides
  EdgeInsets(top: all, right: all, bottom: all, left: all)

proc edgeInsetsSymmetric*(horizontal, vertical: float32): EdgeInsets =
  ## EdgeInsets.symmetric(horizontal, vertical)
  EdgeInsets(
    top: vertical,
    bottom: vertical,
    left: horizontal,
    right: horizontal
  )

proc edgeInsetsOnly*(left = 0.0f32, top = 0.0f32, right = 0.0f32, bottom = 0.0f32): EdgeInsets =
  ## EdgeInsets.only(left, top, right, bottom)
  EdgeInsets(left: left, top: top, right: right, bottom: bottom)

proc edgeInsetsLTRB*(left, top, right, bottom: float32): EdgeInsets =
  ## EdgeInsets.fromLTRB(left, top, right, bottom)
  EdgeInsets(left: left, top: top, right: right, bottom: bottom)

# ============================================================================
# Layout Types
# ============================================================================

type
  Constraints* = object
    minWidth*, maxWidth*: float32
    minHeight*, maxHeight*: float32

# ============================================================================
# Scripting System Types
# ============================================================================

type
  ScriptAction* = enum
    ## Actions that can be performed via scripting
    saClick       # Click a button
    saSetText     # Set text in input
    saGetText     # Read text value
    saGetState    # Query widget state
    saEnable      # Enable/disable widget
    saFocus       # Set focus
    saSetValue    # Set generic value
    saQuery       # Query widget properties

# ============================================================================
# Widget Tree
# ============================================================================

type
  Widget* = ref object of RootObj
    # Identity
    id*: WidgetId              # Internal numeric ID
    stringId*: string          # User-facing ID for scripting (e.g., "login_button")

    # Geometry
    bounds*: Rect
    previousBounds*: Rect      # For incremental hit-test updates

    # State
    visible*: bool
    enabled*: bool
    hovered*: bool             # Mouse is over this widget
    pressed*: bool             # Mouse button down on this widget
    focused*: bool             # Has keyboard focus

    # Dirty flags
    isDirty*: bool             # Needs re-render
    layoutDirty*: bool         # Needs layout calculation

    # Rendering
    cachedTexture*: Option[Texture2D]
    zIndex*: int
    hasOverlay*: bool          # If true, children are sorted by z-index during rendering

    # Scripting support
    scriptable*: bool                    # Can be controlled via scripting
    blockReading*: bool                  # Prevent reading sensitive data (passwords, etc.)
    allowedActions*: set[ScriptAction]   # Permitted actions

    # Focus callbacks
    onFocus*: Option[proc() {.closure.}]       # Called when widget gains focus
    onBlur*: Option[proc() {.closure.}]        # Called when widget loses focus

    # Hierarchy
    parent*: Widget
    children*: seq[Widget]

  WidgetTree* = ref object
    root*: Widget

    anyDirty*: bool # Tree-level optimization flag
    isDirty*: bool

    widgetMap*: Table[WidgetId, Widget]       # Numeric ID -> Widget
    widgetsByStringId*: Table[string, Widget] # String ID -> Widget (for scripting)

# ============================================================================
# Reactive System
# ============================================================================

type
  Link*[T] = ref object
    value*: T  # Internal field accessed by link.nim
    dependentWidgets*: HashSet[Widget]  # Direct references for O(1) updates!
    onChange*: proc(oldVal, newVal: T)

  Store* = ref object of RootObj
    # User defines fields with Link[T] types
    # Example:
    # counter*: Link[int]
    # username*: Link[string]

# ============================================================================
# Event Types
# ============================================================================

type
  EventKind* = enum
    # Mouse
    evMouseMove
    evMouseDown
    evMouseUp
    evMouseWheel
    evMouseHover

    # Keyboard
    evKeyDown
    evKeyUp
    evChar

    # Window
    evWindowResize
    evWindowClose
    evWindowFocus
    evWindowBlur

    # Touch/Gesture
    evTouchStart
    evTouchMove
    evTouchEnd
    evGesture

  EventPriority* = enum
    epHigh      # Input feedback, clicks
    epNormal    # Regular updates
    epLow       # Background operations

  GuiEvent* = object
    kind*: EventKind
    priority*: EventPriority
    timestamp*: MonoTime

    # Event data (variant would go here in full implementation)
    # For now, just the essentials
    mousePos*: Point
    key*: KeyboardKey
    char*: char
    windowSize*: Size

  EventPattern* = enum
    epNormal      # Process immediately
    epReplaceable # Only last matters (mouse move)
    epDebounced   # Wait for quiet period (resize)
    epThrottled   # Rate limited (scroll)
    epBatched     # Collect related (touch gestures)
    epOrdered     # Sequence matters (keyboard combo)

  EventTiming* = object
    count*: int
    totalTime*: Duration
    avgTime*: Duration
    maxTime*: Duration

  EventConfig* = object
    pattern*: EventPattern
    debounceTime*: Duration        # For epDebounced
    throttleInterval*: Duration    # For epThrottled
    batchSize*: int                # For epBatched
    maxSequenceTime*: Duration     # For epBatched, epOrdered

  EventSequence* = object
    events*: seq[GuiEvent]
    startTime*: MonoTime
    lastEventTime*: MonoTime

# ============================================================================
# Rendering Types
# ============================================================================

type
  RenderOpKind* = enum
    ropRect
    ropTexture
    ropText

  RenderOp* = object
    case kind*: RenderOpKind
    of ropRect:
      rect*: Rect
      bgcolor*: Color
    of ropTexture:
      texture*: Texture2D
      source*, dest*: Rect
    of ropText:
      text*: string
      textCache*: Option[Texture2D]
      fgcolor*: Color

# ============================================================================
# Application Types
# ============================================================================

type
  WindowConfig* = object
    width*: int
    height*: int
    title*: string
    fps*: int
    resizable*: bool  # Allow window to be resized by user
    minWidth*: int    # Minimum window width (0 = no minimum)
    minHeight*: int   # Minimum window height (0 = no minimum)

  # App type is defined in core/app.nim to avoid circular dependencies
  # and because it depends on managers that are defined later

# ============================================================================
# Helper Functions
# ============================================================================

proc hash*(id: WidgetId): Hash =
  hash(id.int)

proc `==`*(a, b: WidgetId): bool =
  a.int == b.int

proc `$`*(id: WidgetId): string =
  $id.int

proc hash*(widget: Widget): Hash =
  ## Hash function for Widget (uses id)
  hash(widget.id)

proc `<`*(a, b: GuiEvent): bool =
  ## Comparison for priority queue (higher priority first, then FIFO by timestamp)
  if a.priority != b.priority:
    return a.priority < b.priority
  else:
    return a.timestamp < b.timestamp

# WidgetId generator
var nextWidgetId {.global.} = 0

proc newWidgetId*(): WidgetId =
  result = WidgetId(nextWidgetId)
  inc nextWidgetId

# ============================================================================
# Base Widget Methods (to be overridden by specific widgets)
# ============================================================================

method render*(widget: Widget) {.base.} =
  ## Render this widget. Override in derived types.
  ## Base implementation does nothing.
  discard

method measure*(widget: Widget, constraints: Constraints): Size =
  ## Calculate the preferred size of this widget given constraints.
  ## Base implementation returns current bounds size.
  result = Size(width: widget.bounds.width, height: widget.bounds.height)

method layout*(widget: Widget) =
  ## Position and size children of this widget.
  ## Base implementation does nothing (leaf widgets don't need layout).
  discard

method handleInput*(widget: Widget, event: GuiEvent): bool =
  ## Handle input event. Return true if handled (stops propagation).
  ## Base implementation returns false (not handled).
  result = false

method handleScriptAction*(widget: Widget, action: string, params: JsonNode): JsonNode =
  ## Handle a scripting action. Override in derived widgets.
  ## Returns JSON response (success, error, or data).
  ## Base implementation returns error for unknown action.
  result = %*{
    "success": false,
    "error": "Action not supported: " & action
  }

method getScriptableState*(widget: Widget): JsonNode {.base.} =
  ## Get the current state of this widget as JSON.
  ## Base implementation returns basic widget properties.
  ## Override in derived widgets to include widget-specific state.
  result = %*{
    "id": widget.stringId,
    "type": "Widget",
    "visible": widget.visible,
    "enabled": widget.enabled,
    "scriptable": widget.scriptable,
    "bounds": {
      "x": widget.bounds.x,
      "y": widget.bounds.y,
      "width": widget.bounds.width,
      "height": widget.bounds.height
    }
  }
