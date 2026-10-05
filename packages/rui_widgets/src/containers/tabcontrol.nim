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
from raylib import KeyboardKey

template tabBarHeightOf(w: untyped): float32 =
  ## Tab strip height: the prop, else the theme's.
  themedSize(w.tabBarHeight, currentTheme.barHeight(28.0))

template selectTab(widget: untyped, index: int) =
  ## Show tab `index` (wrapping round), and tell whoever listens.
  block:
    let n = widget.tabs.len
    let i = ((index mod n) + n) mod n
    if i != widget.activeTab:
      widget.activeTab = i
      widget.isDirty = true
      widget.layoutDirty = true   # child visibility is decided in layout
      if widget.onTabChanged != nil:
        widget.onTabChanged(i)

definePrimitive(TabControl):
  props:
    tabs: seq[string] = @[]      # Tab titles
    initialActiveTab: int = 0
    tabBarHeight: float32 = 0.0   # 0: from the theme
    intent: ThemeIntent = Default

  state:
    activeTab: int
    hoverTab: int

  actions:
    onTabChanged(newTab: int)

  init:
    widget.focusable = true
    widget.hoverTab = -1       # nothing is under the pointer yet

  events:
    on_mouse_down:
      if widget.tabs.len == 0:
        return false
      # Only the tab strip responds; the body belongs to the active child.
      if event.mousePos.y > widget.bounds.y + tabBarHeightOf(widget):
        return false
      let tabWidth = widget.bounds.width / float32(widget.tabs.len)
      let idx = int((event.mousePos.x - widget.bounds.x) / tabWidth)
      if idx < 0 or idx >= widget.tabs.len or idx == widget.activeTab:
        return false
      widget.selectTab(idx)
      return true

    on_key_down:
      # From anywhere inside: Ctrl+Tab / Ctrl+PageDown to the next tab,
      # Ctrl+Shift+Tab / Ctrl+PageUp to the previous. On the focused strip
      # itself: Left/Right, Home/End.
      if widget.tabs.len == 0:
        return false
      if event.ctrl:
        case event.key
        of KeyboardKey.Tab:
          widget.selectTab(widget.activeTab + (if event.shift: -1 else: 1))
          return true
        of KeyboardKey.PageDown:
          widget.selectTab(widget.activeTab + 1)
          return true
        of KeyboardKey.PageUp:
          widget.selectTab(widget.activeTab - 1)
          return true
        else:
          return false
      if not widget.focused:
        return false
      case event.key
      of KeyboardKey.Right: widget.selectTab(widget.activeTab + 1)
      of KeyboardKey.Left: widget.selectTab(widget.activeTab - 1)
      of KeyboardKey.Home: widget.selectTab(0)
      of KeyboardKey.End: widget.selectTab(widget.tabs.len - 1)
      else: return false
      return true

    on_mouse_move:
      if widget.tabs.len == 0:
        return false
      let overBar = event.mousePos.y <= widget.bounds.y + tabBarHeightOf(widget)
      let tabWidth = widget.bounds.width / float32(widget.tabs.len)
      let idx = int((event.mousePos.x - widget.bounds.x) / tabWidth)
      let newHover = if overBar and idx >= 0 and idx < widget.tabs.len: idx else: -1
      if newHover != widget.hoverTab:
        widget.hoverTab = newHover
        widget.isDirty = true
      return false

  layout:
    if widget.bounds.width <= 0:
      let style = currentTheme.getThemeProps(widget.intent).captionStyle(BLACK, action = true)
      var total = 0.0'f32
      for tab in widget.tabs:
        total += measureText(tab, style).width + 24.0 + currentTheme.getThemeProps(widget.intent).strokeWidth * 2
      widget.bounds.width = total

    var maxChildHeight = 0.0'f32
    for i, child in widget.children:
      child.visible = i == widget.activeTab
      child.bounds.x = widget.bounds.x
      child.bounds.y = widget.bounds.y + tabBarHeightOf(widget)
      child.bounds.width = widget.bounds.width
      if widget.bounds.height > 0:
        child.bounds.height = widget.bounds.height - tabBarHeightOf(widget)
      # Inactive tabs are still laid out, so switching to one is instant.
      child.layout()
      maxChildHeight = max(maxChildHeight, child.bounds.height)

    if widget.bounds.height <= 0:
      widget.bounds.height = tabBarHeightOf(widget) + maxChildHeight

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
        height: tabBarHeightOf(widget)
      )
      drawTab(tabRect, tab, props, active, i == widget.hoverTab)
