
# Tab control
defineWidget TabControl:
  props:
    tabs: seq[string]
    activeTab: int
    onTabChanged: proc(newTab: int)

  render:
    var active = widget.activeTab
    if GuiTabBar(
      widget.toRaylibRect(),
      widget.tabs.join(";"),
      addr active
    ):
      if active != widget.activeTab:
        widget.activeTab = active
        if widget.onTabChanged != nil:
          widget.onTabChanged(active)

    # Draw active tab content
    if widget.activeTab >= 0 and
       widget.activeTab < widget.children.len:
      widget.children[widget.activeTab].draw()

  state:
    fields:
      tabs: seq[string]
      activeTab: int
