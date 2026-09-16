## Core type definitions for RUI
##
## This file contains the fundamental types used throughout the framework.

import std/[tables, sets, hashes, options, times, monotimes, json]
export sets, tables, options, json  # Export for use in other modules

# Raylib types that are genuinely part of rui_core's interface.
#
# This used to be `export ... , raylib` -- three named symbols followed by the
# whole module, which made the naming decorative and put every raylib proc,
# type and enum field in scope in every module that imports rui_core. It cost
# real workarounds: `TraceLogLevel`'s Info/Warning/Error collided with
# rui_drawing's ThemeIntent, AlertLevel and ValidationState.
#
# KeyboardKey is deliberately NOT here, for the same reason. Exporting an enum
# type exposes its fields unqualified, and KeyboardKey has a `Menu` field that
# collides with the Menu widget, plus `Down` and `Up` that collide with
# rui_drawing's ArrowDirection. That cost `menu.Menu` in six places in
# menus/menubar.nim and `KeyboardKey.Down` in tests/test_keyboard_nav.nim --
# for a type only nine files in the whole repo mention, nearly all of which
# already import raylib on their own account. A module that reads keys says
# `import raylib` and gets the fields; every other module gets its own `Menu`
# back.
#
# Procs (drawTexture, isKeyDown, getTime, ...) are deliberately not re-exported:
# a module that draws should say `import raylib` itself.
import raylib
export raylib.Color, raylib.MouseButton,
       raylib.RenderTexture2D, raylib.Texture2D, raylib.Image,
       raylib.Vector2, raylib.Vector3, raylib.Rectangle, raylib.Font,
       raylib.WHITE, raylib.BLACK, raylib.GRAY, raylib.LIGHTGRAY,
       raylib.DARKGRAY, raylib.RED, raylib.GREEN, raylib.BLUE,
       raylib.YELLOW, raylib.ORANGE, raylib.PURPLE, raylib.MAROON,
       raylib.RAYWHITE, raylib.BLANK
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

proc contains*(rect: Rect, x, y: float32): bool =
  ## Is the point (x, y) inside the rectangle?
  ##
  ## Lives here, next to Rect, because four widgets and the hit-test system all
  ## needed it. When each of them declared its own copy, importing two of them
  ## through the `rui` barrel made every call ambiguous.
  ##
  ## Inclusive on all four edges, which is what the hit-test system has always
  ## used. Kept that way deliberately: making it half-open here would silently
  ## stop clicks landing on a widget's right or bottom edge.
  x >= rect.x and x <= rect.x + rect.width and
  y >= rect.y and y <= rect.y + rect.height

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
# (Scripting is controlled at app-level, not per-widget)

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
    focusable*: bool
      ## Can this widget be a tab stop? Defaults to **false**, so a widget is
      ## reachable by keyboard only if it says so.
      ##
      ## Widgets that handle keys set it in their own `init:` section — plain
      ## code in the widget's own file, not something the DSL infers. A
      ## hand-written widget sets the field like any other, and a container
      ## opts in the same way when it becomes a focus group.
      ##
      ## Before this existed, `collectFocusableWidgets` added every visible and
      ## enabled widget, so Tab landed on containers and static labels.
    focusGroup*: bool
      ## Is this widget a keyboard navigation group?
      ##
      ## A group is **one stop** for Tab from outside: Tab moves onto the group
      ## and lands directly on a member, arrow keys then move between members,
      ## and Tab again leaves the whole group rather than stepping through it.
      ## Escape leaves it without moving on. This is the "roving tabindex"
      ## arrangement every desktop toolkit uses for lists, toolbars and radio
      ## groups, and what stops a twenty-row list being twenty tab stops.
      ##
      ## Groups nest: a list inside a tab page inside a form is three levels,
      ## and each level's keys are tried innermost-first.
      ##
      ## Orthogonal to `focusable`. A group is normally not a tab stop in its
      ## own right -- its members are.

    # Dirty flags
    isDirty*: bool             # Needs re-render
    layoutDirty*: bool         # Needs layout calculation

    # Rendering
    cachedTexture*: Option[RenderTexture2D]  # Cached render target for this widget
    zIndex*: int
    hasOverlay*: bool          # If true, children are sorted by z-index during rendering

    # Scripting support (app-level control)
    blockReading*: bool                  # Prevent reading sensitive data (passwords, etc.)

    # Focus callbacks
    onFocus*: Option[proc() {.closure.}]       # Called when widget gains focus
    onBlur*: Option[proc() {.closure.}]        # Called when widget loses focus

    # Data binding
    onRefresh*: Option[proc() {.closure.}]
      ## Invoked by the layout pass when the widget is dirty, before layout()
      ## runs. This is what makes Link[T] binding actually change what is on
      ## screen: `Link.set` marks its dependents dirty, and each dependent's
      ## refresh hook copies the new value into whatever prop it is bound to.
      ## Without it a Link only ever marked widgets dirty and they re-rendered
      ## the value they were constructed with.

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
    ## Reactive cell. Read and write it through `value` / `value=` (or the
    ## `get` / `set` aliases) -- never the backing field.
    ##
    ## The field is deliberately NOT called `value`. It used to be, and because
    ## Nim resolves `link.value = x` to the field rather than to the `value=`
    ## proc of the same name, every assignment silently skipped the
    ## notification: no dependent was ever marked dirty and no onChange ever
    ## fired. The whole reactive system was inert.
    val*: T
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
    wheelDelta*: float32  # Mouse wheel movement (positive = up, negative = down)

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

