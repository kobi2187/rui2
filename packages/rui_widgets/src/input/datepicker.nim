## DatePicker -- a day chosen from a calendar that drops down from a field.
##
## The value is ISO text ("2026-10-11"; "" is none), so it binds like any
## string: `DatePicker(value = due.value, onChange = due.setter)`. Click the field to open the month;
## the arrows at its top change month, a click on a day picks it. From the
## keyboard (focused), Left/Right move a day, Up/Down a week, PageUp/PageDown a
## month, Enter/Space/F4 open and close the calendar and Escape closes it.
## Weeks start on Monday unless `mondayFirst = false`. `onChange(value)` fires
## on real changes.

import rui_core
import rui_drawing
import std/[options, times, strutils]
import picker_values, popup_field
from raylib import KeyboardKey

type CalendarSource* = proc(): tuple[year, month: int, selected: string, hover: int,
                                      mondayFirst: bool] {.closure.}

definePrimitive(CalendarPopup):
  props:
    intent: ThemeIntent = Default

  state:
    source: CalendarSource

  actions:
    onPickDay(date: string)
    onShiftMonth(delta: int)
    onHoverCell(cell: int)

  init:
    widget.floating = true

  events:
    on_mouse_move:
      let hit = calHit(widget.bounds, event.mousePos.x, event.mousePos.y)
      if widget.onHoverCell != nil:
        widget.onHoverCell(if hit.kind == calDay: hit.cell else: -1)
      widget.isDirty = true
      return true

    on_mouse_down:
      if widget.source == nil: return true
      let hit = calHit(widget.bounds, event.mousePos.x, event.mousePos.y)
      let s = widget.source()
      case hit.kind
      of calPrevMonth:
        if widget.onShiftMonth != nil: widget.onShiftMonth(-1)
      of calNextMonth:
        if widget.onShiftMonth != nil: widget.onShiftMonth(1)
      of calDay:
        let day = calendarCells(s.year, s.month, s.mondayFirst)[hit.cell]
        if widget.onPickDay != nil: widget.onPickDay(isoDate(day))
      of calNone: discard
      return true

  render:
    if widget.source == nil: return
    let s = widget.source()
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let fg = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(Color(r: 80, g: 120, b: 255, a: 255))
    let style = props.captionStyle(fg)
    drawThemedBackground(widget.bounds, props)
    let title = $Month(s.month) & " " & $s.year
    let tw = measureText(title, style).width
    drawStyledText(title, widget.bounds.x + (widget.bounds.width - tw) / 2,
                   widget.bounds.y + (CalHeaderH - style.fontSize) / 2, style)
    for (rect, glyph) in [(calPrevRect(widget.bounds), "<"), (calNextRect(widget.bounds), ">")]:
      let gw = measureText(glyph, style).width
      drawStyledText(glyph, rect.x + (rect.width - gw) / 2,
                     rect.y + (rect.height - style.fontSize) / 2, style)
    let dim = fg.withAlpha(0.45'f32)
    let names = if s.mondayFirst: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                else: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    for i, name in names:
      let nw = measureText(name, style).width
      drawStyledText(name, widget.bounds.x + float32(i) * CalCellW + (CalCellW - nw) / 2,
                     widget.bounds.y + CalHeaderH + (CalWeekdayH - style.fontSize) / 2,
                     TextStyle(fontFamily: style.fontFamily, fontSize: style.fontSize, color: dim))
    let cells = calendarCells(s.year, s.month, s.mondayFirst)
    let today = now()
    let todayYmd = Ymd(year: today.year, month: ord(today.month), day: today.monthday)
    for i, day in cells:
      let rect = calCellRect(widget.bounds, i)
      let chosen = isoDate(day) == s.selected
      if chosen:
        drawBox(rect.inset(2), 4, accent, accent, 0)
      elif i == s.hover:
        drawBox(rect.inset(2), 4, accent.withAlpha(0.2'f32), accent.withAlpha(0.2'f32), 0)
      if day == todayYmd and not chosen:
        drawBox(rect.inset(2), 4, Color(r: 0, g: 0, b: 0, a: 0), accent, 1)
      let label = $day.day
      let lw = measureText(label, style).width
      let color = if chosen: props.backgroundColor.get(WHITE)
                  elif day.month != s.month: dim else: fg
      drawStyledText(label, rect.x + (rect.width - lw) / 2,
                     rect.y + (rect.height - style.fontSize) / 2,
                     TextStyle(fontFamily: style.fontFamily, fontSize: style.fontSize, color: color))
    drawThemedBorder(widget.bounds, props)

proc today(): Ymd =
  let n = now()
  Ymd(year: n.year, month: ord(n.month), day: n.monthday)

template pickDate(widget: untyped, text: string) =
  block:
    let wanted = text
    if wanted != widget.value:
      widget.value = wanted
      let parsed = parseIsoDate(wanted)
      if parsed.isSome:
        widget.viewYear = parsed.get.year
        widget.viewMonth = parsed.get.month
      widget.isDirty = true
      widget.layoutDirty = true
      if widget.onChange != nil: widget.onChange(wanted)

definePrimitive(DatePicker):
  props:
    initialValue: string = ""
    placeholder: string = "Select date..."
    mondayFirst: bool = true
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: string
    isOpen: bool
    viewYear: int
    viewMonth: int
    hoverCell: int
    popup: CalendarPopup

  actions:
    onChange(value: string)

  init:
    widget.focusable = true
    let field = widget
    let start = parseIsoDate(widget.value)
    let shown = if start.isSome: start.get else: today()
    widget.viewYear = shown.year
    widget.viewMonth = shown.month
    widget.hoverCell = -1
    widget.popup = newCalendarPopup(intent = widget.intent)
    widget.popup.source = proc(): tuple[year, month: int, selected: string, hover: int,
                                        mondayFirst: bool] =
      (field.viewYear, field.viewMonth, field.value, field.hoverCell, field.mondayFirst)
    widget.popup.onPickDay = proc(date: string) =
      field.pickDate(date)
      field.setFieldOpen(field.popup, false)
    widget.popup.onShiftMonth = proc(delta: int) =
      let moved = Ymd(year: field.viewYear, month: field.viewMonth, day: 1).addMonths(delta)
      field.viewYear = moved.year
      field.viewMonth = moved.month
      field.popup.isDirty = true
    widget.popup.onHoverCell = proc(cell: int) =
      if cell != field.hoverCell:
        field.hoverCell = cell
        field.popup.isDirty = true
    widget.addChild widget.popup

  events:
    on_mouse_down: return widget.popupFieldClick(widget.popup)

    on_key_down:
      if widget.disabled or not widget.focused: return false
      let current = block:
        let parsed = parseIsoDate(widget.value)
        if parsed.isSome: parsed.get else: today()
      if event.key in {KeyboardKey.Enter, KeyboardKey.KpEnter, KeyboardKey.Space, KeyboardKey.F4} and
         widget.value.len == 0:
        widget.pickDate(isoDate(current))      # opening an empty field starts at today
      if widget.popupToggleKey(widget.popup, event): return true
      case event.key
      of KeyboardKey.Left: widget.pickDate(isoDate(current.addDays(-1)))
      of KeyboardKey.Right: widget.pickDate(isoDate(current.addDays(1)))
      of KeyboardKey.Up: widget.pickDate(isoDate(current.addDays(-7)))
      of KeyboardKey.Down: widget.pickDate(isoDate(current.addDays(7)))
      of KeyboardKey.PageUp: widget.pickDate(isoDate(current.addMonths(-1)))
      of KeyboardKey.PageDown: widget.pickDate(isoDate(current.addMonths(1)))
      else: return false
      return true

  layout:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled)
    let style = props.captionStyle(BLACK)
    if widget.bounds.height <= 0:
      let line = measureText("Ag", style).height
      widget.bounds.height = max(currentTheme.controlHeight, line + 2 * props.fieldInset)
    if widget.bounds.width <= 0:
      widget.bounds.width = max(measureText("0000-00-00", style).width,
                                measureText(widget.placeholder, style).width) +
                            props.fieldInset * 2 + 24
    widget.popup.bounds = popupRect(widget.bounds, CalWidth, CalHeight)

  render:
    let props = widget.themeProps(widget.intent, crText, disabled = widget.disabled,
                                  pressed = widget.isOpen)
    drawComboBox(widget.bounds, (if widget.value.len > 0: widget.value else: widget.placeholder),
                 props, widget.isOpen, widget.hovered, widget.focused)
    if widget.isOpen:
      widget.popup.isDirty = true
    if widget.disabled: drawDisabledOverlay(widget.bounds, currentTheme.canvasColor)
