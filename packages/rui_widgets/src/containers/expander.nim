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
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled: return false
      let props = widget.themeProps(widget.intent, crPointer)
      if event.mousePos.y > widget.bounds.y + headerHeight(props): return false
      widget.expanded = not widget.expanded
      widget.layoutDirty = true
      if widget.onToggle != nil: widget.onToggle(widget.expanded)
      return true

    on_key_down:
      if widget.disabled or not widget.focused: return false
      if event.key == KeyboardKey.Space or event.key == KeyboardKey.Enter:
        widget.expanded = not widget.expanded
        widget.layoutDirty = true
        if widget.onToggle != nil: widget.onToggle(widget.expanded)
        return true
      return false

  layout:
    let props = widget.themeProps(widget.intent, crPointer)
    let head = headerHeight(props)
    let titleW = measureText(widget.title, props.captionStyle(BLACK)).width + head
    var inner = Size()
    if widget.children.len > 0:
      let child = widget.children[0]
      child.visible = widget.expanded
      if widget.expanded:
        inner = child.measure(if widget.bounds.width > 0:
                                unbounded().withWidth(widget.bounds.width)
                              else: unbounded())
    if widget.bounds.width <= 0: widget.bounds.width = max(titleW, inner.width)
    if widget.bounds.height <= 0:
      widget.bounds.height = head + (if widget.expanded: contentGap(widget) + inner.height else: 0.0'f32)
    if widget.expanded and widget.children.len > 0:
      widget.children[0].arrange(Rect(
        x: widget.bounds.x, y: widget.bounds.y + head + contentGap(widget),
        width: widget.bounds.width, height: inner.height))

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let head = headerHeight(props)
    let color = props.foregroundColor.get(BLACK)
    # A chevron: points right collapsed, down open.
    let cx = widget.bounds.x + head / 2
    let cy = widget.bounds.y + head / 2
    let r = head / 6
    if widget.expanded:
      drawLine(cx - r, cy - r / 2, cx, cy + r / 2, color, 2)
      drawLine(cx, cy + r / 2, cx + r, cy - r / 2, color, 2)
    else:
      drawLine(cx - r / 2, cy - r, cx + r / 2, cy, color, 2)
      drawLine(cx + r / 2, cy, cx - r / 2, cy + r, color, 2)
    let style = props.captionStyle(color, action = true)
    drawStyledText(widget.title, widget.bounds.x + head,
                   widget.bounds.y + (head - style.fontSize) / 2, style)
    if widget.focused:
      drawBox(Rect(x: widget.bounds.x, y: widget.bounds.y, width: widget.bounds.width, height: head),
              2, Color(r: 0, g: 0, b: 0, a: 0),
              props.focusColor.get(color), props.focusRingWidth.get(2.0'f32))
