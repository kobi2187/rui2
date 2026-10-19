## What a dropdown Menu and a ContextMenu have in common: a panel of MenuItem
## rows that is collapsed to nothing while closed, laid out in two passes when
## open (each item measures itself, then every row is squared off to the widest),
## and drawn as a themed panel with the items composited over it.

import rui_core
import rui_drawing

proc collapseMenuPanel*(widget: Widget) =
  ## Closed: no bounds, no visible children, nothing to hit-test, so the widgets
  ## underneath stay clickable.
  for child in widget.children:
    child.visible = false
  widget.bounds.width = 0
  widget.bounds.height = 0

proc layoutMenuColumn*(widget: Widget, padding, minWidth: float32) =
  ## Stack the items down from the panel's top-left (`widget.bounds.x/y`, set by
  ## the caller) and size the panel to them.
  var y = widget.bounds.y + padding
  var widest = minWidth - padding * 2
  # Pass 1: let each item measure itself so the panel can size to the widest.
  for child in widget.children:
    child.visible = true
    child.bounds.x = widget.bounds.x + padding
    child.bounds.y = y
    child.bounds.width = 0        # 0 = measure yourself
    child.bounds.height = 0
    child.layout()
    widest = max(widest, child.bounds.width)
    y += child.bounds.height
  widget.bounds.width = widest + padding * 2
  widget.bounds.height = (y - widget.bounds.y) + padding
  # Pass 2: square every item off to the panel width.
  for child in widget.children:
    child.bounds.width = widest
    child.layout()

proc drawMenuPanel*(widget: Widget, intent: ThemeIntent, shadow = false) =
  ## The panel only: the items are composited over it by the render pass.
  let props = currentTheme.getThemeProps(intent, Normal)
  if shadow:
    drawFloatingShadow(widget.bounds, props)
  drawThemedBackground(widget.bounds, props)
  drawThemedBorder(widget.bounds, props)

proc showMenuLayer*(widget: Widget) =
  ## Put the panel on the overlay layer, where it takes the pointer; opening
  ## changes its size, so layout has to re-run.
  showOverlay(widget, interactive = true)
  widget.isDirty = true
  widget.layoutDirty = true

proc hideMenuLayer*(widget: Widget) =
  hideOverlay(widget)
  widget.isDirty = true
  widget.layoutDirty = true
