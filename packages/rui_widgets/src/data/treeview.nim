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
import ../list_input
import std/[options, json]

export virtual_rows

import raylib

import tree_model
export tree_model

template rowH(w: untyped): float32 =
  ## This widget's row height: its own prop, else the theme's.
  themedSize(w.nodeHeight, currentTheme.rowHeight(24.0))

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the TreeView type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.bounds.y, height = widget.bounds.height,
              rowHeight = rowH(widget), scrollY = widget.scrollY)

template reflatten(widget: untyped) =
  ## Rebuild the visible rows from the expanded part of the tree.
  widget.flatNodes.setLen(0)
  flatten(widget.rootNode, 0, widget.flatNodes)

template setExpanded(widget: untyped, node: TreeNode, open: bool) =
  ## Open or close a branch, re-flatten, and tell whoever listens.
  if node.expanded != open:
    node.expanded = open
    widget.reflatten()
    widget.layoutDirty = true
    widget.isDirty = true
    if open:
      if widget.onExpand != nil: widget.onExpand(node.id)
    else:
      if widget.onCollapse != nil: widget.onCollapse(node.id)

definePrimitive(TreeView):
  props:
    rootNode: TreeNode = nil
    nodeHeight: float32 = 0.0   # 0: the theme's row height
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

  init:
    widget.focusable = true

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
          if widget.onExpand != nil: widget.onExpand(flat.node.id)
        else:
          if widget.onCollapse != nil: widget.onCollapse(flat.node.id)
        return true

      if widget.selectedId != flat.node.id:
        widget.selectedId = flat.node.id
        widget.isDirty = true
        if widget.onSelect != nil:
          widget.onSelect(flat.node.id)
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

    on_key_down:
      # Up/Down (Home/End, PageUp/PageDown) move the selection; Right opens a
      # closed branch or steps into an open one; Left closes an open branch
      # or steps out to the parent; Space/Enter open or close a branch.
      if not widget.focused:
        return false
      widget.reflatten()
      let rows = widget.flatNodes
      if rows.len == 0:
        return false
      var at = rows.rowOf(widget.selectedId)
      if at < 0: at = 0
      let node = rows[at].node
      let branch = node.children.len > 0
      var target = at
      case event.key
      of KeyboardKey.Right:
        if branch and not node.expanded: widget.setExpanded(node, true)
        elif branch: target = at + 1
        else: return true
      of KeyboardKey.Left:
        if branch and node.expanded: widget.setExpanded(node, false)
        else:
          let parent = rows.parentRow(at)
          if parent >= 0: target = parent
      of KeyboardKey.Space, KeyboardKey.Enter, KeyboardKey.KpEnter:
        if branch: widget.setExpanded(node, not node.expanded)
        return true
      else:
        let moved = nextFocusIndex(event.key, at, rows.len,
                                   max(1, int(widget.bounds.height / rowH(widget)) - 1))
        if moved.isNone:
          return false
        target = moved.get
      widget.reflatten()
      target = clamp(target, 0, widget.flatNodes.high)
      let id = widget.flatNodes[target].node.id
      if id != widget.selectedId:
        widget.selectedId = id
        if widget.onSelect != nil: widget.onSelect(id)
      widget.scrollY = viewportOf(widget).scrollToShow(target, widget.flatNodes.len)
      widget.isDirty = true
      return true

  layout:
    # Re-flatten: the visible row list is built here (and by a key that
    # opens or closes a branch, which needs it at once).
    widget.reflatten()

    if widget.bounds.height <= 0:
      widget.bounds.height = float32(widget.visibleRows) * rowH(widget)
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
    let nodeH = rowH(widget)
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
