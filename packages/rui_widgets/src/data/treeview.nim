## TreeView Widget - RUI2
##
## Hierarchical tree with expand/collapse, selection and virtual scrolling, so
## a tree with thousands of nodes only ever draws the rows on screen.
##
## The flattening pass runs in `layout`, not in `render`. Rendering has to stay
## a pure draw: it happens inside a render texture with `bounds` zeroed, and the
## hit-testing in the event handlers needs the same flat list the paint used.

import rui_core
import rui_drawing
import ../virtual_rows
import std/[options, json]

export virtual_rows

import raylib

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
  BufferNodes = 5
  TwistyWidth = 16.0'f32

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

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the TreeView type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = widget.nodeHeight, scrollY = widget.scrollY)

proc flatten*(node: TreeNode, level: int, dest: var seq[FlatNode]) =
  ## Depth-first walk of the expanded part of the tree.
  if node == nil:
    return
  node.level = level
  dest.add(FlatNode(node: node, level: level))
  if node.expanded:
    for child in node.children:
      flatten(child, level + 1, dest)

definePrimitive(TreeView):
  props:
    rootNode: TreeNode = nil
    nodeHeight: float32 = 24.0
    indent: float32 = 20.0
    showIcons: bool = true
    visibleRows: int = 10
    intent: ThemeIntent = Default

  state:
    selectedId: string
    hoveredId: string            # Not `hovered`: Widget already has that (a bool)
    flatNodes: seq[FlatNode]
    scrollY: float32
    visibleStart: int
    visibleEnd: int

  actions:
    onSelect(nodeId: string)
    onExpand(nodeId: string)
    onCollapse(nodeId: string)

  events:
    on_mouse_down:
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.flatNodes.len)
      if idx < 0:
        return false

      let flat = widget.flatNodes[idx]

      # Clicking the twisty toggles; clicking anywhere else on the row selects.
      if flat.hitsTwisty(event.mousePos.x, widget.bounds.x, widget.indent):
        flat.node.expanded = not flat.node.expanded
        widget.isDirty = true
        widget.layoutDirty = true   # the flat list just changed length
        if flat.node.expanded:
          if widget.onExpand.isSome: widget.onExpand.get()(flat.node.id)
        else:
          if widget.onCollapse.isSome: widget.onCollapse.get()(flat.node.id)
        return true

      if widget.selectedId != flat.node.id:
        widget.selectedId = flat.node.id
        widget.isDirty = true
        if widget.onSelect.isSome:
          widget.onSelect.get()(flat.node.id)
      return true

    on_mouse_move:
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.flatNodes.len)
      let newHover = if idx >= 0: widget.flatNodes[idx].node.id else: ""
      if newHover != widget.hoveredId:
        widget.hoveredId = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let newScroll = viewportOf(widget).scrolledBy(event.wheelDelta,
                                                    widget.flatNodes.len)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true
      return true

  layout:
    # Re-flatten: this is the only place the visible row list is built.
    widget.flatNodes.setLen(0)
    flatten(widget.rootNode, 0, widget.flatNodes)

    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.visibleRows) * widget.nodeHeight
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var widest = 0.0'f32
      for flat in widget.flatNodes:
        let rowWidth = float32(flat.level) * widget.indent + TwistyWidth +
                       measureText(flat.node.text, style).width
        widest = max(widest, rowWidth)
      widget.bounds.width = widest + 24.0

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let nodeH = widget.nodeHeight
    let v = viewportOf(widget)

    let visible = v.visibleRange(widget.flatNodes.len, buffer = BufferNodes)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    drawThemedBackground(widget.bounds, props)

    let fgColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    let clip = beginClip(widget.bounds)

    for i in visible:
      let flat = widget.flatNodes[i]
      let rowY = v.rowTop(i)

      let rowRect = Rect(x: widget.bounds.x, y: rowY,
                         width: widget.bounds.width, height: nodeH)
      drawSelectionBackground(rowRect, props,
                              selected = flat.node.id == widget.selectedId,
                              hovered = flat.node.id == widget.hoveredId)

      var x = flat.twistyX(widget.bounds.x, widget.indent)

      # Twisty: only branches get one.
      if flat.node.children.len > 0:
        if flat.node.expanded:
          drawDownArrow(x + TwistyWidth / 2, rowY + nodeH / 2, 5.0, fgColor)
        else:
          drawRightArrow(x + TwistyWidth / 2, rowY + nodeH / 2, 5.0, fgColor)
      x += TwistyWidth

      if widget.showIcons and flat.node.icon.len > 0:
        drawText(flat.node.icon, x, rowY + (nodeH - 14.0) / 2, 14.0, fgColor)
        x += 18.0

      drawText(flat.node.text, x, rowY + (nodeH - 14.0) / 2, 14.0, fgColor)

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)
