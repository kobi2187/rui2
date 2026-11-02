## CommandPalette -- every command, found by typing a few of its letters.
##
## ```nim
## var palette: CommandPalette
## ui:
##   palette = CommandPalette(commands = @[
##     command("Open File", "Ctrl+O", proc() = openFile()),
##     command("Save As...", "Ctrl+Shift+S", proc() = saveAs()),
##     command("Toggle Word Wrap", "", proc() = wrap = not wrap)])
## root.onKey(proc(k: KeyboardKey): bool = ...)   # or a key of your app: palette.open()
## ```
##
## `open` shows it near the top of the window with the keyboard in its field.
## Typing filters the commands fuzzily (fuzzy.nim: "opf" finds "Open File"),
## the letters that matched in bold. Up/Down choose, Enter runs the chosen one
## and closes, Escape or a click elsewhere closes. A click on a row runs it.
## It is a popup like a menu: on the overlay layer, closed by the registry.

import rui_core
import rui_drawing
import menu_panel
import ../fuzzy
import ../input/[textarea, popup_field]
import std/[options, strutils, json]
import raylib

type Command* = object
  name*: string
  shortcut*: string        ## shown on the right, as a hint
  run*: proc() {.closure.}

proc command*(name: string, shortcut = "", run: proc() {.closure.} = nil): Command =
  Command(name: name, shortcut: shortcut, run: run)

proc `%`*(c: Command): JsonNode = %c.name
  ## What scripting sees of a command: its name.

proc refilter(widget: Widget)
proc runChosen(widget: Widget, i: int)
proc listKey(widget: Widget, key: KeyboardKey): bool
proc rowRect*(widget: Widget, i: int): Rect

