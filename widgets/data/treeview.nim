## TreeView Widget - RUI2
##
## Hierarchical tree view with virtual scrolling for large datasets.
## Supports expand/collapse, selection, and custom node data.
## Uses virtual scrolling to efficiently handle thousands of nodes.

import ../../core/widget_dsl
import std/[options, sets, json]

when defined(useGraphics):
  import raylib

type
  TreeNode* = ref object
    id*: string
    text*: string
    icon*: string                # Icon text (e.g., "📁", "📄")
    expanded*: bool
    children*: seq[TreeNode]
    data*: JsonNode              # Custom data attached to node
    level*: int                  # Depth level (computed)

  FlatNode = object
    node: TreeNode
    level: int
    index: int                   # Index in flattened list

defineWidget(TreeView):
  props:
    rootNode: TreeNode
    nodeHeight: float = 24.0
    indent: float = 20.0
    showIcons: bool = true
    showLines: bool = true
    lineColor: Color = Color(r: 200, g: 200, b: 200, a: 255)

  state:
    selected: string             # Selected node ID
    hovered: string              # Hovered node ID
    flatNodes: seq[FlatNode]     # Flattened visible nodes (for virtual scrolling)
    scrollY: float               # Scroll offset
    visibleStart: int            # First visible node index
    visibleEnd: int              # Last visible node index

  actions:
    onSelect(nodeId: string)
    onExpand(nodeId: string)
    onCollapse(nodeId: string)
    onDoubleClick(nodeId: string)

  layout:
    # No children to layout - draws nodes directly
    discard

  render:
    when defined(useGraphics):
      # Flatten tree to visible nodes for virtual scrolling
      var flatList: seq[FlatNode] = @[]

      proc flattenNode(node: TreeNode, level: int, idx: var int) =
        flatList.add(FlatNode(node: node, level: level, index: idx))
        inc idx

        if node.expanded:
          for child in node.children:
            flattenNode(child, level + 1, idx)

      var idx = 0
      flattenNode(widget.rootNode, 0, idx)
      widget.flatNodes = flatList

      # Calculate visible range (virtual scrolling)
      let scroll = widget.scrollY
      let viewHeight = widget.bounds.height
      let nodeH = widget.nodeHeight

      let totalHeight = flatList.len.float * nodeH
      let maxScroll = max(0.0, totalHeight - viewHeight)

      # Compute visible range with small buffer
      let bufferNodes = 5  # Render a few extra nodes above/below viewport
      let visStart = max(0, int(scroll / nodeH) - bufferNodes)
      let visEnd = min(flatList.len - 1, int((scroll + viewHeight) / nodeH) + bufferNodes)

      widget.visibleStart = visStart
      widget.visibleEnd = visEnd

      # Draw background
      DrawRectangleRec(
        widget.bounds,
        Color(r: 255, g: 255, b: 255, a: 255)
      )

      # Begin scissor mode for clipping
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      # Get mouse state for hover detection
      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
      var newHovered = ""

      # Draw only visible nodes (virtual scrolling optimization)
      for i in visStart..visEnd:
        let flatNode = flatList[i]
        let node = flatNode.node
        let level = flatNode.level

        # Calculate y position with scroll offset
        let nodeY = widget.bounds.y + (i.float * nodeH) - scroll

        # Skip if completely outside bounds
        if nodeY + nodeH < widget.bounds.y or nodeY > widget.bounds.y + viewHeight:
          continue

        let nodeX = widget.bounds.x + (level.float * widget.indent)
        let nodeW = widget.bounds.width - (level.float * widget.indent)

        let nodeRect = Rectangle(
          x: nodeX,
          y: nodeY,
          width: nodeW,
          height: nodeH
        )

        # Check hover
        if mouseInBounds and CheckCollisionPointRec(mousePos, nodeRect):
          newHovered = node.id

        # Draw selection highlight
        let isSelected = node.id == widget.selected
        let isHovered = node.id == widget.hovered

        if isSelected:
          DrawRectangleRec(nodeRect, Color(r: 100, g: 150, b: 255, a: 100))
        elif isHovered:
          DrawRectangleRec(nodeRect, Color(r: 230, g: 240, b: 255, a: 255))

        # Draw tree lines (optional)
        if widget.showLines and level > 0:
          let lineX = nodeX - widget.indent / 2.0
          DrawLineEx(
            Vector2(x: lineX, y: nodeY),
            Vector2(x: lineX, y: nodeY + nodeH / 2.0),
            1.0,
            widget.lineColor
          )
          DrawLineEx(
            Vector2(x: lineX, y: nodeY + nodeH / 2.0),
            Vector2(x: nodeX, y: nodeY + nodeH / 2.0),
            1.0,
            widget.lineColor
          )

        var textX = nodeX + 4.0

        # Draw expand/collapse button if has children
        if node.children.len > 0:
          let expandRect = Rectangle(
            x: nodeX - 16.0,
            y: nodeY + 4.0,
            width: 16.0,
            height: 16.0
          )

          let expandIcon = if node.expanded: "[-]" else: "[+]"
          DrawText(
            expandIcon.cstring,
            expandRect.x.cint,
            expandRect.y.cint,
            10,
            Color(r: 80, g: 80, b: 80, a: 255)
          )

          # Check click on expand button
          if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
            if CheckCollisionPointRec(mousePos, expandRect):
              node.expanded = not node.expanded
              if node.expanded:
                if widget.onExpand.isSome:
                  widget.onExpand.get()(node.id)
              else:
                if widget.onCollapse.isSome:
                  widget.onCollapse.get()(node.id)

        # Draw icon
        if widget.showIcons and node.icon.len > 0:
          DrawText(
            node.icon.cstring,
            textX.cint,
            (nodeY + 4.0).cint,
            12,
            Color(r: 60, g: 60, b: 60, a: 255)
          )
          textX += 20.0

        # Draw node text
        DrawText(
          node.text.cstring,
          textX.cint,
          (nodeY + 6.0).cint,
          12,
          Color(r: 40, g: 40, b: 40, a: 255)
        )

        # Handle node click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, nodeRect):
            widget.selected = node.id
            if widget.onSelect.isSome:
              widget.onSelect.get()(node.id)

        # Handle double click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, nodeRect):
            # Simple double-click detection (in real impl, track time)
            if widget.onDoubleClick.isSome:
              widget.onDoubleClick.get()(node.id)

      widget.hovered = newHovered

      EndScissorMode()

      # Draw scrollbar if needed
      if totalHeight > viewHeight:
        let scrollbarW = 12.0
        let scrollbarRect = Rectangle(
          x: widget.bounds.x + widget.bounds.width - scrollbarW,
          y: widget.bounds.y,
          width: scrollbarW,
          height: viewHeight
        )

        # Scrollbar track
        DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

        # Scrollbar thumb
        let thumbHeight = max(20.0, viewHeight * (viewHeight / totalHeight))
        let thumbY = widget.bounds.y + (scroll / maxScroll) * (viewHeight - thumbHeight)

        let thumbRect = Rectangle(
          x: scrollbarRect.x + 2.0,
          y: thumbY,
          width: scrollbarW - 4.0,
          height: thumbHeight
        )

        DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

        # Handle scrollbar dragging
        if mouseInBounds and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, scrollbarRect):
            let newScroll = ((mousePos.y - widget.bounds.y) / viewHeight) * maxScroll
            widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Handle mouse wheel scrolling
      if mouseInBounds:
        let wheel = GetMouseWheelMove()
        if wheel != 0.0:
          let newScroll = widget.scrollY - (wheel * nodeH * 3.0)
          widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Draw border
      DrawRectangleLinesEx(
        widget.bounds,
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

    else:
      # Non-graphics mode - simple text output
      proc printNode(node: TreeNode, level: int) =
        let indent = "  ".repeat(level)
        let marker = if node.id == widget.selected: "[X]" else: "[ ]"
        let expandIcon = if node.children.len > 0:
                          (if node.expanded: "[-]" else: "[+]")
                        else: "   "
        echo indent, expandIcon, " ", marker, " ", node.icon, " ", node.text

        if node.expanded:
          for child in node.children:
            printNode(child, level + 1)

      echo "TreeView:"
      printNode(widget.rootNode, 0)
      echo "  Visible nodes: ", widget.visibleStart, " to ", widget.visibleEnd
      echo "  Total nodes: ", widget.flatNodes.len
