## Theme-Aware Widget Drawing Primitives
##
## Forth-style compositional design: build complex widgets from simpler parts.
## Each primitive is minimal and reusable.
##
## Layer architecture:
##   Layer 1: primitives/* (drawRect, drawText, etc.)
##   Layer 2: THIS MODULE (drawButton, drawSlider, etc.)
##   Layer 3: widgets/* (Button, Slider widgets)

import rui_core
import theme_sys_core
import theme_check
import primitives/[shapes, text, controls, indicators, panels]
import pango_text  # drawTextPango
import effects/rect_effects

import raylib
import std/unicode

export types, theme_sys_core

# ============================================================================
# Simple Text Drawing Helper
# ============================================================================

proc drawText*(text: string, x, y: float32, fontSize: float32,
                color: raylib.Color, centered = false) =
  ## Simple text drawing with x, y coordinates.
  ##
  ## `y` is the top of a `fontSize`-high line -- which is what every caller
  ## assumes when it centres text with `(height - fontSize) / 2`. Pango's line
  ## box is taller than the font size (ascent + descent + leading), so drawing
  ## the glyph texture straight at `y` put every such caption a few pixels low:
  ## progress-bar percentages, checkbox and radio labels, tree rows. The line
  ## box is centred on the caller's box instead.
  ##
  ## Routed through the Pango-backed text primitive, like every other text path.
  ## It used to call raylib.drawText directly, which is why checkbox labels and
  ## progress-bar captions still rendered in the built-in bitmap font while the
  ## rest of the UI had switched to real glyphs.
  let style = TextStyle(fontFamily: "", fontSize: fontSize, color: color,
                        bold: false, italic: false, underline: false)
  let m = text.measureText(style)
  let xPos = if centered: x - m.width / 2 else: x
  let yPos = y - (m.height - fontSize) / 2
  drawTextPango(text, xPos, yPos, style.pangoFont, color)

proc drawStyledText*(text: string, x, y: float32, style: TextStyle,
                     centered = false) =
  ## drawText with a whole TextStyle, so weight and family come along.
  let m = text.measureText(style)
  let xPos = if centered: x - m.width / 2 else: x
  let yPos = y - (m.height - style.fontSize) / 2
  drawTextPango(text, xPos, yPos, style.pangoFont, style.color)

# ============================================================================
# Theme geometry: captions, strokes, shadows
# ============================================================================
#
# A brand is more than colours. These read the rest of it from ThemeProps --
# border width, corner radius, padding, caption size/weight/case and a hard
# drop shadow -- so one set of widgets can look fat and bold under one theme
# and thin and lean under another.

