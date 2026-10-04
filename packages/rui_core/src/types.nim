## Core type definitions for RUI
##
## This file contains the fundamental types used throughout the framework.

import std/[tables, sets, hashes, options, times, monotimes, json, unicode]
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
  CursorShape* = enum
    ## The mouse cursor over a widget. rui's own names rather than raylib's
    ## MouseCursor, whose `Default` would collide with ThemeIntent.Default.
    csDefault    ## Inherit from the nearest ancestor that sets one; arrow at the root
    csArrow
    csText       ## I-beam, over editable text
    csPointer    ## Pointing hand, over links
    csCrosshair
    csResizeH    ## Left-right, for splitters and column edges
    csResizeV
    csMove
    csNotAllowed

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
    hotkey*: string
      ## A key chord that activates this widget ("Ctrl+S"), set with the
      ## `.shortcut(...)` modifier. The help overlay labels it next to the widget.
    takesText*: bool
      ## Consumes typed characters while focused (an editable text field). Keys
      ## that are really typing -- a "?" -- are left alone while one has focus.
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

    sizeRequest*: Size
      ## The size this widget asks for, per dimension; 0 is "no request". It
      ## wins over what a parent assigns -- an explicit width beats stretch,
      ## as in CSS -- and is set with `frame(width = ..., height = ...)`
      ## rather than by writing `bounds`, which layout owns.
    sizeMin*, sizeMax*: Size
      ## Limits applied after layout; 0 in `sizeMax` is "unbounded".
    ownWidth*, ownHeight*: float32
      ## The size this widget gave *itself* at its last layout, or -1 for a
      ## dimension its parent assigned. See `beginSelfSizing`.
    cursorShape*: CursorShape
      ## The pointer shape while hovering this widget. `csDefault` defers to
      ## the parent, so a composite sets it once for all its parts.
    culled*: bool
      ## Set by the render pass while the widget is wholly outside what is on
      ## screen: it is skipped, not painted, and keeps whatever dirt it has
      ## until it scrolls into view.
    flexLoose*: bool
      ## Flexible's `FlexFit.loose`: take at most the flex share, not exactly it.
    flexGrow*: float32
      ## Share of a stack's leftover main-axis space this widget takes, like
      ## CSS `flex-grow`. 0 (the default) keeps the widget at its own size.
      ##
      ## Only a stack with a fixed main-axis size has leftover space to hand
      ## out; one that sizes to its content has none. A flex child is measured
      ## at its natural size on every pass before it grows, so it shrinks back
      ## when the stack does. See `rui_core/flex.nim`.

    # Dirty flags
    isDirty*: bool             # Needs re-render
    layoutDirty*: bool         # Needs layout calculation

    # Rendering
    cachedTexture*: Option[RenderTexture2D]  # Cached render target for this widget
    childClip*: Option[Rect]
      ## Clip composited children to this rectangle, in coordinates relative to
      ## this widget's own top-left corner.
      ##
      ## For a viewport that is smaller than the widget holding it: a ScrollView
      ## is as big as its frame, but its content must stop short of the
      ## scrollbars and the padding. Without this, content is clipped only by
      ## the widget's render texture -- which is the full bounds -- and shows
      ## through in the gutter.
      ##
      ## `none` means the whole widget, which is what almost every container
      ## wants and what it costs nothing to leave alone.
    zIndex*: int
    hasOverlay*: bool          # If true, children are sorted by z-index during rendering

    # Scripting support (app-level control)
    blockReading*: bool                  # Prevent reading sensitive data (passwords, etc.)

    # Focus callbacks. Plain nilable closures, like every handler the DSL
    # generates: nil is the only "nothing attached" a proc needs, and an Option
    # around it only forced callers to write some(proc() {.closure.} = ...).
    onFocus*: proc() {.closure.}       # Called when widget gains focus
    onBlur*: proc() {.closure.}        # Called when widget loses focus

    # Data binding
    onRefresh*: proc() {.closure.}
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
    observers*: seq[proc() {.closure.}]
      ## Run after every change: how derived links follow their sources
      ## without taking the single `onChange` slot from the application.
    held*: bool
      ## Inside a `transaction` with a change not yet announced.
    heldFrom*: T
      ## The value before the transaction's first change to this link.

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

    # Files dropped on the window from the OS, delivered where the pointer is
    evFileDrop

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

  KeyMod* = enum
    ## A modifier held while an event happened.
    kmShift, kmCtrl, kmAlt, kmSuper

  GuiEvent* = object
    kind*: EventKind
    priority*: EventPriority
    timestamp*: MonoTime

    # Event data (variant would go here in full implementation)
    # For now, just the essentials
    mousePos*: Point
    key*: KeyboardKey
    char*: char
      ## The typed character when it is ASCII, otherwise '\0'. Kept for
      ## callers that only care about ASCII (NumberInput's digits); anything
      ## that inserts text should use `typedRune`.
    rune*: Rune
      ## The typed codepoint for an `evChar`. `char` alone is one byte and
      ## cannot hold "é" or "ש" -- this can.
    mods*: set[KeyMod]
      ## Modifiers held when the event happened, on every event kind -- so a
      ## Ctrl-click and a Shift+arrow are both answered from the event itself,
      ## not from live keyboard state that a test or a script cannot set.
    windowSize*: Size
    paths*: seq[string]
      ## The files or folders an `evFileDrop` carries (absolute paths).
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
  widget.ownWidth = -1
  widget.ownHeight = -1

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

