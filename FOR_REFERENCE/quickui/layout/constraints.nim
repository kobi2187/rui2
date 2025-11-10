# src/quickui/layout/constraints.nim
import kiwi
import tables, options
import ../core/types

type
  ConstraintVar* = object
    left*, right*, top*, bottom*: Variable
    width*, height*: Variable
    centerX*, centerY*: Variable

  ConstraintSystem* = ref object
    solver: Solver
    variables: Table[string, ConstraintVar]
    widgets: Table[string, Widget]
    dirty: bool

  ConstraintStrength* = enum
    csWeak = 1
    csMedium = 1000
    csStrong = 1000000
    csRequired = float.high.int

  LayoutConstraint* = object
    expr: Expression
    strength: ConstraintStrength

proc newConstraintSystem*(): ConstraintSystem =
  ConstraintSystem(
    solver: newSolver(),
    variables: initTable[string, ConstraintVar](),
    widgets: initTable[string, Widget](),
    dirty: false
  )

proc addWidget*(cs: ConstraintSystem, widget: Widget) =
  if widget.id in cs.widgets:
    return

  # Create variables for the widget
  var vars = ConstraintVar(
    left: newVariable(widget.id & ".left"),
    right: newVariable(widget.id & ".right"),
    top: newVariable(widget.id & ".top"),
    bottom: newVariable(widget.id & ".bottom"),
    width: newVariable(widget.id & ".width"),
    height: newVariable(widget.id & ".height"),
    centerX: newVariable(widget.id & ".centerX"),
    centerY: newVariable(widget.id & ".centerY")
  )

  # Add basic constraints
  # width = right - left
  cs.solver.addConstraint(vars.width == vars.right - vars.left)
  # height = bottom - top
  cs.solver.addConstraint(vars.height == vars.bottom - vars.top)
  # centerX = left + width/2
  cs.solver.addConstraint(vars.centerX == vars.left + vars.width / 2)
  # centerY = top + height/2
  cs.solver.addConstraint(vars.centerY == vars.top + vars.height / 2)

  cs.variables[widget.id] = vars
  cs.widgets[widget.id] = widget
  cs.dirty = true

proc addConstraint*(cs: ConstraintSystem, c: LayoutConstraint) =
  cs.solver.addConstraint(c.expr, c.strength.float)
  cs.dirty = true

proc solve*(cs: ConstraintSystem) =
  if not cs.dirty:
    return

  cs.solver.updateVariables()

  # Update widget geometries
  for id, widget in cs.widgets:
    let vars = cs.variables[id]
    widget.rect.pos.x = vars.left.value
    widget.rect.pos.y = vars.top.value
    widget.rect.size.width = vars.width.value
    widget.rect.size.height = vars.height.value

  cs.dirty = false

# Helper procs for creating constraints
proc left*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].left)

proc right*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].right)

proc top*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].top)

proc bottom*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].bottom)

proc width*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].width)

proc height*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].height)

proc centerX*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].centerX)

proc centerY*(widget: Widget): Expression =
  result = Expression(cs.variables[widget.id].centerY)

# Constraint builders
proc eq*(left, right: Expression, strength = csRequired): LayoutConstraint =
  LayoutConstraint(expr: left == right, strength: strength)

proc leq*(left, right: Expression, strength = csRequired): LayoutConstraint =
  LayoutConstraint(expr: left <= right, strength: strength)

proc geq*(left, right: Expression, strength = csRequired): LayoutConstraint =
  LayoutConstraint(expr: left >= right, strength: strength)

# High-level constraint helpers
proc centerInParent*(cs: ConstraintSystem, widget: Widget, parent: Widget) =
  cs.addConstraint(eq(widget.centerX, parent.centerX))
  cs.addConstraint(eq(widget.centerY, parent.centerY))

proc alignLeft*(cs: ConstraintSystem, widget: Widget, to: Widget, offset = 0.0) =
  cs.addConstraint(eq(widget.left, to.left + offset))

proc alignRight*(cs: ConstraintSystem, widget: Widget, to: Widget, offset = 0.0) =
  cs.addConstraint(eq(widget.right, to.right - offset))

proc alignTop*(cs: ConstraintSystem, widget: Widget, to: Widget, offset = 0.0) =
  cs.addConstraint(eq(widget.top, to.top + offset))

proc alignBottom*(cs: ConstraintSystem, widget: Widget, to: Widget, offset = 0.0) =
  cs.addConstraint(eq(widget.bottom, to.bottom - offset))

proc setWidth*(cs: ConstraintSystem, widget: Widget, width: float) =
  cs.addConstraint(eq(widget.width, width))

proc setHeight*(cs: ConstraintSystem, widget: Widget, height: float) =
  cs.addConstraint(eq(widget.height, height))

proc setSize*(cs: ConstraintSystem, widget: Widget, width, height: float) =
  setWidth(cs, widget, width)
  setHeight(cs, widget, height)

proc setPercentWidth*(cs: ConstraintSystem, widget: Widget, parent: Widget, percent: float) =
  cs.addConstraint(eq(widget.width, parent.width * (percent / 100.0)))

proc setPercentHeight*(cs: ConstraintSystem, widget: Widget, parent: Widget, percent: float) =
  cs.addConstraint(eq(widget.height, parent.height * (percent / 100.0)))

# Animation support
type
  ConstraintAnimation* = object
    startValue, endValue: float
    duration: float
    elapsed: float
    variable: Variable
    easing: proc(t: float): float

proc animate*(cs: ConstraintSystem, anim: var ConstraintAnimation, dt: float): bool =
  anim.elapsed += dt
  if anim.elapsed >= anim.duration:
    anim.variable.value = anim.endValue
    result = true
  else:
    let t = anim.elapsed / anim.duration
    let easedT = anim.easing(t)
    anim.variable.value = lerp(anim.startValue, anim.endValue, easedT)
    result = false
  cs.dirty = true

# Example usage:
when isMainModule:
  let cs = newConstraintSystem()

  let parent = Widget(id: "parent")
  let child = Widget(id: "child")

  cs.addWidget(parent)
  cs.addWidget(child)

  # Center child in parent with 80% width
  cs.centerInParent(child, parent)
  cs.setPercentWidth(child, parent, 80.0)
  cs.setHeight(child, 100.0)

  # Add margin constraints
  cs.addConstraint(geq(child.left, parent.left + 10))
  cs.addConstraint(geq(parent.right - 10, child.right))

  # Solve and apply
  cs.solve()
