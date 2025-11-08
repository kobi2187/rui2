type
  Rect = object
    x, y, w, h: float  # Rectangle properties

  Widget = ref object
    rect: Rect
    id: string  # Widget identifier

# Initialize the tree
var xTree: IntervalTree[Widget] = nil
var yTree: IntervalTree[Widget] = nil

# Populate the tree
proc recreateTree[T](tree: var IntervalTree[T], widgets: seq[T], getInterval: proc(w: T): Interval[T]) =
  tree = nil  # Reset the tree
  for widget in widgets:
    insert(tree, getInterval(widget))

# Example usage
recreateTree(xTree, widgets, proc(w: Widget): Interval[Widget] = 
  Interval(start: w.rect.x, finish: w.rect.x + w.rect.w, data: w))
recreateTree(yTree, widgets, proc(w: Widget): Interval[Widget] = 
  Interval(start: w.rect.y, finish: w.rect.y + w.rect.h, data: w))

# Query for a point
let hitWidgets = query(xTree, 55.0)
for widget in hitWidgets:
  echo "Hit: ", widget.id
