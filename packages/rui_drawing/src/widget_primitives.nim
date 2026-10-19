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
                    Color(r: 255, g: 255, b: 255, a: 255)  # White on selected
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

proc onAccentColor(): Color =
  ## Ink for marks drawn on the accent: the primary action's text colour.
  currentTheme.getThemeProps(ThemeIntent.Info).foregroundColor.get(
    Color(r: 255, g: 255, b: 255, a: 255))

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
      drawLine(Vector2(x: x0, y: y0), Vector2(x: x1, y: y1), 2.0, ink)
      drawLine(Vector2(x: x0, y: y1), Vector2(x: x1, y: y0), 2.0, ink)
  elif checked:
    drawBox(rect, radius, accent, accent, 0)
    drawCheckmark(rect, onAccentColor(), max(2.0'f32, w * 1.25))
  else:
    let bg = if hovered: props.hoverColor.get(props.backgroundColor.get(WHITE))
             else: props.backgroundColor.get(WHITE)
    drawBox(rect, radius, bg, borderFor(props, focused, false), w)
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
  if props.bevelStyle.get(Flat) != Flat:
    # A bevelled theme: a sunken round well -- dark arc above-left, light below-right.
    let c = Vector2(x: cx, y: cy)
    drawCircle(c, r, props.highlightColor.get(WHITE))
    drawCircle(c, r - 1, bg)
    drawRing(c, r - 1.5, r, 135, 315, 24, props.shadowColor.get(GRAY))
    drawRing(c, r - 3.0, r - 1.5, 135, 315, 24, props.darkShadowColor.get(BLACK))
    if selected:
      drawCircle(c, r * 0.42, props.foregroundColor.get(BLACK))
    return
  let ringW = if selected: max(w, r * 0.3) else: w
  drawCircle(Vector2(x: cx, y: cy), r, ring)
  drawCircle(Vector2(x: cx, y: cy), max(0.0'f32, r - ringW), bg)
  if selected:
    drawCircle(Vector2(x: cx, y: cy), r * 0.38, accent)
  if focused:
    let ringColor = props.focusRingColor.get(accent)
    drawRing(Vector2(x: cx, y: cy), max(0.0'f32, r - ringW - props.focusRingWidth.get(2.0)),
             max(0.0'f32, r - ringW), 0, 360, 36, ringColor)

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
    # A bevelled theme (BeOS): a dark groove -- no fill -- and a small raised knob
    # with three dots of grip.
    let x = clamp(rect.x + rect.width * t, rect.x + d / 2, rect.x + rect.width - d / 2)
    let face = props.backgroundColor.get(Color(r: 232, g: 232, b: 232, a: 255))
    let groove = Rect(x: rect.x, y: cy - 3, width: rect.width, height: 6)
    discard drawBevelBody(groove, props, props.darkShadowColor.get(Color(r: 96, g: 96, b: 96, a: 255)),
                          style = some(BeSunken))
    let blockW = max(10.0'f32, d * 0.7)
    let knob = Rect(x: x - blockW / 2, y: cy - d / 2, width: blockW, height: d)
    discard drawBevelBody(knob, props, face, style = some(BeRaised))
    let grip = props.shadowColor.get(GRAY)
    for k in -1 .. 1:
      drawRect(Rect(x: knob.x + knob.width / 2 - 1, y: cy + float32(k) * 3 - 1, width: 2, height: 2), grip)
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

proc drawScrollbar*(rect: Rect, contentSize, viewSize, offset: float32,
                   props: ThemeProps, hovered = false) =
  ## Scrollbar = reuse existing primitive with theme colors.
  ##
  ## The primitive draws translucent tints of this colour, so the fallback --
  ## for a theme that sets no foreground, which the built-in light theme does
  ## not -- is a dark neutral. It was a light grey, and a 35% tint of light grey
  ## on a light background is invisible.
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
    # A bevelled theme (BeOS): the arrow sits in its own small raised button at
    # the field's right end, as the Be menu field does, not as a loose glyph.
    let inset = 3.0'f32
    let side = rect.height - 2 * inset
    let button = Rect(x: rect.x + rect.width - inset - side, y: rect.y + inset,
                      width: side, height: side)
    discard drawBevelBody(button, props, props.backgroundColor.get(WHITE),
                          style = some(BeRaised))
    let ink = props.foregroundColor.get(BLACK)
    let (cx, cy) = (button.x + side / 2, button.y + side / 2)
    if isOpen: drawUpArrow(cx, cy, 3.5, ink)
    else: drawDownArrow(cx, cy, 3.5, ink)
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
  let bgColor = if active:
                  props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255))
                elif hovered:
                  props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255))
                else:
                  Color(r: 220, g: 220, b: 220, a: 255)

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
  ## Spinner = interactive box + padded text + up/down buttons
  drawInteractiveBox(rect, props, focused = focused)
  drawThemedPaddedText(value, rect, props)
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
