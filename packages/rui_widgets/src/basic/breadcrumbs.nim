## Breadcrumbs -- a path as a row of clickable steps: `/ › home › ada › notes`.
##
## Each step is a Crumb, a flat button (press.nim, so it presses, cancels and
## takes Space/Enter like every other button); clicking one calls `onNavigate`
## with the path up to and including it. The last step is where you are, drawn
## bold. When the row is too narrow the leading steps give way to "…", so the
## end of the path -- where you are -- always shows.
##
## ```nim
## Breadcrumbs(path = "/home/ada/notes", onNavigate = proc(p: string) = open(p))
## ```

import rui_core
import ../press
import rui_drawing
import std/[options, os, sequtils, strutils]

const
  CrumbPad = 6.0'f32        ## text inset inside a crumb
  SepWidth = 14.0'f32       ## room for the "›" between crumbs
  Ellipsis = "…"

proc crumbStyle(props: ThemeProps, current: bool): TextStyle =
  ## The steps in the theme's caption; where you are, in bold.
  result = props.captionStyle(props.foregroundColor.get(BLACK))
  result.bold = current

definePrimitive(Crumb):
  props:
    text: string = ""
    current: bool = false        # the last step: where you are
    disabled: bool = false
    intent: ThemeIntent = Default

  actions:
    onClick()

  init:
    widget.makePressable()

  events:
    on_mouse_down: return widget.pressDown(event, not widget.disabled)
    on_key_down: return widget.pressKey(event, not widget.disabled)
    on_mouse_up:
      return widget.pressUp(event):
        if widget.onClick != nil: widget.onClick()

  layout:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    if widget.bounds.width <= 0:
      widget.bounds.width = measureText(widget.text, crumbStyle(props, widget.current)).width +
                            CrumbPad * 2
    if widget.bounds.height <= 0:
      widget.bounds.height = 24.0

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled,
                                  pressed = widget.isPressed)
    # Flat until it has something to say, like a toolbar button.
    if widget.isPressed or widget.hovered or widget.focused:
      drawInteractiveBox(widget.bounds, props, widget.isPressed, widget.hovered, widget.focused)
    let style = crumbStyle(props, widget.current)
    drawStyledText(widget.text, widget.bounds.x + CrumbPad,
                   widget.bounds.y + (widget.bounds.height - style.fontSize) / 2, style)

proc steps*(path: string): seq[tuple[name, path: string]] =
  ## The steps of `path`, each with the path up to it: "/home/ada" gives
  ## ("/", "/"), ("home", "/home"), ("ada", "/home/ada").
  let full = if path.len == 0: "/" else: path
  var acc = ""
  if full.isAbsolute:
    acc = "/"
    result.add ("/", "/")
  for part in full.split({'/', '\\'}):
    if part.len == 0: continue
    acc = if acc.len == 0: part elif acc.endsWith("/"): acc & part else: acc & "/" & part
    result.add (part, acc)

proc navigateTo(widget: Widget, target: string): proc()
proc buildCrumbs(widget: Widget)

definePrimitive(Breadcrumbs):
  props:
    path: string = ""
    height: float32 = 28.0
    intent: ThemeIntent = Default

  state:
    shown: string                # the path the crumbs were built for
    built: bool
    first: int                   # the first crumb that fits; those before it are "…"
    seps: seq[float32]           # where each "›" goes, from the widget's left edge

  actions:
    onNavigate(path: string)

  init:
    widget.buildCrumbs()      # the crumbs exist from the start, for tools and tests

  layout:
    if not widget.built or widget.shown != widget.path:
      widget.buildCrumbs()
    if widget.bounds.height <= 0: widget.bounds.height = widget.height
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    var widths: seq[float32]
    for c in widget.children:
      let crumb = Crumb(c)
      widths.add measureText(crumb.text, crumbStyle(props, crumb.current)).width + CrumbPad * 2
    var total = 0.0'f32
    for w in widths: total += w
    total += SepWidth * float32(max(0, widths.len - 1))
    if widget.bounds.width <= 0: widget.bounds.width = total
    # Drop steps from the front until the rest, after a "…", fits.
    let ellipsisW = measureText(Ellipsis, crumbStyle(props, false)).width + SepWidth
    widget.first = 0
    while widget.first < widths.high and total > widget.bounds.width:
      total -= widths[widget.first] + SepWidth
      if widget.first == 0: total += ellipsisW
      inc widget.first
    var x = widget.bounds.x + (if widget.first > 0: ellipsisW else: 0.0'f32)
    let h = min(24.0'f32, widget.bounds.height)
    let y = widget.bounds.y + (widget.bounds.height - h) / 2
    widget.seps.setLen(0)
    for i, c in widget.children:
      c.visible = i >= widget.first
      if not c.visible: continue
      if i > widget.first or widget.first > 0:
        widget.seps.add x - SepWidth - widget.bounds.x
      c.arrange(Rect(x: x, y: y, width: widths[i], height: h))
      x += widths[i] + SepWidth

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = mixTone(props.foregroundColor.get(BLACK), currentTheme.canvasColor, 0.35)
    let style = TextStyle(fontSize: props.fontSize.get(14.0), color: readableInk(ink,
                          currentTheme.canvasColor, 3.0))
    let midY = widget.bounds.y + (widget.bounds.height - style.fontSize) / 2
    if widget.first > 0:
      drawStyledText(Ellipsis, widget.bounds.x + 2, midY, style)
    # The separators sit in the gaps the layout left between visible crumbs.
    # Offsets, not the crumbs' bounds: while it renders, this widget's bounds
    # are moved to its texture's origin and its children's are not.
    let sepW = measureText("›", style).width
    for gap in widget.seps:
      drawStyledText("›", widget.bounds.x + gap + (SepWidth - sepW) / 2, midY, style)

proc navigateTo(widget: Widget, target: string): proc() =
  ## A crumb's click. Made here, not in the loop that builds the crumbs: a
  ## closure there would share the loop's variable, and every crumb would go
  ## to the last step.
  result = proc() =
    let b = Breadcrumbs(widget)
    if b.onNavigate != nil: b.onNavigate(target)

proc buildCrumbs(widget: Widget) =
  ## One Crumb per step of the path, replacing the last path's.
  let b = Breadcrumbs(widget)
  for c in b.children.toSeq:
    b.removeChild(c)
    disposeTree(c)
  let all = steps(b.path)
  for i, step in all:
    let crumb = newCrumb(text = step.name, current = i == all.high, intent = b.intent)
    crumb.onClick = navigateTo(b, step.path)
    b.addChild(crumb)
  b.shown = b.path
  b.built = true
