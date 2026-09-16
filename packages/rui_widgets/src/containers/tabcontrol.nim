## TabControl Widget - RUI2
##
## A tabbed container: a row of tab buttons on top, one child shown below.
## Child i belongs to tab i.
##
## Inactive children are hidden with `visible = false` rather than skipped at
## render time, because renderPass walks the child list itself -- a container
## cannot decide not to draw a child, it can only mark it invisible.

import rui_core
import rui_drawing
import std/options

definePrimitive(TabControl):
  props:
    tabs: seq[string] = @[]      # Tab titles
    initialActiveTab: int = 0
    tabBarHeight: float32 = 28.0
    intent: ThemeIntent = Default

  state:
    activeTab: int
    hoverTab: int

  actions:
    onTabChanged(newTab: int)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.tabs.len == 0:
        return false
      # Only the tab strip responds; the body belongs to the active child.
      if event.mousePos.y > widget.bounds.y + widget.tabBarHeight:
        return false
      let tabWidth = widget.bounds.width / float32(widget.tabs.len)
      let idx = int((event.mousePos.x - widget.bounds.x) / tabWidth)
      if idx < 0 or idx >= widget.tabs.len or idx == widget.activeTab:
        return false
      widget.activeTab = idx
      widget.isDirty = true
      widget.layoutDirty = true   # child visibility is decided in layout
      if widget.onTabChanged != nil:
        widget.onTabChanged(idx)
      return true

    on_mouse_move:
      if widget.tabs.len == 0:
        return false
      let overBar = event.mousePos.y <= widget.bounds.y + widget.tabBarHeight
      let tabWidth = widget.bounds.width / float32(widget.tabs.len)
      let idx = int((event.mousePos.x - widget.bounds.x) / tabWidth)
      let newHover = if overBar and idx >= 0 and idx < widget.tabs.len: idx else: -1
      if newHover != widget.hoverTab:
        widget.hoverTab = newHover
        widget.isDirty = true
      return false

  layout:
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      var total = 0.0'f32
      for tab in widget.tabs:
        total += measureText(tab, style).width + 24.0
      widget.bounds.width = total

    var maxChildHeight = 0.0'f32
    for i, child in widget.children:
      child.visible = i == widget.activeTab
      child.bounds.x = widget.bounds.x
      child.bounds.y = widget.bounds.y + widget.tabBarHeight
      child.bounds.width = widget.bounds.width
      if widget.bounds.height > 0:
        child.bounds.height = widget.bounds.height - widget.tabBarHeight
      # Inactive tabs are still laid out, so switching to one is instant.
      child.layout()
      maxChildHeight = max(maxChildHeight, child.bounds.height)

    if widget.bounds.height <= 0:
      widget.bounds.height = widget.tabBarHeight + maxChildHeight

  render:
    # Only the tab strip is ours; the active child is composited by renderPass.
    if widget.tabs.len == 0:
      return

    let tabWidth = widget.bounds.width / float32(widget.tabs.len)
    for i, tab in widget.tabs:
      let active = i == widget.activeTab
      let state = if active: Selected
                  elif i == widget.hoverTab: Hovered
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)
      let tabRect = Rect(
        x: widget.bounds.x + float32(i) * tabWidth,
        y: widget.bounds.y,
        width: tabWidth,
        height: widget.tabBarHeight
      )
      drawTab(tabRect, tab, props, active, i == widget.hoverTab)
