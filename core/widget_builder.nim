## Widget Tree Builder
##
## Provides a simple DSL-like API for building widget trees programmatically.
## Inspired by YAML-UI but using Nim procs.

import types
import std/[options, tables]

when defined(useGraphics):
  import raylib

# ============================================================================
# Widget Creation Helpers
# ============================================================================

var nextInternalId = 0

proc newWidgetId*(): WidgetId =
  result = WidgetId(nextInternalId)
  inc nextInternalId

proc newWidget*(kind: WidgetKind, stringId: string = ""): Widget =
  ## Create a new widget with default values
  result = Widget(
    id: newWidgetId(),
    stringId: stringId,
    kind: kind,
    bounds: Rect(x: 0, y: 0, width: 100, height: 30),
    previousBounds: Rect(x: 0, y: 0, width: 100, height: 30),
    visible: true,
    enabled: true,
    hovered: false,
    pressed: false,
    focused: false,
    isDirty: true,
    layoutDirty: true,
    zIndex: 0,
    backgroundColor: none(Color),
    text: "",
    textColor: none(Color),
    children: @[],
    parent: nil,
    padding: EdgeInsets(top: 0, right: 0, bottom: 0, left: 0),
    minWidth: 0,
    maxWidth: 10000,
    minHeight: 0,
    maxHeight: 10000,
    onClick: nil,
    onHover: nil,
    onFocus: nil
  )

proc addChild*(parent, child: Widget) =
  ## Add a child widget to a parent
  parent.children.add(child)
  child.parent = parent
  # Children inherit parent's z-index + small offset
  child.zIndex = parent.zIndex + 1

# ============================================================================
# Specific Widget Constructors
# ============================================================================

proc newButton*(text: string, stringId: string = ""): Widget =
  ## Create a button widget
  result = newWidget(wkButton, stringId)
  result.text = text
  result.bounds.width = 100
  result.bounds.height = 40
  result.padding = EdgeInsets(top: 8, right: 16, bottom: 8, left: 16)

proc newLabel*(text: string, stringId: string = ""): Widget =
  ## Create a label widget
  result = newWidget(wkLabel, stringId)
  result.text = text
  result.bounds.width = 100
  result.bounds.height = 24

proc newTextInput*(placeholder: string = "", stringId: string = ""): Widget =
  ## Create a text input widget
  result = newWidget(wkTextInput, stringId)
  result.text = placeholder
  result.bounds.width = 200
  result.bounds.height = 32
  result.padding = EdgeInsets(top: 6, right: 8, bottom: 6, left: 8)

proc newCheckbox*(label: string = "", stringId: string = ""): Widget =
  ## Create a checkbox widget
  result = newWidget(wkCheckbox, stringId)
  result.text = label
  result.bounds.width = 120
  result.bounds.height = 24

proc newPanel*(stringId: string = ""): Widget =
  ## Create a panel/container widget
  result = newWidget(wkPanel, stringId)
  result.bounds.width = 300
  result.bounds.height = 200
  result.padding = EdgeInsets(top: 16, right: 16, bottom: 16, left: 16)

proc newContainer*(stringId: string = ""): Widget =
  ## Create a generic container widget
  result = newWidget(wkContainer, stringId)
  result.bounds.width = 300
  result.bounds.height = 200

# ============================================================================
# Fluent API for Configuration
# ============================================================================

proc withBounds*(w: Widget, x, y, width, height: float32): Widget {.discardable.} =
  ## Set widget bounds
  w.bounds = Rect(x: x, y: y, width: width, height: height)
  w.previousBounds = w.bounds
  return w

proc withSize*(w: Widget, width, height: float32): Widget {.discardable.} =
  ## Set widget size (position unchanged)
  w.bounds.width = width
  w.bounds.height = height
  return w

proc withPosition*(w: Widget, x, y: float32): Widget {.discardable.} =
  ## Set widget position (size unchanged)
  w.bounds.x = x
  w.bounds.y = y
  return w

proc withPadding*(w: Widget, all: float32): Widget {.discardable.} =
  ## Set uniform padding
  w.padding = EdgeInsets(top: all, right: all, bottom: all, left: all)
  return w

