## Tooltip Widget - RUI2
##
## Wraps the widget it describes, and floats a tip beside the pointer once the
## pointer has rested on that widget for `delay` seconds:
##
## ```nim
## ui:
##   Tooltip(text = "Saves the file"):
##     Button(text = "Save")
## ```
##
## The old Tooltip sat *beside* its target as a sibling and could never show:
## the pointer was never over the tooltip itself, and it waited for a hover
## event nothing produced. Now:
##
## - Wrapping the target makes it an ancestor of whatever the pointer is over,
##   so the target's pointer moves bubble up to it.
## - The delay is a repaint timer, so the tip appears on time in an idle app.
## - The tip goes on the overlay layer (`rui_core/overlays.nim`), above the
##   whole tree and clipped by nothing -- a widget cannot draw outside its own
##   render texture.
## - Leaving the target moves the hover, which dirties the old hovered widget
##   up to the root, Tooltip included; its next render hides the tip.

import rui_core
import rui_drawing
import std/[options, monotimes, times]

import raylib except getTime   # the clock here is std/monotimes, which a test can drive

const
  TipBackground = Color(r: 255, g: 255, b: 225, a: 255)
  TipText = Color(r: 20, g: 20, b: 20, a: 255)

template tipStyle(size: float32): TextStyle =
  TextStyle(fontFamily: "", fontSize: size, color: TipText,
            bold: false, italic: false, underline: false)

# The floating box itself. Lives on the overlay layer, never in the tree.
definePrimitive(TooltipTip):
  props:
    text: string = ""
    fontSize: float32 = 12.0
    padding: float32 = 6.0

  layout:
    # Positioned by its Tooltip; it only sizes itself to the text.
    let m = measureText(widget.text, tipStyle(widget.fontSize))
    widget.bounds.width = m.width + widget.padding * 2
    widget.bounds.height = m.height + widget.padding * 2

  render:
    drawTooltip(widget.text, widget.bounds, TipBackground, TipText,
                tipStyle(widget.fontSize))

proc tipOrigin*(pointer: Point, offsetX, offsetY: float32): Point =
  ## Where the tip's top-left goes: below and right of the pointer, clear of
  ## the cursor glyph.
  Point(x: pointer.x + offsetX, y: pointer.y + offsetY)

template refreshTip*(widget: untyped, now: MonoTime) =
  ## Show or hide the tip for the pointer's current state. `render` calls it;
  ## a test calls it with a clock of its own.
  block:
    let waited = (now - widget.hoverStart).inNanoseconds.float / 1e9
    if not widget.containsPointer:
      widget.hovering = false
      if widget.showing:
        widget.showing = false
        hideOverlay(widget.tip)
    elif widget.hovering and not widget.showing and widget.text.len > 0:
      if waited >= widget.delay - 0.01:
        widget.tip.text = widget.text
        let at = tipOrigin(pointerPos(), widget.offsetX, widget.offsetY)
        widget.tip.bounds.x = at.x
        widget.tip.bounds.y = at.y
        widget.showing = true
        showOverlay(widget.tip)
      else:
        widget.repaintAfter(widget.delay - waited)

defineWidget(Tooltip):
  props:
    text: string = ""
    delay: float = 0.5           # Seconds of rest before the tip shows
    offsetX: float32 = 12.0      # Tip position relative to the pointer
    offsetY: float32 = 18.0
    fontSize: float32 = 12.0
    padding: float32 = 6.0

  state:
    showing: bool
    hovering: bool               # the pointer arrived and has not left
    hoverStart: MonoTime         # when it arrived
    tip: TooltipTip

  init:
    widget.tip = newTooltipTip(text = widget.text, fontSize = widget.fontSize,
                               padding = widget.padding)

  events:
    on_mouse_move:
      # Bubbled up from whatever part of the target is under the pointer.
      if not widget.hovering:
        widget.hovering = true
        widget.hoverStart = getMonoTime()
        widget.repaintAfter(widget.delay)
      return false               # the target still gets its own moves

  layout:
    # A pass-through frame around the one child: the child fills it when the
    # parent sized the Tooltip, and sizes it when not.
    if widget.children.len > 0:
      let target = widget.children[0]
      target.bounds.x = widget.bounds.x
      target.bounds.y = widget.bounds.y
      if widget.bounds.width > 0: target.bounds.width = widget.bounds.width
      if widget.bounds.height > 0: target.bounds.height = widget.bounds.height
      target.layout()
      if widget.bounds.width <= 0: widget.bounds.width = target.bounds.width
      if widget.bounds.height <= 0: widget.bounds.height = target.bounds.height

  render:
    # Runs when the delay timer fires, and when the hover leaves the target.
    widget.refreshTip(getMonoTime())
