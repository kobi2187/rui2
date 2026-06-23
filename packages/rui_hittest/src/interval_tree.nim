## Interval Tree Implementation
##
## AVL-balanced interval tree for efficient spatial queries.
## Supports O(log n) insert, remove, and query operations.
##
## Used for hit-testing in the RUI framework.

import std/[algorithm, sequtils]

type
  Interval*[T] = object
    ## Represents an interval [start, fin] with associated data
    start*, fin*: float32
    data*: T

  IntervalNode[T] = ref object
    ## Internal node of the interval tree
    interval: Interval[T]
    maxEnd: float32              # Max end value in this subtree
    height: int                  # Height for AVL balancing
    left, right: IntervalNode[T]

  IntervalTree*[T] = ref object
    ## AVL-balanced interval tree
    root: IntervalNode[T]
    size: int                    # Number of intervals in tree

  IntervalError* = object of CatchableError

# ============================================================================
# Helper Functions
# ============================================================================

proc newInterval*[T](start, fin: float32, data: T): Interval[T] =
  ## Create a new interval. Validates that start <= fin.
  if start > fin:
    raise newException(IntervalError, "Invalid interval: start must be <= fin")
  result = Interval[T](start: start, fin: fin, data: data)

proc height[T](node: IntervalNode[T]): int =
  ## Get height of a node (nil nodes have height 0)
  if node == nil: 0 else: node.height

proc balanceFactor[T](node: IntervalNode[T]): int =
  ## Calculate balance factor (left height - right height)
  if node == nil: 0
  else: height(node.left) - height(node.right)

proc updateHeight[T](node: IntervalNode[T]) =
  ## Update the height of a node based on its children
  if node != nil:
    node.height = 1 + max(height(node.left), height(node.right))

proc updateMaxEnd[T](node: IntervalNode[T]) =
  ## Update the maxEnd value for this node based on its subtree
  if node != nil:
    node.maxEnd = node.interval.fin
    if node.left != nil:
      node.maxEnd = max(node.maxEnd, node.left.maxEnd)
    if node.right != nil:
      node.maxEnd = max(node.maxEnd, node.right.maxEnd)

# ============================================================================
# AVL Rotation Operations
# ============================================================================

proc rotateRight[T](y: IntervalNode[T]): IntervalNode[T] =
  ## Perform right rotation on node y
  if y == nil or y.left == nil:
    return y

  let x = y.left
  let T2 = x.right

  # Perform rotation
  x.right = y
  y.left = T2

  # Update heights and maxEnd
  updateHeight(y)
  updateHeight(x)
  updateMaxEnd(y)
  updateMaxEnd(x)

  return x

proc rotateLeft[T](x: IntervalNode[T]): IntervalNode[T] =
  ## Perform left rotation on node x
  if x == nil or x.right == nil:
    return x

  let y = x.right
  let T2 = y.left

  # Perform rotation
  y.left = x
  x.right = T2

  # Update heights and maxEnd
  updateHeight(x)
  updateHeight(y)
  updateMaxEnd(x)
  updateMaxEnd(y)

  return y

# ============================================================================
# Insert Operation
# ============================================================================

proc insertNode[T](node: var IntervalNode[T], interval: Interval[T]): IntervalNode[T] =
  ## Insert an interval into the tree with AVL balancing

  # Standard BST insertion
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

  # Update height and maxEnd
  updateHeight(node)
  updateMaxEnd(node)

  # Get balance factor
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

proc insert*[T](tree: var IntervalTree[T], start, fin: float32, data: T) =
  ## Insert an interval [start, fin] with associated data into the tree
  let interval = newInterval(start, fin, data)
  if tree == nil:
    tree = IntervalTree[T]()
  tree.root = insertNode(tree.root, interval)
  inc tree.size

# ============================================================================
# Remove Operation
# ============================================================================

proc minValueNode[T](node: IntervalNode[T]): IntervalNode[T] =
  ## Find the node with minimum start value in the tree
  if node == nil or node.left == nil:
    return node
  return minValueNode(node.left)

