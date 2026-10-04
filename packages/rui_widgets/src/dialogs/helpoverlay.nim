## HelpOverlay -- a shade over the whole window with the keyboard bindings.
##
## F1 or "?" (the user's `showHelp` keys) shows it; any key or click closes it.
## It lists what is actually in force -- the user's own key choices -- plus any
## shortcuts the application registered with `app.addHelp`. Like MessageBox it
## covers the whole window (a widget cannot paint outside its bounds), so
## `bounds` is the window and the card is centred in it.

import rui_core
import rui_drawing
import raylib
import std/strutils

definePrimitive(HelpOverlay):
  props:
    sections: seq[HelpSection] = @[]
    title: string = "Keyboard"
    intent: ThemeIntent = Default

  render:
    let props = widget.themeProps(widget.intent)
    let ink = props.foregroundColor.get(BLACK)
    let surface = props.backgroundColor.get(WHITE)
    var head = props.captionStyle(ink, action = true)
    head.fontSize += 4
    head.bold = true
    var section = props.captionStyle(ink.withAlpha(0.65), action = true)
    var keyStyle = props.captionStyle(props.activeColor.get(ink), action = true)
    keyStyle.bold = true
    section.bold = true
    let body = props.captionStyle(ink)
    let pad = props.fieldInset * 2
    let rowH = measureText("Ag", body).height + 6

    # Size the card to its widest key column and widest description.
    var keyW, textW = 0.0'f32
    var rows = 0
    for s in widget.sections:
      rows += 1
      for e in s.entries:
        keyW = max(keyW, measureText(e.keys, keyStyle).width)
        textW = max(textW, measureText(e.text, body).width)
        rows += 1
    let headH = measureText(widget.title, head).height + pad
    let w = min(widget.bounds.width - 40, keyW + textW + 24 + pad * 2)
    let h = min(widget.bounds.height - 40, headH + float32(rows) * rowH + pad * 2)
    let card = Rect(x: widget.bounds.x + (widget.bounds.width - w) / 2,
                    y: widget.bounds.y + (widget.bounds.height - h) / 2,
                    width: w, height: h)

    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 150))      # the shade
    drawBox(card, props.cornerRadius.get(6.0), surface,
            props.borderColor.get(ink), props.strokeWidth)
    drawStyledText(widget.title, card.x + pad, card.y + pad, head)

    var y = card.y + headH + pad / 2
    for s in widget.sections:
      drawStyledText(s.title.toUpperAscii, card.x + pad, y, section)
      y += rowH
      for e in s.entries:
        drawStyledText(e.keys, card.x + pad, y, keyStyle)
        drawStyledText(e.text, card.x + pad + keyW + 24, y, body)
        y += rowH
