## HelpOverlay -- a shade over the window that shows where the keys are.
##
## F1 or "?" (the user's `showHelp` keys) puts it up; any key or click closes it.
## It says two things:
##
## - **along the top**, one line with the general navigation keys -- the user's
##   own bindings -- and below it any application shortcuts that belong to no
##   particular widget (`app.addHelp`);
## - **beside each widget that has a shortcut** (`.shortcut("Ctrl+S")`), a small
##   badge with the chord, and an outline round the widget, so the keys for
##   *this* application appear where they apply.
##
## Like MessageBox it covers the whole window (a widget cannot paint outside its
## bounds), so `bounds` is the window.

import rui_core
import rui_drawing
import raylib

definePrimitive(HelpOverlay):
  props:
    items: seq[HelpEntry] = @[]       # the navigation keys, along the top
    notes: seq[HelpEntry] = @[]       # application shortcuts with no widget
    hints: seq[HintMark] = @[]        # a badge for each of these
    intent: ThemeIntent = Default

  render:
    let props = widget.themeProps(widget.intent)
    let ink = props.foregroundColor.get(BLACK)
    let surface = props.backgroundColor.get(WHITE)
    var line = props.captionStyle(ink)
    line.fontSize = max(11.0'f32, line.fontSize - 2)    # a slim bar: it covers the app's top
    var strong = props.captionStyle(ink, action = true)
    strong.bold = true
    strong.fontSize = line.fontSize
    # The hint badges: a sign post. The theme says how (yellow, thick border,
    # small uppercase monospace unless it says otherwise).
    let look = currentTheme.hintLook
    let badgeStyle = TextStyle(fontFamily: look.fontFamily, fontSize: look.fontSize,
                               color: look.foreground, bold: true, italic: false,
                               underline: false)
    let pad = props.fieldInset
    let lineH = measureText("Ag", line).height
    let w = widget.bounds.width

    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 150))             # the shade

    # The navigation keys, wrapped to the window's width; the application's
    # other shortcuts follow on their own rows.
    let sep = 20.0'f32
    proc rows(entries: seq[HelpEntry]): seq[seq[HelpEntry]] =
      var current: seq[HelpEntry]
      var x = 0.0'f32
      for e in entries:
        let ew = measureText(e.keys & " " & e.text, strong).width + sep
        if x + ew > w - pad * 2 and current.len > 0:
          result.add current
          current = @[]
          x = 0
        current.add e
        x += ew
      if current.len > 0: result.add current
    let navRows = rows(widget.items)
    let noteRows = rows(widget.notes)
    let rowH = lineH + 4
    let bar = Rect(x: 0, y: 0, width: w,
                   height: float32(navRows.len + noteRows.len) * rowH + pad * 2 - 4)
    drawRect(bar, surface)
    drawRect(Rect(x: 0, y: bar.height - props.strokeWidth, width: w,
                  height: max(1.0'f32, props.strokeWidth)), props.borderColor.get(ink))
    var y = pad
    proc drawRow(r: seq[HelpEntry], y: float32) =
      var x = pad
      for e in r:
        drawStyledText(e.keys, x, y, strong)
        x += measureText(e.keys & " ", strong).width
        drawStyledText(e.text, x, y, line)
        x += measureText(e.text, line).width + sep
    for r in navRows:
      drawRow(r, y)
      y += rowH
    for r in noteRows:
      drawRow(r, y)
      y += rowH

    # A badge on the top-right corner of each widget that has a hint.
    var placed: seq[Rect]
    for hint in widget.hints:
      let text = if look.uppercase: hint.keys.toUpperAscii else: hint.keys
      let tw = measureText(text, badgeStyle).width
      let th = measureText("Ag", badgeStyle).height
      let pad = 5.0'f32 + look.borderWidth
      let spot = placeBadge(hint.target, Size(width: tw + pad * 2, height: th + pad),
                            Rect(x: 2, y: bar.height + 2, width: w - 4,
                                 height: widget.bounds.height - bar.height - 4), placed)
      placed.add spot
      drawBox(spot, 3, look.background, look.border, look.borderWidth)
      drawStyledText(text, spot.x + pad, spot.y + (spot.height - th) / 2, badgeStyle)
