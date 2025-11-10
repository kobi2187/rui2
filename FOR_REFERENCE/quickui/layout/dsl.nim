# src/quickui/layout/dsl.nim
import macros, tables
import ../core/[types, widget]
import ./constraints

type
  LayoutContext = ref object
    parent: Widget
    cs: ConstraintSystem
    variables: Table[string, Widget]

# Main layout macro
macro layout*(body: untyped): untyped =
  ## Main layout DSL entry point
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
  
  # Create layout context
  result.add quote do:
    var ctx = LayoutContext(
      cs: newConstraintSystem(),
      variables: initTable[string, Widget]()
    )

  # Process layout body
  for node in body:
    result.add processLayoutNode(node, "ctx")

proc processLayoutNode(node: NimNode, ctxName: string): NimNode =
  case node.kind
  of nnkCall:
    # Widget definition: name: body
    let widgetName = node[0]
    let widgetBody = node[1]
    
    result = quote do:
      block:
        let widget = `widgetName`
        `ctxName`.variables[widget.id] = widget
        `ctxName`.cs.addWidget(widget)
        
        # Process widget body
        `processWidgetBody`(widget, `widgetBody`, `ctxName`)
  else:
    error("Unexpected node kind in layout: " & $node.kind)

# Layout property handling
macro layoutProps*(widget: Widget, body: untyped): untyped =
  ## Process layout properties for a widget
  ## Example:
  ## layoutProps button:
  ##   width = 100
  ##   height = 30
  ##   left = parent.left + 10
  result = newStmtList()
  
  for prop in body:
    case prop.kind
    of nnkAsgn:
      # Property assignment: prop = value
      let propName = prop[0]
      let propValue = prop[1]
      result.add processConstraint(widget, propName, propValue)
    of nnkInfix:
      # Relation: widget in parent
      if prop[0].strVal == "in":
        result.add processRelation(widget, prop[1], prop[2])
    else:
      error("Unexpected property kind: " & $prop.kind)

# Helper procs for processing constraints
proc processConstraint(widget: NimNode, prop, value: NimNode): NimNode =
  case prop.strVal
  of "width":
    case value.kind
    of nnkIntLit, nnkFloatLit:
      # Fixed size
      quote do:
        cs.setWidth(`widget`, `value`.float32)
    of nnkInfix:
      if value[0].strVal == "%":
        # Percentage
        let percent = value[1]
        quote do:
          cs.setPercentWidth(`widget`, parent, `percent`.float32)
      else:
        error("Unsupported width operation: " & value[0].strVal)
    else:
      error("Unsupported width value kind: " & $value.kind)
  
  of "height": # Similar to width...
    # ... implementation

  of "left", "right", "top", "bottom":
    # Edge constraints
    quote do:
      cs.addConstraint(eq(`widget`.`prop`, `value`))

  else:
    error("Unknown property: " & prop.strVal)

# Layout patterns
template hstack*(body: untyped) =
  ## Horizontal stack layout
  layout:
    let stack = Panel(layoutType: ltHorizontal)
    `body`
    for i, child in stack.children:
      if i > 0:
        cs.addConstraint(eq(child.left, stack.children[i-1].right + spacing))
      cs.addConstraint(eq(child.top, stack.top))

template vstack*(body: untyped) =
  ## Vertical stack layout
  layout:
    let stack = Panel(layoutType: ltVertical)
    `body`
    for i, child in stack.children:
      if i > 0:
        cs.addConstraint(eq(child.top, stack.children[i-1].bottom + spacing))
      cs.addConstraint(eq(child.left, stack.left))

# Usage example:
layout:
  mainWindow:
    width = 800
    height = 600
    
    vstack:
      spacing = 10
      
      toolbar:
        height = 40
        
        hstack:
          spacing = 5
          
          button "Save":
            width = 80
          
          button "Load":
            width = 80
      
      hsplit:
        sidebar:
          width = 200
          
        content:
          # Remaining space
          left = sidebar.right + 10
          right = parent.right - 10

# DSL support for common patterns
template center*(widget: Widget) =
  layoutProps widget:
    centerX = parent.centerX
    centerY = parent.centerY

template fill*(widget: Widget, margin: float32 = 0) =
  layoutProps widget:
    left = parent.left + margin
    right = parent.right - margin
    top = parent.top + margin
    bottom = parent.bottom - margin

template grid*(columns: int, spacing: float32 = 10, body: untyped) =
  layout:
    let grid = Panel(layoutType: ltGrid)
    grid.columns = columns
    grid.spacing = spacing
    `body`

# Responsive layout support
template responsive*(body: untyped) =
  layout:
    case window.width:
    of 0..600:
      `body`[0]  # Mobile layout
    of 601..1200:
      `body`[1]  # Tablet layout
    else:
      `body`[2]  # Desktop layout

# Animation support in layouts
template animate*(duration: float32, easing: proc(t: float32): float32, body: untyped) =
  layout:
    let anim = ConstraintAnimation(
      duration: duration,
      easing: easing
    )
    `body`
    cs.animate(anim)