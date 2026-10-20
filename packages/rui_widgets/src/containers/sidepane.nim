## SidePane -- an optional pane that folds to a slim strip.
##
## Open, it is a titled column `width` wide with its content under the header.
## Minimized, it shrinks to a `stripWidth` strip that keeps a chevron to open it
## again and its `summary` (a count, say), so what is in it is never out of
## sight. Click the header -- or the strip -- or press Space/Enter while it has
## focus; the width eases over the theme's transition time, as a Drawer's does.
## `side` is the edge it sits on: a right-hand pane folds toward the right.
##
## ```nim
## Row():
##   Expanded(): Content()
##   SidePane(title = "Chosen", summary = "3", side = psRight):
##     ListBox(items = chosen)
## ```

import rui_core
import ../press
import rui_drawing
import std/options

type PaneSide* = enum psRight, psLeft

proc paneHeader(): float32 = max(currentTheme.controlHeight * 0.9'f32, 26.0'f32)

definePrimitive(SidePane):
  props:
    title: string = ""
    summary: string = ""         # shown beside the title, and alone on the strip
    width: float32 = 220.0
    stripWidth: float32 = 30.0
    initialExpanded: bool = true
    side: PaneSide = psRight
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    expanded: bool
    slide: Animated[float32]
    shown: float32               # 0 minimized .. 1 open, eased

  actions:
    onToggle(expanded: bool)

  init:
    widget.makePressable()
    widget.expanded = widget.initialExpanded
    widget.shown = if widget.expanded: 1.0 else: 0.0

  events:
    on_mouse_down:
      # Open, the header folds it; minimized, the whole strip opens it.
      let region = if widget.expanded:
                     Rect(x: widget.bounds.x, y: widget.bounds.y,
                          width: widget.bounds.width, height: paneHeader())
                   else: widget.bounds
      return widget.pressDown(event, not widget.disabled, region)

    on_key_down:
      return widget.pressKey(event, not widget.disabled,
        Point(x: widget.bounds.x + 4, y: widget.bounds.y + paneHeader() / 2))

    on_mouse_up:
      return widget.pressUp(event):
        widget.expanded = not widget.expanded
        widget.layoutDirty = true
        if widget.onToggle != nil: widget.onToggle(widget.expanded)

  layout:
    widget.shown = widget.slide.follow(widget, (if widget.expanded: 1.0'f32 else: 0.0'f32),
                                       currentTheme.transitionSeconds)
    let w = widget.stripWidth + (widget.width - widget.stripWidth) * widget.shown
    let head = paneHeader()
    let h = if widget.bounds.height > 0: widget.bounds.height
            elif widget.children.len > 0:
              head + widget.children[0].measure(unbounded().withWidth(widget.width)).height
            else: head
    # A right-hand pane grows leftward from its right edge, so it folds toward it.
    if widget.side == psRight and widget.bounds.width > 0:
      widget.bounds.x += widget.bounds.width - w
    widget.bounds.width = w
    widget.bounds.height = h
    if widget.children.len > 0:
      let child = widget.children[0]
      child.visible = w > widget.stripWidth + 8
      let x = if widget.side == psRight: widget.bounds.x else: widget.bounds.x + w - widget.width
      child.arrange(Rect(x: x, y: widget.bounds.y + head,
                         width: widget.width, height: max(0.0'f32, h - head)))
    widget.childClip = some(Rect(x: 0, y: head, width: w, height: max(0.0'f32, h - head)))

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled,
                                  pressed = widget.isPressed)
    let rest = currentTheme.getThemeProps(widget.intent, Normal)
    let head = paneHeader()
    let ink = rest.foregroundColor.get(BLACK)
    drawThemedRect(widget.bounds, rest)
    let header = Rect(x: widget.bounds.x, y: widget.bounds.y,
                      width: widget.bounds.width, height: if widget.expanded: head else: widget.bounds.height)
    if widget.hovered or widget.isPressed:
      drawThemedBackground(header, props, pressed = widget.isPressed, hovered = true)
    # The chevron points the way the pane will move: toward its edge to fold,
    # away from it to open.
    let towardEdge = if widget.side == psRight: cwRight else: cwLeft
    let awayFromEdge = if widget.side == psRight: cwLeft else: cwRight
    let chevronX = widget.bounds.x + widget.stripWidth / 2
    drawChevron(Vector2(x: chevronX, y: widget.bounds.y + head / 2), 9.0,
                if widget.expanded: towardEdge else: awayFromEdge, ink)
    let style = rest.captionStyle(ink, action = true)
    if widget.shown > 0.6:
      let caption = if widget.summary.len > 0: widget.title & "  (" & widget.summary & ")"
                    else: widget.title
      drawStyledText(fittedText(caption, style, widget.bounds.width - widget.stripWidth - 6),
                     widget.bounds.x + widget.stripWidth,
                     widget.bounds.y + (head - style.fontSize) / 2, style)
    elif widget.summary.len > 0:
      # Minimized: the summary stands alone under the chevron.
      drawStyledText(widget.summary, chevronX, widget.bounds.y + head + 4, style, centered = true)
    if widget.focused:
      drawThemedFocusRing(header, props)

method computeSize*(widget: SidePane, c: Constraints): Size =
  let w = if widget.expanded: widget.width else: widget.stripWidth
  var h = paneHeader()
  if widget.children.len > 0:
    h += widget.children[0].measure(unbounded().withWidth(widget.width)).height
  Size(width: w, height: (if c.tightHeight: c.minHeight else: h))

proc setExpanded*(widget: SidePane, expanded: bool) =
  ## Open or minimize it from code.
  if widget.expanded == expanded: return
  widget.expanded = expanded
  widget.layoutDirty = true
  widget.markDirtyToRoot()
  if widget.onToggle != nil: widget.onToggle(expanded)