proc removeNode[T](node: var IntervalNode[T], interval: Interval[T]): IntervalNode[T] =
  ## Remove an interval from the tree with AVL balancing

  if node == nil:
    return nil

  # Standard BST deletion
  if interval.start < node.interval.start:
    node.left = removeNode(node.left, interval)
  elif interval.start > node.interval.start:
    node.right = removeNode(node.right, interval)
  else:
    # Found node with matching start - check fin to be sure
    if interval.fin != node.interval.fin:
      node.right = removeNode(node.right, interval)
    else:
      # This is the node to delete
      if node.left == nil:
        return node.right
      elif node.right == nil:
        return node.left

      # Node with two children: get inorder successor
      let temp = minValueNode(node.right)
      node.interval = temp.interval
      node.right = removeNode(node.right, temp.interval)

  if node == nil:
    return nil

  # Update height and maxEnd
  updateHeight(node)
  updateMaxEnd(node)

  # Get balance factor
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

proc remove*[T](tree: var IntervalTree[T], start, fin: float32) =
  ## Remove an interval [start, fin] from the tree
  if tree == nil:
    raise newException(IntervalError, "Cannot remove from nil tree")
  let interval = Interval[T](start: start, fin: fin)
  tree.root = removeNode(tree.root, interval)
  dec tree.size

# ============================================================================
# Query Operations
# ============================================================================

proc queryNode[T](node: IntervalNode[T], point: float32, result: var seq[T]) =
  ## Query for all intervals containing a point (recursive helper)
  if node == nil:
    return

  # Check if current interval contains the point
  if node.interval.start <= point and node.interval.fin >= point:
    result.add(node.interval.data)

  # Check left subtree only if it could contain the point
  if node.left != nil and node.left.maxEnd >= point:
    queryNode(node.left, point, result)

  # Check right subtree only if point is >= current start
  if node.right != nil and point >= node.interval.start:
    queryNode(node.right, point, result)

proc query*[T](tree: IntervalTree[T], point: float32): seq[T] =
  ## Query for all intervals containing the given point
  ## Returns a sequence of data elements whose intervals contain the point
  result = @[]
  if tree == nil or tree.root == nil:
    return
  queryNode(tree.root, point, result)

proc findOverlapsNode[T](node: IntervalNode[T], interval: Interval[T], result: var seq[T]) =
  ## Find all intervals that overlap with the given interval (recursive helper)
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

proc findOverlaps*[T](tree: IntervalTree[T], start, fin: float32): seq[T] =
  ## Find all intervals that overlap with [start, fin]
  ## Two intervals [a1, a2] and [b1, b2] overlap if a1 <= b2 and b1 <= a2
  result = @[]
  if tree == nil or tree.root == nil:
    return
  let interval = Interval[T](start: start, fin: fin)
  findOverlapsNode(tree.root, interval, result)

# ============================================================================
# Utility Functions
# ============================================================================

proc len*[T](tree: IntervalTree[T]): int =
  ## Return the number of intervals in the tree
  if tree == nil: 0 else: tree.size

proc isEmpty*[T](tree: IntervalTree[T]): bool =
  ## Check if the tree is empty
  tree == nil or tree.root == nil

proc clear*[T](tree: var IntervalTree[T]) =
  ## Clear all intervals from the tree
  if tree != nil:
    tree.root = nil
    tree.size = 0

proc newIntervalTree*[T](): IntervalTree[T] =
  ## Create a new empty interval tree
  result = IntervalTree[T](root: nil, size: 0)

# ============================================================================
# Debug/Testing Functions
# ============================================================================

proc inOrderTraversal[T](node: IntervalNode[T], result: var seq[Interval[T]]) =
  ## In-order traversal of the tree (for testing/debugging)
  if node == nil:
    return
  inOrderTraversal(node.left, result)
  result.add(node.interval)
  inOrderTraversal(node.right, result)

proc toSeq*[T](tree: IntervalTree[T]): seq[Interval[T]] =
  ## Convert tree to sequence of intervals (in-order)
  result = @[]
  if tree != nil and tree.root != nil:
    inOrderTraversal(tree.root, result)

proc verifyAVL[T](node: IntervalNode[T]): bool =
  ## Verify that the tree maintains AVL property (for testing)
  if node == nil:
    return true

  let balance = balanceFactor(node)
  if abs(balance) > 1:
    return false

  return verifyAVL(node.left) and verifyAVL(node.right)

proc isBalanced*[T](tree: IntervalTree[T]): bool =
  ## Check if the tree is properly balanced
  if tree == nil or tree.root == nil:
    return true
  return verifyAVL(tree.root)
