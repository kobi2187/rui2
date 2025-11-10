# constraints.nim
import macros, tables, sets
import kiwi

type
  ConstraintKind = enum
    ckEqual, ckLessEqual, ckGreaterEqual
    ckPercentage, ckRelative, ckAbsolute

  ConstraintExpr = object
    case kind: ConstraintKind
    of ckEqual, ckLessEqual, ckGreaterEqual:
      left, right: Expression
    of ckPercentage:
      value: float32
      relativeTo: string  # parent property name
    of ckRelative:
      widget: string    # widget path
      property: string  # property name
      offset: float32
    of ckAbsolute:
      value: float32

  LayoutScope = object
    solver: Solver
    variables: Table[string, Variable]  # "widgetPath.property" -> Variable

macro layout*(body: untyped): untyped =
  ## Layout DSL for constraints
  ## Example:
  ## layout:
  ##   mainPanel:
  ##     width = 80%
  ##     height = 90%
  ##     center in parent
  ##   
  ##   sidebar:
  ##     width = 200
  ##     left = parent.left
  ##     top = mainPanel.bottom
  
  result = newStmtList()
  
  # Create solver and scope
  result.add quote do:
    var scope = LayoutScope(
      solver: newSolver(),
      variables: initTable[string, Variable]()
    )

  # Process each widget section
  for section in body:
    case section.kind
    of nnkCall:
      # Handle widget path and constraints
      let widgetPath = section[0]
      let constraints = section[1]
      result.add processWidgetConstraints(widgetPath, constraints)
    else:
      error("Expected widget path followed by constraints")

proc processWidgetConstraints(path, constraints: NimNode): NimNode =
  result = newStmtList()
  
  # Add variables for this widget
  result.add quote do:
    let widget = findWidget(`path`)
    addWidgetVariables(scope, widget)
  
  # Process each constraint
  for constraint in constraints:
    result.add processConstraint(constraint)

# Helper procs for the macro
proc findWidget(path: string): Widget =
  # Find widget by path in the widget tree
  # "mainPanel/button/1" would find the first button in mainPanel
  let parts = path.split('/')
  var current = rootWidget
  for part in parts:
    if part.endsWith("*"):
      # Handle wildcards
      let prefix = part[0..^2]
      # Find all matching widgets
      result = findMatchingWidgets(current, prefix)
    else:
      current = current.findChild(part)
  result = current

# Usage example
let panel = Panel()
let sidebar = Panel()
let content = Panel()

layout:
  panel:
    width = 80%
    height = 90%
    center in parent
  
  sidebar:
    width = 200
    left = panel.left
    top = panel.bottom + 10
    bottom = parent.bottom
  
  content:
    left = sidebar.right + 10
    right = parent.right - 10
    top = panel.bottom + 10
    bottom = parent.bottom

# Wildcard example
layout:
  "toolbar/button/*":
    height = 30
    width = 100

# Complex layout example
layout:
  mainView:
    fill parent
    padding = 10

  "mainView/header":
    height = 60
    width = fill
    top = parent.top

  "mainView/sidebar":
    width = 250
    top = header.bottom
    bottom = footer.top
    left = parent.left

  "mainView/content":
    left = sidebar.right + 10
    right = parent.right
    top = header.bottom
    bottom = footer.top

  # All buttons in the content area
  "mainView/content//button/*":
    height = 32
    margin = 5

  "mainView/footer":
    height = 40
    width = fill
    bottom = parent.bottom

# Special positioning helpers
proc center(widget: Widget, inParent: Widget) =
  layout:
    widget:
      centerX = parent.centerX
      centerY = parent.centerY

proc fill(widget: Widget, inParent: Widget, padding: float32 = 0) =
  layout:
    widget:
      left = parent.left + padding
      right = parent.right - padding
      top = parent.top + padding
      bottom = parent.bottom - padding

# Animation support
proc animate(duration: float32, easing: EasingFunction, body: untyped): untyped =
  ## Animate constraints over time
  layout:
    panel:
      constraints animate(0.3, easeInOut):
        from:
          scale = 0.8
          opacity = 0
        to:
          scale = 1.0
          opacity = 1