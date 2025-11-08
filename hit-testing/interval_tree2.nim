type
  Interval[T] = object
    start, fin: float  # Start and end of the interval
    data: T            # Generic data

  IntervalNode[T] = ref object
    interval: Interval[T]     # The interval this node represents
    maxEnd: float            # Maximum 'end' value in this subtree
    height: int              # Height of the node for AVL balancing
    left, right: IntervalNode[T]

  IntervalTree[T] = ref object
    root: IntervalNode[T]

  IntervalError = object of Exception

proc newInterval[T](start, fin: float, data: T): Interval[T] =
  if start > fin:
    raise newException(IntervalError, "Invalid interval: start must be <= end")
  result = Interval[T](start: start, fin: fin, data: data)

proc height[T](node: IntervalNode[T]): int =
  if node == nil: 0 else: node.height

proc balanceFactor[T](node: IntervalNode[T]): int =
  if node == nil: 0
  else: height(node.left) - height(node.right)

proc updateHeight[T](node: IntervalNode[T]) =
  if node != nil:
    node.height = 1 + max(height(node.left), height(node.right))

proc updateMaxEnd[T](node: IntervalNode[T]) =
  if node != nil:
    node.maxEnd = node.interval.fin
    if node.left != nil:
      node.maxEnd = max(node.maxEnd, node.left.maxEnd)
    if node.right != nil:
      node.maxEnd = max(node.maxEnd, node.right.maxEnd)

proc rotateRight[T](y: IntervalNode[T]): IntervalNode[T] =
  if y == nil or y.left == nil: return y
  let x = y.left
  let T2 = x.right

  x.right = y
  y.left = T2

  updateHeight(y)
  updateHeight(x)
  updateMaxEnd(y)
  updateMaxEnd(x)

  return x

proc rotateLeft[T](x: IntervalNode[T]): IntervalNode[T] =
  if x == nil or x.right == nil: return x
  let y = x.right
  let T2 = y.left

  y.left = x
  x.right = T2

  updateHeight(x)
  updateHeight(y)
  updateMaxEnd(x)
  updateMaxEnd(y)

  return y

proc insertNode[T](node: var IntervalNode[T], interval: Interval[T]): IntervalNode[T] =
  # Insert with AVL balancing
  if node == nil:
    result = IntervalNode[T](
      interval: interval,
      maxEnd: interval.fin,
      height: 1
    )
    return

  if interval.start < node.interval.start:
    node.left = insertNode(node.left, interval)
  else:
    node.right = insertNode(node.right, interval)

  updateHeight(node)
  updateMaxEnd(node)

  let balance = balanceFactor(node)

  # Left Left Case
  if balance > 1 and interval.start < node.left.interval.start:
    return rotateRight(node)

  # Right Right Case
  if balance < -1 and interval.start >= node.right.interval.start:
    return rotateLeft(node)

  # Left Right Case
  if balance > 1 and interval.start >= node.left.interval.start:
    node.left = rotateLeft(node.left)
    return rotateRight(node)

  # Right Left Case
  if balance < -1 and interval.start < node.right.interval.start:
    node.right = rotateRight(node.right)
    return rotateLeft(node)

  return node

proc insert*[T](tree: var IntervalTree[T], start, fin: float, data: T) =
  let interval = newInterval(start, fin, data)
  if tree == nil:
    tree = IntervalTree[T]()
  tree.root = insertNode(tree.root, interval)

proc minValueNode[T](node: IntervalNode[T]): IntervalNode[T] =
  if node == nil or node.left == nil:
    return node
  return minValueNode(node.left)

proc removeNode[T](node: var IntervalNode[T], interval: Interval[T]): IntervalNode[T] =
  if node == nil:
    return nil

  if interval.start < node.interval.start:
    node.left = removeNode(node.left, interval)
  elif interval.start > node.interval.start:
    node.right = removeNode(node.right, interval)
  else:
    # Found the node to delete
    if interval.fin != node.interval.fin:
      node.right = removeNode(node.right, interval)
    else:
      # Node with only one child or no child
      if node.left == nil:
        return node.right
      elif node.right == nil:
        return node.left

      # Node with two children
      let temp = minValueNode(node.right)
      node.interval = temp.interval
      node.right = removeNode(node.right, temp.interval)

  if node == nil:
    return nil

  updateHeight(node)
  updateMaxEnd(node)

  let balance = balanceFactor(node)

  # Left Left Case
  if balance > 1 and balanceFactor(node.left) >= 0:
    return rotateRight(node)

  # Left Right Case
  if balance > 1 and balanceFactor(node.left) < 0:
    node.left = rotateLeft(node.left)
    return rotateRight(node)

  # Right Right Case
  if balance < -1 and balanceFactor(node.right) <= 0:
    return rotateLeft(node)

  # Right Left Case
  if balance < -1 and balanceFactor(node.right) > 0:
    node.right = rotateRight(node.right)
    return rotateLeft(node)

  return node

proc remove*[T](tree: var IntervalTree[T], start, fin: float) =
  if tree == nil:
    raise newException(IntervalError, "Tree is nil")
  let interval = Interval[T](start: start, fin: fin)
  tree.root = removeNode(tree.root, interval)

proc queryNode[T](node: IntervalNode[T], point: float, result: var seq[T]) =
  if node == nil:
    return

  # Check current node
  if node.interval.start <= point and node.interval.fin >= point:
    result.add(node.interval.data)

  # Check left subtree only if it could contain point
  if node.left != nil and node.left.maxEnd >= point:
    queryNode(node.left, point, result)

  # Check right subtree only if point is greater than current node's start
  if node.right != nil and point >= node.interval.start:
    queryNode(node.right, point, result)

proc query*[T](tree: IntervalTree[T], point: float): seq[T] =
  result = @[]
  if tree == nil:
    return
  queryNode(tree.root, point, result)

proc findOverlapsNode[T](node: IntervalNode[T], interval: Interval[T], result: var seq[T]) =
  if node == nil:
    return

  # Check if current interval overlaps
  if node.interval.start <= interval.fin and interval.start <= node.interval.fin:
    result.add(node.interval.data)

  # Check left subtree only if it could contain overlaps
  if node.left != nil and node.left.maxEnd >= interval.start:
    findOverlapsNode(node.left, interval, result)

  # Check right subtree if necessary
  if node.right != nil and node.interval.start <= interval.fin:
    findOverlapsNode(node.right, interval, result)

proc findOverlaps*[T](tree: IntervalTree[T], start, fin: float): seq[T] =
  result = @[]
  if tree == nil:
    return
  let interval = Interval[T](start: start, fin: fin)
  findOverlapsNode(tree.root, interval, result)