proc withPadding*(w: Widget, horiz, vert: float32): Widget {.discardable.} =
  ## Set horizontal and vertical padding
  w.padding = EdgeInsets(top: vert, right: horiz, bottom: vert, left: horiz)
  return w

proc withPadding*(w: Widget, top, right, bottom, left: float32): Widget {.discardable.} =
  ## Set individual padding values
  w.padding = EdgeInsets(top: top, right: right, bottom: bottom, left: left)
  return w

proc withBackgroundColor*(w: Widget, color: Color): Widget {.discardable.} =
  ## Set background color
  w.backgroundColor = some(color)
  return w

proc withTextColor*(w: Widget, color: Color): Widget {.discardable.} =
  ## Set text color
  w.textColor = some(color)
  return w

proc withZIndex*(w: Widget, z: int): Widget {.discardable.} =
  ## Set z-index
  w.zIndex = z
  return w

proc onClick*(w: Widget, handler: proc()): Widget {.discardable.} =
  ## Set click handler
  w.onClick = handler
  return w

proc onHover*(w: Widget, handler: proc()): Widget {.discardable.} =
  ## Set hover handler
  w.onHover = handler
  return w

# ============================================================================
# Widget Tree Management
# ============================================================================

proc newWidgetTree*(root: Widget): WidgetTree =
  ## Create a new widget tree
  result = WidgetTree(
    root: root,
    anyDirty: true,
    widgetMap: initTable[WidgetId, Widget](),
    widgetsByStringId: initTable[string, Widget]()
  )

proc registerWidget*(tree: WidgetTree, widget: Widget) =
  ## Register a widget in the tree's lookup tables
  tree.widgetMap[widget.id] = widget
  if widget.stringId.len > 0:
    tree.widgetsByStringId[widget.stringId] = widget

  # Recursively register children
  for child in widget.children:
    tree.registerWidget(child)

proc buildTree*(root: Widget): WidgetTree =
  ## Build a widget tree and register all widgets
  result = newWidgetTree(root)
  result.registerWidget(root)

proc getWidget*(tree: WidgetTree, stringId: string): Widget =
  ## Get a widget by its string ID
  tree.widgetsByStringId.getOrDefault(stringId, nil)

proc getWidget*(tree: WidgetTree, id: WidgetId): Widget =
  ## Get a widget by its numeric ID
  tree.widgetMap.getOrDefault(id, nil)

# ============================================================================
# Tree Traversal
# ============================================================================

proc walkTreeImpl(widget: Widget, result: var seq[Widget]) =
  ## Recursive helper for tree traversal
  result.add(widget)
  for child in widget.children:
    walkTreeImpl(child, result)

proc getAllWidgets*(tree: WidgetTree): seq[Widget] =
  ## Get all widgets as a sequence
  result = @[]
  if tree.root != nil:
    walkTreeImpl(tree.root, result)

proc getAllWidgets*(widget: Widget): seq[Widget] =
  ## Get all widgets from a widget and its children
  result = @[]
  walkTreeImpl(widget, result)

iterator walkTree*(tree: WidgetTree): Widget =
  ## Walk the entire tree from root
  let widgets = tree.getAllWidgets()
  for widget in widgets:
    yield widget

iterator walkTree*(widget: Widget): Widget =
  ## Walk from a widget through its children
  let widgets = widget.getAllWidgets()
  for w in widgets:
    yield w

# ============================================================================
# Layout Helpers (Simple for now)
# ============================================================================

proc layoutVertical*(parent: Widget, spacing: float32 = 8) =
  ## Simple vertical layout of children
  var yPos = parent.bounds.y + parent.padding.top
  for child in parent.children:
    child.bounds.x = parent.bounds.x + parent.padding.left
    child.bounds.y = yPos
    yPos += child.bounds.height + spacing

proc layoutHorizontal*(parent: Widget, spacing: float32 = 8) =
  ## Simple horizontal layout of children
  var xPos = parent.bounds.x + parent.padding.left
  for child in parent.children:
    child.bounds.x = xPos
    child.bounds.y = parent.bounds.y + parent.padding.top
    xPos += child.bounds.width + spacing
