# Internally just uses VStack with indentation
proc drawTreeNode(node: TreeNode, level: int) =
  HStack:
    # Indentation
    Spacing(width = level * 20)
    
    # Expand/Collapse arrow
    if node.hasChildren:
      Button(icon = if node.expanded: DownArrow else: RightArrow)
    
    # Node content
    Label(text = node.text)

  # Children (if expanded)
  if node.expanded:
    for child in node.children:
      drawTreeNode(child, level + 1)