type SelfSizing* = tuple[width, height: bool]

proc clampDimension*(value, lo, hi: float32): float32 =
  ## `value` within [lo, hi], where a `hi` of 0 means no upper limit.
  result = max(value, lo)
  if hi > 0:
    result = min(result, hi)

proc beginSelfSizing*(widget: Widget): SelfSizing =
  ## Run before a widget's `layout`: forget any size it gave itself last time.
  ##
  ## Widgets tell "my parent assigned this size" from "I have to measure" by
  ## `bounds.width <= 0`. That only works once: after the first layout a
  ## self-computed size is non-zero and looks assigned, so a VStack that sized
  ## itself to two children stayed that height when a third arrived. A
  ## dimension still equal to what the widget set itself is reset to 0 here,
  ## so it is measured afresh; one the parent has since changed is left alone.
  ##
  ## Returns which dimensions start at zero, i.e. which the widget will be
  ## sizing itself this time.
  if widget.ownWidth >= 0 and widget.bounds.width == widget.ownWidth:
    widget.bounds.width = 0
  if widget.ownHeight >= 0 and widget.bounds.height == widget.ownHeight:
    widget.bounds.height = 0
  # A requested size is an assignment the widget makes on its own behalf, and
  # it overrides the parent's -- so it is applied before the body runs and
  # the children lay out inside it.
  if widget.sizeRequest.width > 0:
    widget.bounds.width = widget.sizeRequest.width
  if widget.sizeRequest.height > 0:
    widget.bounds.height = widget.sizeRequest.height
  result = (widget.bounds.width <= 0, widget.bounds.height <= 0)
  # An assigned size is clamped now, before the children see it; a self-
  # computed one after the body has measured it (endSelfSizing).
  if not result.width:
    widget.bounds.width = clampDimension(widget.bounds.width,
                                         widget.sizeMin.width, widget.sizeMax.width)
  if not result.height:
    widget.bounds.height = clampDimension(widget.bounds.height,
                                          widget.sizeMin.height, widget.sizeMax.height)

proc endSelfSizing*(widget: Widget, sizing: SelfSizing) =
  ## Run after `layout`: clamp what the widget gave itself, and remember it.
  if sizing.width:
    widget.bounds.width = clampDimension(widget.bounds.width,
                                         widget.sizeMin.width, widget.sizeMax.width)
  if sizing.height:
    widget.bounds.height = clampDimension(widget.bounds.height,
                                          widget.sizeMin.height, widget.sizeMax.height)
  widget.ownWidth = if sizing.width: widget.bounds.width else: -1.0'f32
  widget.ownHeight = if sizing.height: widget.bounds.height else: -1.0'f32

proc effectiveCursor*(widget: Widget): CursorShape =
  ## The shape to show over `widget`: its own, or the nearest ancestor's.
  var w = widget
  while w != nil:
    if w.cursorShape != csDefault:
      return w.cursorShape
    w = w.parent
  csArrow

proc typedRune*(e: GuiEvent): Rune =
  ## The codepoint an `evChar` carries: `rune` when the source set it,
  ## otherwise the ASCII `char`, so an event built with only `char:` still
  ## types what it says.
  if e.rune.int32 > 0: e.rune else: Rune(ord(e.char))

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