proc initWidgetBase*(widget: Widget) =
  ## Bring a freshly allocated widget up to "exists and will be drawn".
  ##
  ## Nim zeroes a new ref object, so without this a widget is born with
  ## visible == false, enabled == false and a zero id: renderPass() skips it
  ## and nothing ever appears. Every DSL constructor calls this first, and a
  ## hand-written widget must do the same.
  widget.id = newWidgetId()
  widget.visible = true
  widget.enabled = true
  widget.isDirty = true
  widget.layoutDirty = true
  widget.children = @[]

# Structural change counter.
#
# Anything that caches a walk of the widget tree -- the focus chain is the one
# that exists today -- records this value when it builds and compares on use, so
# it can tell "the tree grew since I last looked" without the tree having to
# know its observers exist. rui_core cannot reach rui_events, so a callback or a
# direct notification would be a dependency cycle.
#
# Bumped by addChild. There is no removeChild in the library yet; when one
# arrives it must bump this too.
var treeStructureVersion {.global.} = 0

proc structureVersion*(): int =
  ## Increments whenever the widget tree's shape changes.
  treeStructureVersion

proc noteStructureChanged*() =
  ## Call after adding or removing a widget from the tree.
  inc treeStructureVersion

# ============================================================================
# Base Widget Methods (to be overridden by specific widgets)
# ============================================================================

method render*(widget: Widget) {.base.} =
  ## Render this widget. Override in derived types.
  ## Base implementation does nothing.
  discard

method measure*(widget: Widget, constraints: Constraints): Size {.base.}=
  ## Calculate the preferred size of this widget given constraints.
  ## Base implementation returns current bounds size.
  result = Size(width: widget.bounds.width, height: widget.bounds.height)

method layout*(widget: Widget) {.base.}=
  ## Position and size children of this widget.
  ## Base implementation does nothing (leaf widgets don't need layout).
  discard

method handleInput*(widget: Widget, event: GuiEvent): bool {.base.}=
  ## Handle input event. Return true if handled (stops propagation).
  ## Base implementation returns false (not handled).
  result = false

method handleScriptAction*(widget: Widget, action: string, params: JsonNode): JsonNode {.base.}=
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
    "bounds": {
      "x": widget.bounds.x,
      "y": widget.bounds.y,
      "width": widget.bounds.width,
      "height": widget.bounds.height
    }
  }

method getTypeName*(widget: Widget): string {.base.} =
  ## Get the widget's type name
  ## MUST be overridden by derived widgets
  ## The defineWidget macro generates this automatically
  "Widget"

# ============================================================================
# Widget Tree Helpers
# ============================================================================

proc treeDepth*(widget: Widget): int =
  ## Distance from the root of the widget tree. Used by hit-testing to prefer
  ## the most deeply nested widget when several overlap at the same z-index.
  var w = widget.parent
  while w != nil:
    inc result
    w = w.parent

proc registerWidget*(tree: WidgetTree, widget: Widget) =
  ## Register a widget in the widget tree
  ## Adds to both numeric ID map and string ID map (if stringId is set)
  tree.widgetMap[widget.id] = widget
  if widget.stringId.len > 0:
    tree.widgetsByStringId[widget.stringId] = widget

proc unregisterWidget*(tree: WidgetTree, widget: Widget) =
  ## Unregister a widget from the widget tree
  tree.widgetMap.del(widget.id)
  if widget.stringId.len > 0:
    tree.widgetsByStringId.del(widget.stringId)

proc setWidgetStringId*(tree: WidgetTree, widget: Widget, id: string) =
  ## Set a widget's string ID and register it in the tree
  ## Use this instead of directly setting widget.stringId
  if widget.stringId.len > 0:
    # Remove old registration
    tree.widgetsByStringId.del(widget.stringId)
  widget.stringId = id
  if id.len > 0:
    tree.widgetsByStringId[id] = widget

proc markSubtreeDirty*(widget: Widget, alsoLayout = true) =
  ## Mark a widget and everything under it as needing a repaint.
  ##
  ## Needed for changes that affect every widget at once -- a theme switch, a
  ## font-rendering change -- where the per-widget dirty flags carry no signal
  ## because nothing about any individual widget changed.
  if widget == nil:
    return
  widget.isDirty = true
  if alsoLayout:
    # Composites read theme props inside layout() (a Button rebuilds its
    # background and label there), so a repaint alone is not enough.
    widget.layoutDirty = true
  for child in widget.children:
    child.markSubtreeDirty(alsoLayout)

proc registerWidgetRecursive*(tree: WidgetTree, widget: Widget) =
  ## Register a widget and all its children recursively
  tree.registerWidget(widget)
  for child in widget.children:
    tree.registerWidgetRecursive(child)

proc markDirtyToRoot*(widget: Widget) =
  ## Mark this widget and every ancestor up to the root as needing a re-render.
  ##
  ## Only the direct leaf->root line is marked. Siblings and any unaffected
  ## subtree stay clean, so the render pass reuses their cached textures and a
  ## dirty parent simply re-composites its children's caches (rebuilding only the
  ## dirty ones). This keeps the changed texture flowing to the screen while
  ## untouched subtrees are not redrawn.
  var w = widget
  while w != nil:
    w.isDirty = true
    w = w.parent