proc captionStyle*(props: ThemeProps, color: Color,
                   size = 14.0'f32, action = false): TextStyle =
  ## The style a control's caption is drawn in: the theme's size and family
  ## ("" falls through to the theme typography). An `action` caption -- a
  ## button's -- also takes the theme's weight; check box captions and list
  ## rows stay regular, or a bold brand would shout every line.
  TextStyle(fontFamily: props.fontFamily.get(""),
            fontSize: props.fontSize.get(size), color: color,
            bold: action and props.isBold, italic: false, underline: false)

proc captionText*(props: ThemeProps, text: string): string =
  ## A button caption as the theme shows it: in capitals, if the theme says
  ## so. Only action captions take this -- list rows and field text do not.
  if props.uppercase.get(false): unicode.toUpper(text) else: text

proc strokeWidth*(props: ThemeProps): float32 =
  ## The control outline width; 0 is borderless.
  max(0.0'f32, props.borderWidth.get(1.0))

proc controlPadding*(props: ThemeProps, x = 16.0'f32, y = 8.0'f32): EdgeInsets =
  ## Inner padding of a control, from the theme when it sets one.
  props.padding.get(EdgeInsets(left: x, right: x, top: y, bottom: y))

proc shadowOffset*(props: ThemeProps): tuple[x, y: float32] =
  ## How far a control's hard drop shadow falls, right and down.
  let o = props.dropShadowOffset.get((0.0'f32, 0.0'f32))
  (max(0.0'f32, o.x), max(0.0'f32, o.y))

proc bodyRect*(rect: Rect, props: ThemeProps, pressed = false): Rect =
  ## The part of `rect` the control itself occupies, leaving room for its drop
  ## shadow. Pressed, the body sinks into the shadow -- the press of a raised
  ## key rather than a colour change alone.
  let o = props.shadowOffset
  result = Rect(x: rect.x, y: rect.y,
                width: max(0.0'f32, rect.width - o.x),
                height: max(0.0'f32, rect.height - o.y))
  if pressed:
    result.x += o.x
    result.y += o.y

proc drawDropShadow*(rect: Rect, props: ThemeProps, pressed = false) =
  ## The hard shadow behind a control's body, unless it is pressed into it.
  let o = props.shadowOffset
  if pressed or (o.x <= 0 and o.y <= 0):
    return
  let body = bodyRect(rect, props)
  let color = props.dropShadowColor.get(Color(r: 0, g: 0, b: 0, a: 255))
  drawRoundedRect(Rect(x: body.x + o.x, y: body.y + o.y,
                       width: body.width, height: body.height),
                  props.cornerRadius.get(4.0), color)

proc getPaddingLeft*(props: ThemeProps, default: float32): float32 =
  props.padding.get(EdgeInsets(left: default, top: default, right: default, bottom: default)).left

proc drawArrow*(x, y, size: float32, angle: float32, color: raylib.Color) =
  let direction: controls.ArrowDirection = if angle == 90.0f32: ArrowDirection.Down
                  elif angle == -90.0f32: ArrowDirection.Up
                  elif angle == 0.0f32: ArrowDirection.Right
                  elif angle == 180.0f32 or angle == -180.0f32: ArrowDirection.Left
                  else: ArrowDirection.Right
  let rect = Rect(x: x - size, y: y - size, width: size * 2, height: size * 2)
  controls.drawArrow(rect, direction, color)

# ============================================================================
# Atomic Parts (smallest building blocks)
# ============================================================================

proc backgroundFor(props: ThemeProps, pressed, hovered: bool): Color =
  if pressed:
    props.pressedColor.get(props.backgroundColor.get(Color(r: 200, g: 200, b: 200, a: 255)))
  elif hovered:
    props.hoverColor.get(props.backgroundColor.get(Color(r: 220, g: 220, b: 220, a: 255)))
  else:
    props.backgroundColor.get(Color(r: 240, g: 240, b: 240, a: 255))

proc borderFor(props: ThemeProps, focused, active: bool): Color =
  if focused:
    props.focusColor.get(props.borderColor.get(Color(r: 100, g: 150, b: 255, a: 255)))
  elif active:
    props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
  else:
    props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))

proc fieldColor*(props: ThemeProps): Color =
  ## What a text field or list is filled with: white in a bevelled theme (Be's
  ## wells are white against the grey panel), else the control's own colour.
  if props.bevelStyle.get(Flat) != Flat: Color(r: 255, g: 255, b: 255, a: 255)
  else: props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255))

proc placeholderInk*(props: ThemeProps): Color =
  ## The ink for placeholder text in a field: the theme's text colour muted toward
  ## the field, then held to 4.5:1 against it. A fixed grey read on some themes and
  ## vanished on others; this one is derived from the theme that draws it.
  let field = props.fieldColor
  let text = props.foregroundColor.get(Color(r: 0, g: 0, b: 0, a: 255))
  readableInk(inkMixed(text, field, 0.45), field, 4.5)

proc bevelOf(props: ThemeProps, pressed = false): BevelStyle =
  ## The theme's bevel, flipped when pressed: a raised key pushed in goes sunken.
  result = props.bevelStyle.get(Flat)
  if pressed:
    case result
    of Raised: result = Sunken
    of BeRaised: result = BeSunken
    else: discard

proc drawBevelBody*(rect: Rect, props: ThemeProps, fill: Color,
                    pressed = false, style = none(BevelStyle)): bool =
  ## Fill and bevel in one: true when the theme has a bevel (so the caller
  ## skips its flat outline), false for a flat theme. `style` forces one
  ## (a text field is always sunken in a bevelled theme).
  let st = if style.isSome and props.bevelStyle.get(Flat) != Flat: style.get
           else: bevelOf(props, pressed)
  if st == Flat: return false
  drawBeveledRect(rect, st, fill, 0.0,
                  props.highlightColor.get(Color(r: 255, g: 255, b: 255, a: 255)),
                  props.shadowColor.get(Color(r: 128, g: 128, b: 128, a: 255)),
                  props.darkShadowColor.get(Color(r: 0, g: 0, b: 0, a: 255)),
                  max(1.0'f32, props.strokeWidth))
  true

proc drawFloatingShadow*(rect: Rect, props: ThemeProps) =
  ## The shadow under a panel that floats above the page: a menu, a dialog, a
  ## window. A flat theme gets a soft shadow, feathered over its corner radius.
  ## A bevelled theme (BeOS) has none: R5's windows and menus sat flat on the page.
  if props.bevelStyle.get(Flat) != Flat:
    return
  drawShadow(rect, Shadow(offsetX: 0.0, offsetY: 6.0, blur: 14.0, spread: -2.0,
                          color: Color(r: 0, g: 0, b: 0, a: 56),
                          radius: props.cornerRadius.get(0.0)))

proc drawThemedBackground*(rect: Rect, props: ThemeProps,
                          pressed = false, hovered = false, well = false) =
  ## Draw background with state-based color selection. In a bevelled theme the
  ## box is raised, or a white sunken `well` for a list or field.
  if well:
    if drawBevelBody(rect, props, props.fieldColor, style = some(BeSunken)): return
  elif drawBevelBody(rect, props, backgroundFor(props, pressed, hovered), pressed):
    return
  drawRoundedRect(rect, props.cornerRadius.get(4.0),
                  backgroundFor(props, pressed, hovered))

proc drawThemedBorder*(rect: Rect, props: ThemeProps, focused = false, active = false) =
  ## The theme's outline, `borderWidth` deep inside `rect`.
  let w = props.strokeWidth
  if props.bevelStyle.get(Flat) != Flat:
    return                     # the bevel is the outline
  if w > 0:
    drawRoundedRectLines(rect, props.cornerRadius.get(4.0), w,
                         borderFor(props, focused, active))

proc drawThemedFocusRing*(rect: Rect, props: ThemeProps) =
  ## The focus ring: a solid band `focusRingWidth` deep, just inside the
  ## outline. It used to be a one-pixel dashed line in a fixed width.
  let w = props.focusRingWidth.get(2.0)
  if w <= 0:
    return
  let color = props.focusRingColor.get(
    props.focusColor.get(Color(r: 100, g: 150, b: 255, a: 255)))
  let b = props.strokeWidth
  let inner = Rect(x: rect.x + b, y: rect.y + b,
                   width: rect.width - 2 * b, height: rect.height - 2 * b)
  if inner.width > 2 * w and inner.height > 2 * w:
    drawRoundedRectLines(inner, max(0.0'f32, props.cornerRadius.get(4.0) - b), w, color)

proc drawThemedText*(text: string, x, y: float32, props: ThemeProps,
                    selected = false, centered = false) =
  ## Draw a caption in the theme's colour, size, weight and case.
  let textColor = if selected:
                    # The ink on the selected background: the theme's text colour,
                    # moved toward black or white only as far as it takes to read there.
                    readableInk(props.foregroundColor.get(Color(r: 0, g: 0, b: 0, a: 255)),
                                props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255)),
                                4.5)
                  else:
                    props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
  drawStyledText(text, x, y, props.captionStyle(textColor), centered)

proc drawThemedCenteredText*(text: string, rect: Rect, props: ThemeProps,
                             selected = false) =
  ## Draw centered text in rectangle
  let textY = rect.y + (rect.height - props.fontSize.get(14.0)) / 2
  drawThemedText(text, rect.x + rect.width/2, textY, props, selected, centered = true)

proc fieldInset*(props: ThemeProps): float32 =
  ## How far text sits in from the edge of a field, list row or combo box:
  ## the theme's vertical padding, plus its outline.
  props.padding.get(EdgeInsets(top: 8.0)).top + props.strokeWidth

proc drawThemedPaddedText*(text: string, rect: Rect, props: ThemeProps,
                          selected = false) =
  ## Draw left-aligned text with padding
  let padding = props.fieldInset
  let textY = rect.y + (rect.height - props.fontSize.get(14.0)) / 2
  drawThemedText(text, rect.x + padding, textY, props, selected)

proc drawDownArrow*(x, y, size: float32, color: Color) =
  ## Draw a downward-pointing arrow
  drawArrow(x, y, size, 90.0f32, color)

proc drawUpArrow*(x, y, size: float32, color: Color) =
  ## Draw an upward-pointing arrow
  drawArrow(x, y, size, -90.0f32, color)

proc drawRightArrow*(x, y, size: float32, color: Color) =
  ## Draw a rightward-pointing arrow
  drawArrow(x, y, size, 0.0, color)

# ============================================================================
# Compound Parts (combine atomic parts)
# ============================================================================

proc drawInteractiveBox*(rect: Rect, props: ThemeProps,
                        pressed = false, hovered = false, focused = false) =
  ## Standard interactive box: drop shadow, body with its outline, and the
  ## focus ring -- every one of them sized by the theme.
  drawDropShadow(rect, props, pressed)
  let body = bodyRect(rect, props, pressed)
  if not drawBevelBody(body, props, backgroundFor(props, pressed, hovered), pressed):
    drawBox(body, props.cornerRadius.get(4.0), backgroundFor(props, pressed, hovered),
            borderFor(props, focused, false), props.strokeWidth)
  if focused:
    drawThemedFocusRing(body, props)

proc drawSelectionBackground*(rect: Rect, props: ThemeProps,
                             selected = false, hovered = false) =
  ## Draw background for selectable items (list items, menu items)
  if selected:
    let selColor = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
    drawRect(rect, selColor)
  elif hovered:
    let hoverColor = props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255))
    drawRect(rect, hoverColor)

# ============================================================================
# Widget Primitives (compose compound parts)
# ============================================================================

proc drawButton*(rect: Rect, text: string, props: ThemeProps,
                 pressed = false, hovered = false, focused = false) =
  ## Button = interactive box + centered text
  drawInteractiveBox(rect, props, pressed, hovered, focused)
  drawThemedCenteredText(text, rect, props)

proc mixTone*(a, b: Color, t: float32): Color =
  ## `a` moved `t` of the way toward `b`, opaque.
  proc lerp(x, y: uint8): uint8 = uint8(float32(x) + (float32(y) - float32(x)) * t)
  Color(r: lerp(a.r, b.r), g: lerp(a.g, b.g), b: lerp(a.b, b.b), a: 255)

proc drawCheckbox*(rect: Rect, checked: bool, props: ThemeProps,
                   hovered = false, focused = false) =
  ## A check box: an outlined square, filled with the accent and ticked when
  ## checked. Stroke, tick weight and rounding all follow the theme.
  let w = max(1.0'f32, props.strokeWidth)
  let radius = min(props.cornerRadius.get(2.0), rect.width / 4)
  let accent = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme: a sunken well, marked with an X in the ink colour. R5
    # marks a checked box with two strokes corner to corner, not a tick.
    let bg = if hovered: props.hoverColor.get(props.backgroundColor.get(WHITE))
             else: props.backgroundColor.get(WHITE)
    discard drawBevelBody(rect, props, bg, style = some(BeSunken))
    if checked:
      let i = 3.0'f32
      let ink = props.foregroundColor.get(BLACK)
      let (x0, y0) = (rect.x + i, rect.y + i)
      let (x1, y1) = (rect.x + rect.width - i, rect.y + rect.height - i)
      drawSmoothLine(Vector2(x: x0, y: y0), Vector2(x: x1, y: y1), 2.0, ink)
      drawSmoothLine(Vector2(x: x0, y: y1), Vector2(x: x1, y: y0), 2.0, ink)
  elif checked:
    drawBox(rect, radius, accent, accent, 0)
    drawCheckmark(rect, onFillInk(accent), max(2.0'f32, w * 1.25))
  else:
    let bg = if hovered: props.hoverColor.get(props.backgroundColor.get(WHITE))
             else: props.backgroundColor.get(WHITE)
    # Hover tints the outline toward the accent: a fill change alone is too faint
    # on a white box.
    let outline = if hovered and not focused: mixTone(borderFor(props, false, false), accent, 0.5)
                  else: borderFor(props, focused, false)
    drawBox(rect, radius, bg, outline, w)
  if focused:
    drawThemedFocusRing(rect, props)

proc drawRadioButton*(rect: Rect, selected: bool, props: ThemeProps,
                      hovered = false, focused = false) =
  ## A radio button: a ring the theme's stroke thick, with the accent dot.
  let w = max(1.0'f32, props.strokeWidth)
  let cx = rect.x + rect.width / 2
  let cy = rect.y + rect.height / 2
  let r = min(rect.width, rect.height) / 2
  let accent = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
  let ring = if selected: accent else: borderFor(props, focused, false)
  let bg = if hovered: props.hoverColor.get(props.backgroundColor.get(WHITE))
           else: props.backgroundColor.get(WHITE)
  let c = Vector2(x: cx, y: cy)
  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme (BeOS): a sunken round well. The dark crescent above-left and
    # the light edge below-right come from two discs, one moved by a pixel, so they
    # are smooth-edged as the rest of the control is.
    let light = props.highlightColor.get(WHITE)
    let dark = props.darkShadowColor.get(BLACK)
    let shade = props.shadowColor.get(GRAY)
    drawSmoothDisc(c, r, dark)
    drawSmoothDisc(Vector2(x: cx + 1, y: cy + 1), r - 1, light)
    drawSmoothDisc(c, r - 2, shade)
    drawSmoothDisc(Vector2(x: cx + 1, y: cy + 1), r - 3, bg)
    if selected:
      drawSmoothDisc(c, r * 0.42, props.foregroundColor.get(BLACK))
    return
  let ringW = if selected: max(w, r * 0.3) else: w
  drawSmoothDisc(c, r, ring)
  drawSmoothDisc(c, max(0.0'f32, r - ringW), bg)
  if selected:
    drawSmoothDisc(c, r * 0.38, accent)
  if focused:
    drawSmoothRing(c, max(0.0'f32, r - ringW), props.focusRingWidth.get(2.0),
                   props.focusRingColor.get(accent))

proc drawBeGroove*(x, width, cy: float32, props: ThemeProps) =
  ## A bevelled slider's track: a sunken groove, six pixels deep, centred on `cy`.
  let groove = Rect(x: x, y: cy - 3, width: width, height: 6)
  discard drawBevelBody(groove, props, props.darkShadowColor.get(Color(r: 96, g: 96, b: 96, a: 255)),
                        style = some(BeSunken))

proc drawBeKnob*(x, cy, d: float32, props: ThemeProps) =
  ## A bevelled slider's thumb: a raised block, centred on (`x`, `cy`), with three
  ## dots of grip. Shared by Slider and RangeSlider, which use one knob each.
  let face = props.backgroundColor.get(Color(r: 232, g: 232, b: 232, a: 255))
  let blockW = max(10.0'f32, d * 0.7)
  let knob = Rect(x: x - blockW / 2, y: cy - d / 2, width: blockW, height: d)
  discard drawBevelBody(knob, props, face, style = some(BeRaised))
  let grip = props.shadowColor.get(GRAY)
  for k in -1 .. 1:
    drawRect(Rect(x: knob.x + knob.width / 2 - 1, y: cy + float32(k) * 3 - 1, width: 2, height: 2), grip)

proc drawSlider*(rect: Rect, value, minVal, maxVal: float32, props: ThemeProps,
                 dragging = false, hovered = false) =
  ## A slider: a track `trackThickness` thick, filled with the accent up to a
  ## `thumbSize` thumb. A square-cornered theme gets a square track.
  let t = if maxVal > minVal: clamp((value - minVal) / (maxVal - minVal), 0.0, 1.0)
          else: 0.0'f32
  let accent = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
  let th = min(currentTheme.trackThickness, rect.height)
  let d = min(currentTheme.thumbSize, rect.height)
  let radius = min(props.cornerRadius.get(4.0), th / 2)
  let cy = rect.y + rect.height / 2
  let track = Rect(x: rect.x, y: cy - th / 2, width: rect.width, height: th)
  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme (BeOS): a dark groove -- no fill -- and a small raised knob.
    let x = clamp(rect.x + rect.width * t, rect.x + d / 2, rect.x + rect.width - d / 2)
    drawBeGroove(rect.x, rect.width, cy, props)
    drawBeKnob(x, cy, d, props)
    return
  let rail = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
  drawBox(track, radius, rail, rail, 0)
  let x = clamp(rect.x + rect.width * t, rect.x + d / 2, rect.x + rect.width - d / 2)
  drawBox(Rect(x: rect.x, y: track.y, width: x - rect.x, height: th), radius,
          accent, accent, 0)
  # The thumb: round unless the theme is square-cornered.
  let thumb = Rect(x: x - d / 2, y: cy - d / 2, width: d, height: d)
  let thumbRadius = if props.cornerRadius.get(4.0) >= 2: d / 2 else: 0.0'f32
  let w = props.strokeWidth
  if w >= 2:
    # A heavy-stroke theme outlines the thumb in its ink.
    drawBox(thumb, thumbRadius, accent,
            props.foregroundColor.get(Color(r: 0, g: 0, b: 0, a: 255)), w)
  else:
    drawBox(thumb, thumbRadius, accent, accent, 0)

proc drawProgressBar*(rect: Rect, progress: float32, props: ThemeProps) =
  ## A progress bar: the theme's rounding and outline, filled with the accent.
  let radius = min(props.cornerRadius.get(4.0), rect.height / 2)
  let w = props.strokeWidth
  let trough = props.backgroundColor.get(Color(r: 220, g: 220, b: 220, a: 255))
  if props.bevelStyle.get(Flat) != Flat:
    discard drawBevelBody(rect, props, WHITE, style = some(BeSunken))
    let p = clamp(progress, 0.0, 1.0)
    if p > 0:
      drawRect(Rect(x: rect.x + 2, y: rect.y + 2, width: (rect.width - 4) * p,
                    height: rect.height - 4),
               props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255)))
    return
  drawBox(rect, radius, trough, props.borderColor.get(trough), w)
  let p = clamp(progress, 0.0, 1.0)
  if p > 0:
    let inner = Rect(x: rect.x + w, y: rect.y + w,
                     width: (rect.width - 2 * w) * p, height: rect.height - 2 * w)
    if inner.width > 0 and inner.height > 0:
      let accent = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
      drawBox(inner, max(0.0'f32, min(radius - w, inner.width / 2)), accent, accent, 0)

proc themeBevelled*(): bool =
  ## True when the current theme draws bevels (BeOS): its scroll bars then have
  ## arrow buttons at their ends.
  currentTheme.getThemeProps(Default, Normal).bevelStyle.get(Flat) != Flat

proc scrollEndSize(bar: Rect, bevelled: bool): float32 =
  ## The side of each arrow button: a square the bar's thickness, or nothing.
  if bevelled: min(bar.width, bar.height) else: 0.0'f32

proc scrollBarEnds*(bar: Rect, bevelled = themeBevelled()): tuple[startEnd, stopEnd: Rect] =
  ## The arrow buttons at the start (top or left) and stop (bottom or right) of
  ## `bar`. Empty rects in a theme without bevels.
  let e = scrollEndSize(bar, bevelled)
  if bar.height >= bar.width:
    (Rect(x: bar.x, y: bar.y, width: bar.width, height: e),
     Rect(x: bar.x, y: bar.y + bar.height - e, width: bar.width, height: e))
  else:
    (Rect(x: bar.x, y: bar.y, width: e, height: bar.height),
     Rect(x: bar.x + bar.width - e, y: bar.y, width: e, height: bar.height))

proc scrollBarTrack*(bar: Rect, bevelled = themeBevelled()): Rect =
  ## The part of `bar` that the thumb moves in: the whole bar, less the arrow
  ## buttons. Every scroll bar's geometry -- drawing, hit tests, drags -- uses this,
  ## so an arrow is never a press on the track.
  let e = scrollEndSize(bar, bevelled)
  if bar.height >= bar.width:
    Rect(x: bar.x, y: bar.y + e, width: bar.width, height: max(0.0'f32, bar.height - 2 * e))
  else:
    Rect(x: bar.x + e, y: bar.y, width: max(0.0'f32, bar.width - 2 * e), height: bar.height)

proc drawBeArrow(button: Rect, vertical, towardStart: bool, ink: Color) =
  ## The outlined triangle on a scroll bar's arrow button.
  let cx = button.x + button.width / 2
  let cy = button.y + button.height / 2
  let s = if towardStart: -1.0'f32 else: 1.0'f32
  let (apex, b1, b2) =
    if vertical:
      (Vector2(x: cx, y: cy + 3 * s), Vector2(x: cx - 3.5, y: cy - 2.5 * s),
       Vector2(x: cx + 3.5, y: cy - 2.5 * s))
    else:
      (Vector2(x: cx + 3 * s, y: cy), Vector2(x: cx - 2.5 * s, y: cy - 3.5),
       Vector2(x: cx - 2.5 * s, y: cy + 3.5))
  drawLine(apex, b1, 1.0, ink)
  drawLine(b1, b2, 1.0, ink)
  drawLine(b2, apex, 1.0, ink)

proc drawBeScrollbar(bar: Rect, contentSize, viewSize, offset: float32, props: ThemeProps) =
  ## R5's scroll bar: a raised arrow button at each end, the track between them
  ## sunken, and a raised thumb with a grip square in its middle.
  let vertical = bar.height >= bar.width
  let ends = scrollBarEnds(bar, true)
  let face = props.backgroundColor.get(WHITE)
  let shadow = props.shadowColor.get(GRAY)
  let ink = props.foregroundColor.get(BLACK)
  let track = scrollBarTrack(bar, true)
  # The track is the face darkened toward the shadow: R5's stippled grey.
  let tone = Color(r: uint8(face.r.int - (face.r.int - shadow.r.int) * 4 div 10),
                   g: uint8(face.g.int - (face.g.int - shadow.g.int) * 4 div 10),
                   b: uint8(face.b.int - (face.b.int - shadow.b.int) * 4 div 10), a: 255)
  discard drawBevelBody(track, props, tone, style = some(BeSunken))
  let thumb = scrollThumb(track, contentSize, viewSize, offset)
  discard drawBevelBody(thumb, props, face, style = some(BeRaised))
  if thumb.width >= 9 and thumb.height >= 9:
    drawRectangleLines(int32(thumb.x + thumb.width / 2 - 3.5), int32(thumb.y + thumb.height / 2 - 3.5),
                       7, 7, shadow)
  for (button, towardStart) in [(ends.startEnd, true), (ends.stopEnd, false)]:
    if button.width > 0 and button.height > 0:
      discard drawBevelBody(button, props, face, style = some(BeRaised))
      drawBeArrow(button, vertical, towardStart, ink)

proc drawScrollbar*(rect: Rect, contentSize, viewSize, offset: float32,
                   props: ThemeProps, hovered = false) =
  ## Scrollbar = reuse existing primitive with theme colors.
  ##
  ## The primitive draws translucent tints of this colour, so the fallback --
  ## for a theme that sets no foreground, which the built-in light theme does
  ## not -- is a dark neutral. It was a light grey, and a 35% tint of light grey
  ## on a light background is invisible.
  if props.bevelStyle.get(Flat) != Flat:
    drawBeScrollbar(rect, contentSize, viewSize, offset, props)
    return
  drawScrollbar(
    rect,
    contentSize,
    viewSize,
    offset,
    props.foregroundColor.get(Color(r: 40, g: 40, b: 40, a: 255)),
    hovered
  )

proc drawMenuItem*(rect: Rect, text: string, props: ThemeProps,
                   selected = false, hovered = false, hasSubmenu = false) =
  ## Menu item = selection background + padded text + optional arrow
  drawSelectionBackground(rect, props, selected, hovered)
  drawThemedPaddedText(text, rect, props, selected)

  # Submenu arrow
  if hasSubmenu:
    let padding = props.fieldInset
    let arrowX = rect.x + rect.width - padding - 8
    let arrowY = rect.y + rect.height / 2
    let textColor = if selected:
                      Color(r: 255, g: 255, b: 255, a: 255)
                    else:
                      props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    drawRightArrow(arrowX, arrowY, 8.0, textColor)

proc drawListItem*(rect: Rect, text: string, props: ThemeProps,
                   selected = false, hovered = false, focused = false) =
  ## List item = selection background + padded text
  ## (same as menu item but without submenu arrow)
  drawSelectionBackground(rect, props, selected, hovered)
  drawThemedPaddedText(text, rect, props, selected)

proc drawComboBox*(rect: Rect, text: string, props: ThemeProps,
                   isOpen = false, hovered = false, focused = false) =
  ## Combo box = interactive box + padded text + down/up arrow
  drawInteractiveBox(rect, props, hovered = hovered, focused = focused)
  drawThemedPaddedText(text, rect, props)

  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme (BeOS): the field is one raised button, its text on the
    # left and a small arrow inside it at the right, as the Be menu field is.
    let ink = props.foregroundColor.get(BLACK)
    let (cx, cy) = (rect.x + rect.width - 10, rect.y + rect.height / 2)
    if isOpen: drawUpArrow(cx, cy, 3.0, ink)
    else: drawDownArrow(cx, cy, 3.0, ink)
    return

  # Dropdown arrow
  let padding = props.fieldInset
  let arrowX = rect.x + rect.width - padding - 8
  let arrowY = rect.y + rect.height / 2
  let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

  if isOpen:
    drawUpArrow(arrowX, arrowY, 8.0, textColor)
  else:
    drawDownArrow(arrowX, arrowY, 8.0, textColor)

proc drawWindowTab*(bar: Rect, caption: string, props: ThemeProps,
                    face: Color, active = true): Rect =
  ## The BeOS window tab: a tab only as wide as its caption, hanging from the top
  ## of the title bar, raised with a light edge above-left and a dark one
  ## below-right. `face` is the theme's titleColor while the window is active;
  ## an inactive tab is the bar's own colour, so only the caption says it is there.
  ## The left 32px are the close box's space. Returns the tab's rect.
  let style = props.captionStyle(BLACK, action = active)
  let tabW = min(bar.width, measureText(caption, style).width + 56)
  let tab = Rect(x: bar.x, y: bar.y, width: tabW, height: bar.height)
  drawRect(tab, face)
  let light = if active: Color(r: 255, g: 255, b: 80, a: 255) else: Color(r: 255, g: 255, b: 255, a: 255)
  drawBeveledRect(tab, BeRaised, face, 0.0, light,
                  Color(r: 152, g: 152, b: 152, a: 255), Color(r: 152, g: 152, b: 152, a: 255), 2.0)
  drawStyledText(caption, tab.x + 32, tab.y + (tab.height - style.fontSize) / 2, style)
  tab

proc mixTab(panel: Color): Color =
  ## An inactive tab in a bevelled theme: the panel, a little darker.
  Color(r: uint8(panel.r.int * 9 div 10), g: uint8(panel.g.int * 9 div 10),
        b: uint8(panel.b.int * 9 div 10), a: 255)

proc drawTab*(rect: Rect, text: string, props: ThemeProps,
              active = false, hovered = false) =
  ## Tab = background + bottom indicator + centered text
  # Background
  # An inactive tab sits between the panel and the window behind it, so it reads
  # on either kind of theme: a dark theme's tab is not a light grey.
  let bgColor = if active:
                  props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255))
                elif hovered:
                  props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255))
                else:
                  mixTone(props.backgroundColor.get(currentTheme.canvasColor),
                          currentTheme.canvasColor, 0.5)

  let radius = props.cornerRadius.get(4.0)
  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme: a raised tab; the active one is the panel colour and
    # runs into the page below (its bottom edge is painted over).
    let panel = props.backgroundColor.get(Color(r: 216, g: 216, b: 216, a: 255))
    discard drawBevelBody(rect, props, if active: panel else: mixTab(panel), style = some(BeRaised))
    if active:
      drawRect(Rect(x: rect.x + 1, y: rect.y + rect.height - 2, width: rect.width - 2, height: 3), panel)
    let ink = if active: props.foregroundColor.get(BLACK) else: Color(r: 96, g: 96, b: 96, a: 255)
    let style = props.captionStyle(ink, action = true)
    drawStyledText(fittedText(text, style, rect.width - 8), rect.x + rect.width/2,
                   rect.y + (rect.height - style.fontSize) / 2, style, centered = true)
    return
  drawRoundedRect(rect, radius, bgColor)

  # Active indicator bar at bottom: as thick as the theme's strokes call for.
  if active:
    let indicatorHeight = max(3.0'f32, props.strokeWidth * 1.5)
    let indicatorRect = Rect(
      x: rect.x,
      y: rect.y + rect.height - indicatorHeight,
      width: rect.width,
      height: indicatorHeight
    )
    let activeColor = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
    drawRect(indicatorRect, activeColor)

  # Text (dimmed if inactive)
  let textColor = if active:
                    props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
                  else:
                    # the ink dimmed, not a fixed grey: stays readable (>= 4.5:1) on any tab fill
                    let ink = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
                    Color(r: uint8((ink.r.int + 90) div 2),
                          g: uint8((ink.g.int + 90) div 2), b: uint8((ink.b.int + 90) div 2), a: 255)
  let style = props.captionStyle(textColor, action = true)
  drawStyledText(fittedText(text, style, rect.width - 8), rect.x + rect.width/2,
                 rect.y + (rect.height - style.fontSize) / 2, style, centered = true)

proc drawSpinnerButtons*(rect: Rect, props: ThemeProps,
                        upHovered = false, downHovered = false) =
  ## Spinner up/down buttons on the right side of a rect
  let buttonWidth = 16.0
  let buttonHeight = rect.height / 2
  let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

  # Up button
  let upRect = Rect(
    x: rect.x + rect.width - buttonWidth,
    y: rect.y,
    width: buttonWidth,
    height: buttonHeight
  )
  if upHovered:
    drawRect(upRect, props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255)))
  drawUpArrow(upRect.x + buttonWidth/2, upRect.y + buttonHeight/2, 6.0, textColor)

  # Down button
  let downRect = Rect(
    x: rect.x + rect.width - buttonWidth,
    y: rect.y + buttonHeight,
    width: buttonWidth,
    height: buttonHeight
  )
  if downHovered:
    drawRect(downRect, props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255)))
  drawDownArrow(downRect.x + buttonWidth/2, downRect.y + buttonHeight/2, 6.0, textColor)

proc drawSpinner*(rect: Rect, value: string, props: ThemeProps,
                  upHovered = false, downHovered = false, focused = false) =
  ## Spinner = interactive box + text + up/down buttons. The value is centred on the
  ## box whatever the theme's vertical padding: a theme with deep padding or a
  ## heavy border must not push the digits off the bottom edge.
  drawInteractiveBox(rect, props, focused = focused)
  let style = props.captionStyle(props.foregroundColor.get(BLACK))
  let left = props.padding.get(EdgeInsets()).left
  let body = bodyRect(rect, props, false)   # inside the shadow and the border
  drawStyledText(value, body.x + left, body.y + (body.height - style.fontSize) / 2, style)
  drawSpinnerButtons(rect, props, upHovered, downHovered)

proc drawGroupBox*(rect: Rect, title: string, props: ThemeProps) =
  ## Group box = reuse existing primitive with theme colors
  let borderColor = props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))
  let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

  # TODO: figure out enhancing ThemeProps to also include GroupBoxStyle, and other specific widgets
  let style = panels.GroupBoxStyle(
    borderStyle: panels.BorderStyle(
      style: panels.Solid,
      color: borderColor,
      width: max(1.0'f32, props.strokeWidth),
      radius: props.cornerRadius.get(4.0)
    ),
    titleStyle: props.captionStyle(textColor, action = true),
    backgroundColor: props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255)),
    titlePosition: TextAlign.Left,
    titlePadding: 8.0f32,
    titleBackgroundColor: none(Color)
  )
  panels.drawGroupBox(rect, title, style)

proc drawStatusBar*(rect: Rect, text: string, props: ThemeProps) =
  ## Status bar = background + top border + padded text
  # Background
  let bgColor = props.backgroundColor.get(Color(r: 240, g: 240, b: 240, a: 255))
  drawRect(rect, bgColor)

  # Top border
  let borderColor = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
  drawLine(rect.x, rect.y, rect.x + rect.width, rect.y, borderColor,
           max(1.0'f32, props.strokeWidth))

  # Text
  let padding = props.fieldInset
  let textY = rect.y + (rect.height - props.fontSize.get(12.0)) / 2
  let textColor = props.foregroundColor.get(Color(r: 80, g: 80, b: 80, a: 255))
  drawText(text, rect.x + padding, textY, props.fontSize.get(12.0), textColor)
