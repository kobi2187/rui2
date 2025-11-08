type
  Widget = ref object
    id: string
    rect: Rect
    # ... other fields

  Rect = object
    x, y, width, height: float

  Interval[T] = object
    start, fin: float
    data: T

  IntervalNode[T] = ref object
    interval: Interval[T]
    maxEnd: float
    left, right: IntervalNode[T]

  IntervalTree[T] = ref object
    root: IntervalNode[T]

  HitTestSystem* = object
    xTree, yTree: IntervalTree[Widget]

proc newIntervalTree[T](): IntervalTree[T] =
  new(result)

proc newHitTestSystem*(): HitTestSystem =
  result.xTree = newIntervalTree[Widget]()
  result.yTree = newIntervalTree[Widget]()

proc clear*(tree: var IntervalTree) =
  tree.root = nil

proc insert[T](tree: var IntervalTree[T], start, fin: float, data: T) =
  proc insertNode(node: var IntervalNode[T], interval: Interval[T]): IntervalNode[T] =
    if node == nil:
      result = IntervalNode[T](interval: interval, maxEnd: interval.fin)
    else:
      if interval.start < node.interval.start:
        node.left = insertNode(node.left, interval)
      else:
        node.right = insertNode(node.right, interval)
      node.maxEnd = max(node.maxEnd, interval.fin)
      result = node

  let interval = Interval[T](start: start, fin: fin, data: data)
  tree.root = insertNode(tree.root, interval)

proc remove[T](tree: var IntervalTree[T], start, fin: float, data: T) =
  proc removeNode(node: var IntervalNode[T], start, fin: float, data: T): IntervalNode[T] =
    if node == nil:
      return nil

    if start == node.interval.start and fin == node.interval.fin and node.interval.data == data:
      if node.left == nil: return node.right
      if node.right == nil: return node.left
      
      var temp = node.right
      while temp.left != nil:
        temp = temp.left
      
      node.interval = temp.interval
      node.right = removeNode(node.right, temp.interval.start, temp.interval.fin, temp.interval.data)
    elif start < node.interval.start:
      node.left = removeNode(node.left, start, fin, data)
    else:
      node.right = removeNode(node.right, start, fin, data)
    
    if node != nil:
      node.maxEnd = node.interval.fin
      if node.left != nil: node.maxEnd = max(node.maxEnd, node.left.maxEnd)
      if node.right != nil: node.maxEnd = max(node.maxEnd, node.right.maxEnd)
    
    result = node

  tree.root = removeNode(tree.root, start, fin, data)

proc queryPoint[T](tree: IntervalTree[T], point: float): seq[T] =
  result = @[]
  
  proc search(node: IntervalNode[T]) =
    if node == nil: return
    
    if node.interval.start <= point and point <= node.interval.fin:
      result.add(node.interval.data)
    
    if node.left != nil and node.left.maxEnd >= point:
      search(node.left)
    
    if node.right != nil and node.interval.start <= point:
      search(node.right)
  
  search(tree.root)

# HitTestSystem operations
proc clear*(system: var HitTestSystem) =
  system.xTree.clear()
  system.yTree.clear()

proc rebuildTree*(system: var HitTestSystem, widgets: openArray[Widget]) =
  system.clear()
  for widget in widgets:
    let r = widget.rect
    system.xTree.insert(r.x, r.x + r.width, widget)
    system.yTree.insert(r.y, r.y + r.height, widget)

proc updateWidgets*(system: var HitTestSystem, widgets: openArray[Widget]) =
  # For small updates
  for widget in widgets:
    let r = widget.rect
    system.xTree.insert(r.x, r.x + r.width, widget)
    system.yTree.insert(r.y, r.y + r.height, widget)

proc removeWidget*(system: var HitTestSystem, widget: Widget) =
  let r = widget.rect
  system.xTree.remove(r.x, r.x + r.width, widget)
  system.yTree.remove(r.y, r.y + r.height, widget)

proc findWidgetsAt*(system: HitTestSystem, x, y: float): seq[Widget] =
  # Get candidates from both trees
  let xCandidates = system.xTree.queryPoint(x)
  let yCandidates = system.yTree.queryPoint(y)
  
  # Find intersection using hash set for efficiency
  result = @[]
  var ySet = initHashSet[Widget]()
  for widget in yCandidates:
    ySet.incl(widget)
  
  for widget in xCandidates:
    if widget in ySet:
      result.add(widget)