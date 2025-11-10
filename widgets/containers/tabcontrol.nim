## TabControl Widget - RUI2
##
## A tabbed interface container that shows one child at a time.
## Displays tab buttons at the top and the active tab's content below.
## Ported from Hummingbird to RUI2's defineWidget DSL.

import ../../core/widget_dsl_v2
import std/[options, strutils]

when defined(useGraphics):
  import raylib

defineWidget(TabControl):
  props:
    tabs: seq[string] = @[]      # Tab titles
    initialActiveTab: int = 0
    tabBarHeight: float = 28.0
    onTabChanged: proc(newTab: int)

  state:
    activeTab: int

  layout:
    # All children have the same bounds (below tab bar)
    # Only the active one will be rendered
    for i, child in widget.children:
      child.bounds.x = widget.bounds.x
      child.bounds.y = widget.bounds.y + widget.tabBarHeight
      child.bounds.width = widget.bounds.width
      child.bounds.height = widget.bounds.height - widget.tabBarHeight

      # Layout all children (even inactive ones)
      child.layout()

  render:
    when defined(useGraphics):
      var activeIdx = widget.activeTab.get()

      # Join tab titles with semicolon separator
      let tabsStr = if widget.tabs.len > 0:
                      widget.tabs.join(";")
                    else:
                      "No tabs"

      # GuiTabBar signature: (bounds, text, active)
      if GuiTabBar(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.tabBarHeight
        ),
        tabsStr.cstring,
        addr activeIdx
      ):
        # Tab changed
        if activeIdx != widget.activeTab.get():
          widget.activeTab.set(activeIdx)
          if widget.onTabChanged.isSome:
            widget.onTabChanged.get()(activeIdx)

      # Render only the active tab's content
      if activeIdx >= 0 and activeIdx < widget.children.len:
        widget.children[activeIdx].render()
    else:
      # Non-graphics mode
      let activeIdx = widget.activeTab.get()
      echo "Tabs: ", widget.tabs.join(" | ")
      if activeIdx >= 0 and activeIdx < widget.tabs.len:
        echo "Active: [", widget.tabs[activeIdx], "]"
      if activeIdx >= 0 and activeIdx < widget.children.len:
        echo "Content:"
        echo widget.children[activeIdx]
