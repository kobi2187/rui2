## The tree model: nodes, the flattening pass, and where a row's twisty sits.
##
## Split out of treeview.nim. A TreeView draws a *list*, not a tree -- the
## expanded part of the tree is walked depth-first into a flat seq once per
## layout, and everything after that (the row viewport, the hit-testing, the
## drawing) indexes that seq. Which is what lets a tree of any depth scroll
## with the same arithmetic as a table.
##
## None of this needs a widget or a window.

import std/json

type
  TreeNode* = ref object
    id*: string
    text*: string
    icon*: string                # Icon glyph (e.g. a folder or file character)
    expanded*: bool
    children*: seq[TreeNode]
    data*: JsonNode              # Custom payload
    level*: int                  # Depth, filled in by the flatten pass

  FlatNode* = object
    node*: TreeNode
    level*: int

const
  BufferNodes* = 5
    ## Rows rendered above and below the viewport, so a fast scroll does not
    ## show a blank strip before the next layout catches up.
  TwistyWidth* = 16.0'f32

proc twistyX*(flat: FlatNode, originX, indent: float32): float32 =
  ## Left edge of the expand/collapse triangle for this row, which sits one
  ## indent step in per level of depth.
  originX + float32(flat.level) * indent

proc hitsTwisty*(flat: FlatNode, mouseX, originX, indent: float32): bool =
  ## Only a branch has a twisty, so a leaf never claims the click.
  if flat.node.children.len == 0:
    return false
  let left = flat.twistyX(originX, indent)
  mouseX >= left and mouseX < left + TwistyWidth


proc flatten*(node: TreeNode, level: int, dest: var seq[FlatNode]) =
  ## Depth-first walk of the expanded part of the tree.
  if node == nil:
    return
  node.level = level
  dest.add(FlatNode(node: node, level: level))
  if node.expanded:
    for child in node.children:
      flatten(child, level + 1, dest)

