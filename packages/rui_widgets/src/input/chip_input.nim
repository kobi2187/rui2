## ChipInput -- tags typed into a field: each one becomes a chip.
##
## ```nim
## ChipInput(initialChips = @["nim", "ui"], suggestions = @["raylib", "pango"],
##           onChange = proc(chips: seq[string]) = echo chips)
## ```
##
## - Type and press Enter (or a comma) to make a chip of what was typed; a
##   suggestion taken from the list (the Autocomplete's) makes one too.
## - Backspace in the empty field removes the last chip; the x on a chip
##   removes that one.
## - The same text twice is one chip (case ignored), unless `allowDuplicates`.
## - Chips flow in rows, and the field takes the room left on the last; with no
##   height given the widget grows to its rows.
##
## The typing is an Autocomplete (and its TextInput): editing, suggestions and
## keys work as they do there.

import rui_core
import rui_drawing
import std/[options, strutils]
import textarea, autocomplete
import raylib

const
  ChipGap = 4'f32
  ChipPadX = 8'f32
  CloseSize = 14'f32
  MinField = 80'f32

proc chipLayout*(widget: Widget): tuple[chips: seq[Rect], field: Rect, height: float32]
proc closeRect*(chip: Rect): Rect
proc addChips(widget: Widget, typed: string)
proc removeChip(widget: Widget, i: int)

definePrimitive(ChipInput):
  props:
    initialChips: seq[string] = @[]
    suggestions: seq[string] = @[]
    placeholder: string = "Add..."
    allowDuplicates: bool = false
    chipHeight: float32 = 24.0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    chips: seq[string]
    field: Autocomplete
    hoverClose: int               ## the chip whose x is under the pointer; -1: none

  actions:
    onChange(chips: seq[string])

  init:
    let w = widget
    widget.chips = widget.initialChips
    widget.hoverClose = -1
    widget.field = newAutocomplete(suggestions = widget.suggestions,
                                   placeholder = widget.placeholder,
                                   disabled = widget.disabled, intent = widget.intent)
    widget.field.onSubmit = proc(text: string) = w.addChips(text)
    widget.field.onPick = proc(text: string) = w.addChips(text)
    widget.field.onChange = proc(text: string) =
      if ',' in text: w.addChips(text)     # a comma ends a chip as Enter does
    # Backspace in the empty field (the field does not use it then) removes
    # the last chip. Plain keys do not bubble, so the field hands it on.
    widget.field.input.onKey(proc(key: KeyboardKey): bool =
      if key != KeyboardKey.Backspace or w.chips.len == 0 or w.disabled: return false
      w.removeChip(w.chips.high)
      true)
    widget.addChild widget.field

  events:
    on_mouse_down:
      if widget.disabled: return false
      let lay = widget.chipLayout
      for i, r in lay.chips:
        if r.closeRect.contains(event.mousePos.x, event.mousePos.y):
          widget.removeChip(i)
          return true
      wantFocus(widget.field.input)         # a click anywhere else types
      return false

    on_mouse_move:
      var over = -1
      let lay = widget.chipLayout
      for i, r in lay.chips:
        if r.closeRect.contains(event.mousePos.x, event.mousePos.y):
          over = i
      if over != widget.hoverClose:
        widget.hoverClose = over
        widget.isDirty = true
      return false

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 320
    let lay = widget.chipLayout
    if widget.bounds.height <= 0: widget.bounds.height = lay.height
    widget.field.arrange(lay.field)

  render:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    let b = widget.bounds
    let ink = props.foregroundColor.get(BLACK)
    drawThemedBackground(b, props)
    drawThemedBorder(b, props, widget.field.input.focused)
    let accent = props.activeColor.get(ink)
    var style = props.captionStyle(ink)
    style.fontSize = max(10'f32, style.fontSize - 2)
    let lay = widget.chipLayout
    for i, r in lay.chips:
      drawBox(r, r.height / 2, accent.withAlpha(0.16), accent.withAlpha(0.5), 1)
      drawStyledText(widget.chips[i], r.x + ChipPadX,
                     r.y + (r.height - style.fontSize * 1.25) / 2, style)
      let c = Vector2(x: r.x + r.width - CloseSize / 2 - 4, y: r.y + r.height / 2)
      if i == widget.hoverClose:
        drawCircle(c, CloseSize / 2, accent.withAlpha(0.3))
      let k = CloseSize * 0.22
      drawLine(c.x - k, c.y - k, c.x + k, c.y + k, ink, 1.5)
      drawLine(c.x - k, c.y + k, c.x + k, c.y - k, ink, 1.5)

proc chipLayout*(widget: Widget): tuple[chips: seq[Rect], field: Rect, height: float32] =
  ## Where each chip sits, in rows, and the room left for the field on the
  ## last row (a row of its own when too little is left).
  let widget = ChipInput(widget)
  var style = widget.themeProps(widget.intent, crText).captionStyle(BLACK)
  style.fontSize = max(10'f32, style.fontSize - 2)
  let b = widget.bounds
  let pad = 4'f32
  let h = widget.chipHeight
  let fieldH = max(h, 28'f32)
  let rowH = max(h, fieldH) + ChipGap
  var x = b.x + pad
  var y = b.y + pad
  let right = b.x + b.width - pad
  for text in widget.chips:
    let w = measureText(text, style).width + ChipPadX + CloseSize + 8
    if x + w > right and x > b.x + pad:
      x = b.x + pad
      y += rowH
    result.chips.add Rect(x: x, y: y + (fieldH - h) / 2, width: min(w, right - x), height: h)
    x += w + ChipGap
  if right - x < MinField and x > b.x + pad:
    x = b.x + pad
    y += rowH
  result.field = Rect(x: x, y: y, width: max(1'f32, right - x), height: fieldH)
  result.height = y - b.y + fieldH + pad

proc closeRect*(chip: Rect): Rect =
  ## A chip's x: what a press takes to remove it.
  Rect(x: chip.x + chip.width - CloseSize - 6, y: chip.y,
       width: CloseSize + 6, height: chip.height)

proc changed(widget: ChipInput) =
  widget.layoutDirty = true
  widget.markDirtyToRoot()
  if widget.onChange != nil: widget.onChange(widget.chips)

proc addChips(widget: Widget, typed: string) =
  ## Each comma-separated part of `typed` becomes a chip; the field empties.
  let widget = ChipInput(widget)
  var added = false
  for part in typed.split(','):
    let t = part.strip
    if t.len == 0: continue
    var known = false
    if not widget.allowDuplicates:
      for c in widget.chips:
        if cmpIgnoreCase(c, t) == 0: known = true
    if not known:
      widget.chips.add t
      added = true
  widget.field.input.replaceText("")
  if added: widget.changed()

proc removeChip(widget: Widget, i: int) =
  let widget = ChipInput(widget)
  if i < 0 or i >= widget.chips.len: return
  widget.chips.delete(i)
  widget.changed()
