## Autocomplete -- a text field that offers matching suggestions as you type.
##
## Type, and the entries of `suggestions` containing what you typed (those that
## start with it first, case ignored) drop down. Down/Up move through them,
## Enter takes the highlighted one, Escape closes the list; a click takes one
## too. Anything may still be typed: it is a text field, not a choice list.
## `onChange(text)` fires as the text changes, `onSubmit(text)` on Enter with
## nothing highlighted, `onPick(text)` when a suggestion is taken.
##
## ```nim
## Autocomplete(suggestions = @["Berlin", "Bern", "Bergen"], placeholder = "City")
## ```

import rui_core
import rui_drawing
import std/[options, strutils, sequtils]
import textarea, popup_field
import ../basic/combobox
from raylib import KeyboardKey

proc suggestionsFor*(all: openArray[string], typed: string, limit: int): seq[string] =
  ## What to offer for `typed`: entries starting with it, then entries merely
  ## containing it; never the exact entry already typed; at most `limit`.
  if typed.len == 0: return @[]
  let needle = typed.toLowerAscii
  var prefix, inside: seq[string]
  for item in all:
    let hay = item.toLowerAscii
    if hay == needle: continue
    if hay.startsWith(needle): prefix.add item
    elif needle in hay: inside.add item
  result = prefix & inside
  if result.len > limit: result.setLen(limit)

definePrimitive(Autocomplete):
  props:
    suggestions: seq[string] = @[]
    initialText: string = ""
    placeholder: string = "Type here..."
    maxShown: int = 6
    itemHeight: float32 = 24.0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    isOpen: bool
    matches: seq[string]
    hoverIndex: int
    input: TextInput
    list: ComboList

  actions:
    onChange(text: string)
    onSubmit(text: string)
    onPick(text: string)

  init:
    let field = widget
    widget.hoverIndex = -1
    widget.list = newComboList(itemHeight = widget.itemHeight, intent = widget.intent)
    widget.list.source = proc(): tuple[items: seq[string], selected, hover: int] =
      (field.matches, -1, field.hoverIndex)
    widget.list.onPick = proc(i: int) =
      if i >= 0 and i < field.matches.len:
        let text = field.matches[i]
        field.setFieldOpen(field.list, false)
        field.input.replaceText(text)
        if field.onPick != nil: field.onPick(text)
    widget.list.onHover = proc(i: int) =
      let h = if i >= 0 and i < field.matches.len: i else: -1
      if h != field.hoverIndex:
        field.hoverIndex = h
        field.list.isDirty = true
    widget.input = newTextInput(initialText = widget.initialText,
                                placeholder = widget.placeholder, disabled = widget.disabled,
                                intent = widget.intent)
    widget.input.onChange = proc(text: string) =
      field.matches = suggestionsFor(field.suggestions, text, field.maxShown)
      field.hoverIndex = -1
      field.setFieldOpen(field.list, field.matches.len > 0 and field.input.focused)
      field.list.isDirty = true
      if field.onChange != nil: field.onChange(text)
    widget.input.onSubmit = proc(text: string) =
      if field.isOpen and field.hoverIndex >= 0 and field.hoverIndex < field.matches.len:
        let chosen = field.matches[field.hoverIndex]
        field.setFieldOpen(field.list, false)
        field.input.replaceText(chosen)
        if field.onPick != nil: field.onPick(chosen)
      else:
        field.setFieldOpen(field.list, false)
        if field.onSubmit != nil: field.onSubmit(text)
    widget.addChild widget.input
    widget.addChild widget.list

  events:
    on_key_down:
      # Reached by bubbling from the text field, which leaves Up/Down/Escape alone.
      if widget.disabled or not widget.isOpen: return false
      if event.key == KeyboardKey.Escape:
        widget.setFieldOpen(widget.list, false)
        return true
      let moved = highlightKey(event.key, widget.matches.len, widget.hoverIndex)
      if moved < 0 or event.key in {KeyboardKey.Home, KeyboardKey.End}: return false   # those edit the text
      widget.hoverIndex = moved
      widget.list.isDirty = true
      widget.isDirty = true
      return true

  layout:
    let natural = widget.input.measure(constraintsOf(widget.bounds))
    if widget.bounds.height <= 0: widget.bounds.height = natural.height
    if widget.bounds.width <= 0: widget.bounds.width = natural.width
    widget.input.arrange(widget.bounds)
    let h = float32(widget.matches.len) * widget.itemHeight
    widget.list.bounds = popupRect(widget.bounds, widget.bounds.width, h)
    widget.list.itemHeight = widget.itemHeight

  render:
    if widget.isOpen:
      widget.list.fieldProps = widget.themeProps(widget.intent, crText)
      widget.list.isDirty = true
