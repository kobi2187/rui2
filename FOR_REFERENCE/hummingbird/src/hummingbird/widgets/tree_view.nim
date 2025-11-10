
# Tree view widget with collapsible nodes
defineWidget TreeView:
  props:
    rootNode: TreeNode
    selected: string  # Selected node id
    onSelect: proc(nodeId: string)
    onExpand: proc(nodeId: string)
    onCollapse: proc(nodeId: string)
    indent: float32 = 20.0

  type TreeNode* = ref object
    id*: string
    text*: string
    icon*: Option[Icon]
    expanded*: bool
    children*: seq[TreeNode]
    data*: JsonNode  # Custom data

  render:
    proc drawNode(node: TreeNode, x, y: float32, level: int): float32 =
      let nodeRect = Rectangle(
        x: x + level.float32 * widget.indent,
        y: y,
        width: widget.rect.width - (level.float32 * widget.indent),
        height: 24  # Node height
      )

      # Draw expand/collapse if has children
      if node.children.len > 0:
        if GuiButton(
          Rectangle(x: nodeRect.x - 16, y: nodeRect.y + 4, width: 16, height: 16),
          if node.expanded: "-" else: "+"
        ):
          node.expanded = not node.expanded
          if node.expanded and widget.onExpand != nil:
            widget.onExpand(node.id)
          elif not node.expanded and widget.onCollapse != nil:
            widget.onCollapse(node.id)

      # Draw node text/icon
      let isSelected = node.id == widget.selected
      if GuiButton(nodeRect, node.text, isSelected):
        widget.selected = node.id
        if widget.onSelect != nil:
          widget.onSelect(node.id)

      var nextY = y + 24

      # Draw children if expanded
      if node.expanded:
        for child in node.children:
          nextY = drawNode(child, x, nextY, level + 1)

      result = nextY

    # Start drawing from root
    discard drawNode(widget.rootNode, widget.rect.x, widget.rect.y, 0)
