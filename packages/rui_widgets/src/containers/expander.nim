## Expander -- a header that shows and hides its content.
##
## Click the header, or press Space/Enter while it has focus. `initialExpanded`
## seeds the state `expanded`; `onToggle(expanded)` reports changes. Collapsed,
## the content is hidden and takes no room.
##
## ```nim
## Expander(title = "Advanced", initialExpanded = false):
##   Checkbox(text = "Verbose logging")
## ```

import rui_core
import ../press
import rui_drawing
import std/options
import raylib

proc headerHeight(props: ThemeProps): float32 =
  max(currentTheme.controlHeight * 0.8'f32, props.captionStyle(BLACK).fontSize + 10)

proc contentGap(widget: Widget): float32 = 4.0'f32

definePrimitive(Expander):
  props:
    title: string = ""
    initialExpanded: bool = true
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    expanded: bool

  actions:
    onToggle(expanded: bool)

  init:
    widget.makePressable()

  events:
    on_mouse_down:
      let head = headerHeight(widget.themeProps(widget.intent, crPointer))
      return widget.pressDown(event, not widget.disabled,
        Rect(x: widget.bounds.x, y: widget.bounds.y, width: widget.bounds.width, height: head))

    on_key_down:
      let head = headerHeight(widget.themeProps(widget.intent, crPointer))
      return widget.pressKey(event, not widget.disabled,
        Point(x: widget.bounds.x + 4, y: widget.bounds.y + head / 2))

    on_mouse_up:
      return widget.pressUp(event):
        widget.expanded = not widget.expanded
        widget.layoutDirty = true
        if widget.onToggle != nil: widget.onToggle(widget.expanded)

  layout:
    let props = widget.themeProps(widget.intent, crPointer)
    let head = headerHeight(props)
    let titleW = measureText(widget.title, props.captionStyle(BLACK)).width + head
    # The room under the header when a parent gave this a height: more than
    # the content's own while it is open in an Accordion, and, while one is
    # easing shut, what is left of it -- the content stays in sight until then.
    let room = widget.bounds.height - head - contentGap(widget)
    var inner = Size()
    if widget.children.len > 0:
      let child = widget.children[0]
      child.visible = widget.expanded or room > 1
      if child.visible:
        inner = child.measure(if widget.bounds.width > 0:
                                unbounded().withWidth(widget.bounds.width)
                              else: unbounded())
    if widget.bounds.width <= 0: widget.bounds.width = max(titleW, inner.width)
    if widget.bounds.height <= 0:
      widget.bounds.height = head + (if widget.expanded: contentGap(widget) + inner.height else: 0.0'f32)
    if widget.children.len > 0 and widget.children[0].visible:
      let child = widget.children[0]
      # Content that asks for the leftover room (`.flex()`) gets it.
      let h = if widget.expanded and child.flexGrow > 0: max(inner.height, room)
              else: inner.height
      child.arrange(Rect(x: widget.bounds.x, y: widget.bounds.y + head + contentGap(widget),
                         width: widget.bounds.width, height: h))
    widget.childClip = some(Rect(x: 0, y: head, width: widget.bounds.width,
                                 height: max(0.0'f32, widget.bounds.height - head)))   # widget-local

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let head = headerHeight(props)
    let color = props.foregroundColor.get(BLACK)
    # A chevron: points right collapsed, down open.
    drawChevron(Vector2(x: widget.bounds.x + head / 2, y: widget.bounds.y + head / 2),
                head / 3, if widget.expanded: cwDown else: cwRight, color)
    let style = props.captionStyle(color, action = true)
    drawStyledText(widget.title, widget.bounds.x + head,
                   widget.bounds.y + (head - style.fontSize) / 2, style)
    if widget.focused:
      drawBox(Rect(x: widget.bounds.x, y: widget.bounds.y, width: widget.bounds.width, height: head),
              2, Color(r: 0, g: 0, b: 0, a: 0),
              props.focusColor.get(color), props.focusRingWidth.get(2.0'f32))