defineWidget(CommandPalette):
  props:
    commands: seq[Command] = @[]
    placeholder: string = "Type a command"
    width: float32 = 480.0
    maxShown: int = 8
    rowHeight: float32 = 28.0
    intent: ThemeIntent = Default

  state:
    isOpen: bool
    field: TextInput
    shown: seq[tuple[index: int, match: FuzzyMatch]]   ## what the query finds, best first
    chosen: int

  init:
    let w = widget
    widget.floating = true
    widget.field = newTextInput(placeholder = widget.placeholder, intent = widget.intent)
    widget.field.onChange = proc(text: string) = w.refilter()
    widget.field.onSubmit = proc(text: string) = w.runChosen(w.chosen)
    # Plain keys do not bubble from the focused field: it hands on the ones
    # it leaves (Up/Down move the choice).
    widget.field.onKey(proc(key: KeyboardKey): bool = w.listKey(key))
    widget.addChild widget.field

  events:
    on_key_down:
      if widget.isOpen and event.key == KeyboardKey.Escape:   # bubbles from the field
        closePopupOf(widget)
        return true
      return widget.listKey(event.key)

    on_mouse_move:
      for k in 0 ..< widget.shown.len:
        if widget.rowRect(k).contains(event.mousePos.x, event.mousePos.y):
          if k != widget.chosen:
            widget.chosen = k
            widget.isDirty = true
          return true
      return false

    on_mouse_down:
      for k in 0 ..< widget.shown.len:
        if widget.rowRect(k).contains(event.mousePos.x, event.mousePos.y):
          widget.runChosen(k)
          return true
      return widget.isOpen                 # a press on the panel stays in it

  layout:
    if not widget.isOpen:
      widget.collapseMenuPanel()
      return
    var area = Rect(x: 0, y: 0, width: 800, height: 600)
    if renderView.isSome: area = renderView.get
    else:
      var top: Widget = widget
      while top.parent != nil: top = top.parent
      area = top.bounds
    let w = min(widget.width, area.width - 24)
    let rows = min(widget.shown.len, widget.maxShown)
    let pad = 8'f32
    let fieldH = 34'f32
    let h = pad * 2 + fieldH + (if rows > 0: 6 + float32(rows) * widget.rowHeight else: 0)
    widget.bounds = Rect(x: area.x + (area.width - w) / 2, y: area.y + area.height * 0.12,
                         width: w, height: h)
    widget.field.visible = true
    widget.field.arrange(Rect(x: widget.bounds.x + pad, y: widget.bounds.y + pad,
                              width: w - 2 * pad, height: fieldH))

  render:
    if not widget.isOpen: return
    widget.drawMenuPanel(widget.intent)
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    var style = props.captionStyle(ink)
    for k in 0 ..< min(widget.shown.len, widget.maxShown):
      let r = widget.rowRect(k)
      let c = widget.commands[widget.shown[k].index]
      if k == widget.chosen:
        drawBox(r, min(4'f32, props.cornerRadius.get(4.0)), accent.withAlpha(0.18),
                accent.withAlpha(0.18), 0)
      # The name, the letters that matched in bold.
      var x = r.x + 8
      let y = r.y + (r.height - style.fontSize * 1.25) / 2
      let hits = widget.shown[k].match.positions
      var i = 0
      while i < c.name.len:
        var j = i
        let bold = i in hits
        while j < c.name.len and (j in hits) == bold: inc j
        var s = style
        s.bold = bold
        let part = c.name[i ..< j]
        drawStyledText(part, x, y, s)
        x += measureText(part, s).width
        i = j
      if c.shortcut.len > 0:
        var hint = style
        hint.color = ink.withAlpha(0.6)
        hint.fontSize = max(10'f32, style.fontSize - 2)
        let sw = measureText(c.shortcut, hint).width
        drawStyledText(c.shortcut, r.x + r.width - sw - 8, y + 1, hint)

proc rowRect*(widget: Widget, i: int): Rect =
  ## Where row `i` of the shown commands is drawn -- and where a click finds it.
  let widget = CommandPalette(widget)
  let pad = 8'f32
  Rect(x: widget.bounds.x + pad, y: widget.bounds.y + pad + 34 + 6 + float32(i) * widget.rowHeight,
       width: widget.bounds.width - 2 * pad, height: widget.rowHeight)

proc refilter(widget: Widget) =
  ## The commands the field's text finds, best first; the first one chosen.
  let widget = CommandPalette(widget)
  var names: seq[string]
  for c in widget.commands: names.add c.name
  widget.shown = fuzzyRank(widget.field.text, names)
  widget.chosen = if widget.shown.len > 0: 0 else: -1
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc close*(widget: CommandPalette) =
  if not widget.isOpen: return
  widget.isOpen = false
  widget.field.visible = false
  closedPopup(widget)
  widget.hideMenuLayer()

proc open*(widget: CommandPalette) =
  ## Show it, empty, with every command, and the keyboard in its field.
  if widget.isOpen: return
  widget.isOpen = true
  widget.field.replaceText("")
  widget.refilter()
  openPopup(widget, scope = widget, close = proc() = widget.close())
  widget.showMenuLayer()
  wantFocus(widget.field)

proc runChosen(widget: Widget, i: int) =
  ## Close, then run command `i` of what is shown (closing first: a command
  ## may open a dialog that wants the keyboard).
  let widget = CommandPalette(widget)
  if i < 0 or i >= widget.shown.len: return
  let c = widget.commands[widget.shown[i].index]
  widget.close()
  if c.run != nil: c.run()

proc listKey(widget: Widget, key: KeyboardKey): bool =
  ## Up/Down (and PageUp/PageDown) move the choice. True when used.
  let widget = CommandPalette(widget)
  if not widget.isOpen or widget.shown.len == 0: return false
  let n = min(widget.shown.len, widget.maxShown)
  let next = case key
    of KeyboardKey.Down: min(n - 1, widget.chosen + 1)
    of KeyboardKey.Up: max(0, widget.chosen - 1)
    of KeyboardKey.PageDown: n - 1
    of KeyboardKey.PageUp: 0
    else: -1
  if next < 0: return false
  widget.chosen = next
  widget.isDirty = true
  true
