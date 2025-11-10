# src/quickui/core/types.nim
type
  Point* = object
    x*, y*: float32

  Size* = object
    width*, height*: float32

  Rect* = object
    pos*: Point
    size*: Size

  Widget* = ref object of RootObj
    id*: string
    rect*: Rect
    visible*: bool
    parent*: Widget
    children*: seq[Widget]
    constraints*: WidgetConstraints  # New field
    layoutDirty*: bool              # New field

  WidgetConstraints* = ref object
    left*, right*, top*, bottom*: float32
    width*, height*: float32
    minWidth*, maxWidth*: float32
    minHeight*, maxHeight*: float32
    margin*: EdgeInsets
    padding*: EdgeInsets

  EdgeInsets* = object
    left*, right*, top*, bottom*: float32

# src/quickui/core/widget.nim
import types
import ../layout/constraints

proc updateLayout*(widget: Widget, cs: ConstraintSystem) =
  # Called when widget needs to update its constraints
  if widget.layoutDirty:
    # Update constraints
    cs.setMinSize(widget, widget.constraints.minWidth, widget.constraints.minHeight)
    cs.setMaxSize(widget, widget.constraints.maxWidth, widget.constraints.maxHeight)
    
    # Apply margins
    if widget.parent != nil:
      let m = widget.constraints.margin
      cs.addConstraint(geq(widget.left, widget.parent.left + m.left))
      cs.addConstraint(geq(widget.parent.right - m.right, widget.right))
      cs.addConstraint(geq(widget.top, widget.parent.top + m.top))
      cs.addConstraint(geq(widget.parent.bottom - m.bottom, widget.bottom))
    
    # Update children
    for child in widget.children:
      child.updateLayout(cs)
    
    widget.layoutDirty = false

method layout*(widget: Widget, cs: ConstraintSystem) {.base.} =
  # Override this for custom layout behavior
  updateLayout(widget, cs)

# src/quickui/widgets/button.nim
import ../core/[types, widget]
import ../layout/constraints

type
  Button* = ref object of Widget
    text*: string
    onClick*: proc()

method layout*(button: Button, cs: ConstraintSystem) =
  # Set minimum size based on text
  let textSize = measureText(button.text)
  button.constraints.minWidth = textSize.width + 20  # padding
  button.constraints.minHeight = textSize.height + 10  # padding
  
  # Update layout
  procCall button.Widget.layout(cs)

# src/quickui/widgets/panel.nim
type
  Panel* = ref object of Widget
    background*: Color
    layoutType*: LayoutType

  LayoutType* = enum
    ltVertical, ltHorizontal, ltGrid

method layout*(panel: Panel, cs: ConstraintSystem) =
  # First update base constraints
  procCall panel.Widget.layout(cs)
  
  # Then layout children based on layout type
  case panel.layoutType
  of ltVertical:
    var currentY = panel.top + panel.constraints.padding.top
    for child in panel.children:
      cs.addConstraint(eq(child.top, currentY))
      cs.addConstraint(eq(child.left, panel.left + panel.constraints.padding.left))
      cs.addConstraint(leq(child.right, panel.right - panel.constraints.padding.right))
      
      currentY += child.height + panel.constraints.padding.top

  of ltHorizontal:
    var currentX = panel.left + panel.constraints.padding.left
    for child in panel.children:
      cs.addConstraint(eq(child.left, currentX))
      cs.addConstraint(eq(child.top, panel.top + panel.constraints.padding.top))
      cs.addConstraint(leq(child.bottom, panel.bottom - panel.constraints.padding.bottom))
      
      currentX += child.width + panel.constraints.padding.left

  of ltGrid:
    let columns = 3  # Could be configurable
    let spacing = panel.constraints.padding.left
    let availableWidth = panel.width - panel.constraints.padding.left - panel.constraints.padding.right
    let cellWidth = availableWidth / columns.float32
    
    var row, col = 0
    for child in panel.children:
      let x = panel.left + panel.constraints.padding.left + (col.float32 * (cellWidth + spacing))
      let y = panel.top + panel.constraints.padding.top + (row.float32 * (cellWidth + spacing))
      
      cs.addConstraint(eq(child.left, x))
      cs.addConstraint(eq(child.top, y))
      cs.addConstraint(eq(child.width, cellWidth))
      cs.addConstraint(eq(child.height, cellWidth))  # Square cells
      
      inc col
      if col >= columns:
        col = 0
        inc row

# Example usage:
let window = Panel(
  id: "mainWindow",
  layoutType: ltVertical,
  constraints: WidgetConstraints(
    padding: EdgeInsets(left: 10, right: 10, top: 10, bottom: 10)
  )
)

let toolbar = Panel(
  id: "toolbar",
  layoutType: ltHorizontal,
  constraints: WidgetConstraints(
    height: 40,
    margin: EdgeInsets(bottom: 10)
  )
)

let saveBtn = Button(
  id: "saveButton",
  text: "Save"
)

let loadBtn = Button(
  id: "loadButton",
  text: "Load"
)

toolbar.children.add(saveBtn)
toolbar.children.add(loadBtn)
window.children.add(toolbar)

# Update layout
let cs = newConstraintSystem()
cs.addWidget(window)
window.layout(cs)
cs.solve()