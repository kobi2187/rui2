# constraints.nim
import kiwi
import types

type
  Anchor* = enum
    aLeft, aRight, aTop, aBottom
    aWidth, aHeight
    aCenterX, aCenterY

  Constraint* = object
    variable*: Variable
    solver*: Solver
    strength*: float
    
  WidgetConstraints* = object
    left*, right*, top*, bottom*: Variable
    width*, height*: Variable
    solver*: Solver

  # Add to Widget type
  Widget* = ref object of RootObj
    constraints*: WidgetConstraints
    # ... other fields

proc initConstraints*(widget: Widget) =
  # Create variables for the widget's edges
  let solver = newSolver()
  widget.constraints = WidgetConstraints(
    left: newVariable(widget.id & ".left"),
    right: newVariable(widget.id & ".right"),
    top: newVariable(widget.id & ".top"),
    bottom: newVariable(widget.id & ".bottom"),
    width: newVariable(widget.id & ".width"),
    height: newVariable(widget.id & ".height"),
    solver: solver
  )

  # Add basic constraints that must always be satisfied
  # width = right - left
  solver.addConstraint(
    widget.constraints.width == widget.constraints.right - widget.constraints.left
  )
  # height = bottom - top
  solver.addConstraint(
    widget.constraints.height == widget.constraints.bottom - widget.constraints.top
  )

proc addConstraint*(widget: Widget, expr: Expression, strength: float = 1.0) =
  widget.constraints.solver.addConstraint(expr, strength)

# Helper procs for common constraint patterns
proc centerX*(widget: Widget, in_parent: Widget) =
  let parentCenter = (in_parent.constraints.left + in_parent.constraints.right) / 2
  let widgetCenter = (widget.constraints.left + widget.constraints.right) / 2
  widget.constraints.solver.addConstraint(widgetCenter == parentCenter)

proc centerY*(widget: Widget, in_parent: Widget) =
  let parentCenter = (in_parent.constraints.top + in_parent.constraints.bottom) / 2
  let widgetCenter = (widget.constraints.top + widget.constraints.bottom) / 2
  widget.constraints.solver.addConstraint(widgetCenter == parentCenter)

proc width*(widget: Widget, value: float32) =
  widget.constraints.solver.addConstraint(widget.constraints.width == value)

proc height*(widget: Widget, value: float32) =
  widget.constraints.solver.addConstraint(widget.constraints.height == value)

proc left*(widget: Widget, value: float32) =
  widget.constraints.solver.addConstraint(widget.constraints.left == value)

proc percentWidth*(widget: Widget, percent: float32, of_parent: Widget) =
  widget.constraints.solver.addConstraint(
    widget.constraints.width == of_parent.constraints.width * (percent / 100.0)
  )

# Layout management
proc solveConstraints*(widget: Widget) =
  # Solve constraints recursively for the widget and its children
  widget.constraints.solver.updateVariables()
  
  # Update widget geometry from solved constraints
  widget.rect.pos.x = widget.constraints.left.value
  widget.rect.pos.y = widget.constraints.top.value
  widget.rect.size.width = widget.constraints.width.value
  widget.rect.size.height = widget.constraints.height.value
  
  # Solve for children
  for child in widget.children:
    solveConstraints(child)

# Example usage
proc constrainWidget(widget, parent: Widget) =
  # Initialize constraints
  initConstraints(widget)
  
  # Add constraints relative to parent
  widget.addConstraint(widget.constraints.left >= parent.constraints.left + 10)
  widget.addConstraint(widget.constraints.right <= parent.constraints.right - 10)
  widget.addConstraint(widget.constraints.top >= parent.constraints.top + 10)
  widget.addConstraint(widget.constraints.bottom <= parent.constraints.bottom - 10)
  
  # Center widget
  centerX(widget, parent)
  
  # Set size
  width(widget, 200)
  height(widget, 100)

# Integrate with Widget system
method update*(widget: Widget) =
  # Solve constraints before rendering
  solveConstraints(widget)
  
  # Normal update logic follows
  procCall widget.Widget.update()