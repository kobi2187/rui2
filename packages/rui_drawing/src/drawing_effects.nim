## Drawing Effects Module
##
## Advanced visual effects for creating calming and inspiring UIs.
## These are helper functions that widget render code can call directly.
##
## Visual Effects:
## - 3D Bevels (BeOS, Windows 98 style)
## - Gradients (Mac OS X Aqua style)
## - Drop shadows (modern depth)
## - Glow effects (soft highlights)
## - Inner shadows (inset depth)
## - Neumorphism (soft UI style)
##
## The effects themselves live in effects/rect_effects.nim; this module is the
## themed entry point that picks one, plus scissor clipping.

import std/options
import rui_core
import theme_types
import theme_sys_core
import raylib
import effects/rect_effects

export rect_effects

## ============================================================================
## Which effect a set of ThemeProps asks for
##
## This was an if/elif chain inside drawThemedRect: cc=13, and the set of
## effects plus their precedence was control flow you had to trace. It is a
## list now, in priority order, so adding an effect is one entry rather than
## another branch in the repo's largest file.
## ============================================================================

type
  RectEffect* = object
    ## One effect, and the question that decides whether a theme wants it.
    name*: string
      ## For debugging and for tests that assert on precedence.
    wanted*: proc(props: ThemeProps): bool {.nimcall.}
    draw*: proc(bounds: Rect, props: ThemeProps, bgColor: Color,
                cornerRadius: float32) {.nimcall.}

proc wantsBevel(props: ThemeProps): bool =
  ## Flat is the absence of a bevel, not a bevel style, so it does not count.
  props.bevelStyle.isSome and props.bevelStyle.get() != Flat

proc drawBevel(bounds: Rect, props: ThemeProps, bgColor: Color,
               cornerRadius: float32) =
  drawBeveledRect(bounds, props.bevelStyle.get(), bgColor, cornerRadius,
                  props.highlightColor.get(Color(r: 255, g: 255, b: 255, a: 255)),
                  props.shadowColor.get(Color(r: 128, g: 128, b: 128, a: 255)),
                  props.darkShadowColor.get(Color(r: 0, g: 0, b: 0, a: 255)))

proc wantsGradient(props: ThemeProps): bool =
  ## Both ends, or there is no gradient to draw.
  props.gradientStart.isSome and props.gradientEnd.isSome

proc drawGradient(bounds: Rect, props: ThemeProps, bgColor: Color,
                  cornerRadius: float32) =
  drawGradientRect(bounds, props.gradientStart.get(), props.gradientEnd.get(),
                   props.gradientDirection.get(Vertical), cornerRadius)

const DefaultShadowOpacity = 0.3'f32
  ## A theme that sets dropShadowOffset but no opacity gets this. ThemeProps has
  ## no dropShadowOpacity field to read, which is why it is a constant here.

proc wantsDropShadow(props: ThemeProps): bool = props.dropShadowOffset.isSome

proc drawDropShadow(bounds: Rect, props: ThemeProps, bgColor: Color,
                    cornerRadius: float32) =
  let offset = props.dropShadowOffset.get()
  drawShadowedRect(bounds, bgColor, cornerRadius, offset.x, offset.y,
                   props.dropShadowBlur.get(8.0), DefaultShadowOpacity)

proc wantsGlow(props: ThemeProps): bool = props.glowColor.isSome

proc drawGlow(bounds: Rect, props: ThemeProps, bgColor: Color,
              cornerRadius: float32) =
  drawGlowRect(bounds, bgColor, props.glowColor.get(), cornerRadius,
               props.glowRadius.get(8.0))

proc wantsInset(props: ThemeProps): bool = props.insetShadowDepth.isSome

proc drawInset(bounds: Rect, props: ThemeProps, bgColor: Color,
               cornerRadius: float32) =
  drawInsetRect(bounds, bgColor, cornerRadius, props.insetShadowDepth.get(),
                props.insetShadowOpacity.get(0.2))

let RectEffects*: seq[RectEffect] = @[
  ## In precedence order: the first effect a theme asks for is the one drawn.
  ##
  ## The order is the one drawThemedRect's elif chain had, preserved
  ## deliberately -- a bevel wins over a gradient because a BeOS-style theme
  ## sets both and means the bevel, and a drop shadow wins over a glow because
  ## a theme that sets both is describing depth rather than emphasis.
  RectEffect(name: "bevel", wanted: wantsBevel, draw: drawBevel),
  RectEffect(name: "gradient", wanted: wantsGradient, draw: drawGradient),
  RectEffect(name: "dropShadow", wanted: wantsDropShadow, draw: drawDropShadow),
  RectEffect(name: "glow", wanted: wantsGlow, draw: drawGlow),
  RectEffect(name: "inset", wanted: wantsInset, draw: drawInset),
]

proc effectFor*(props: ThemeProps): Option[RectEffect] =
  ## The effect these props ask for, or none for a plain fill.
  for effect in RectEffects:
    if effect.wanted(props):
      return some(effect)
  none(RectEffect)

## ============================================================================
## Convenience: Draw Themed Rectangle
## ============================================================================

proc roundness(cornerRadius: float32, bounds: Rect): float32 =
  ## raylib wants roundness as a fraction of the shorter side, not pixels.
  cornerRadius / min(bounds.width, bounds.height)

proc asRectangle(bounds: Rect): Rectangle =
  Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)

proc drawPlainRect(bounds: Rect, bgColor: Color, cornerRadius: float32) =
  if cornerRadius > 0:
    drawRectangleRounded(bounds.asRectangle, roundness(cornerRadius, bounds),
                         16, bgColor)
  else:
    drawRectangle(bounds.asRectangle, bgColor)

proc drawThemedBorder(bounds: Rect, props: ThemeProps, cornerRadius: float32) =
  if props.borderColor.isNone or props.borderWidth.get(0.0) <= 0:
    return
  if cornerRadius > 0:
    drawRectangleRoundedLines(bounds.asRectangle, roundness(cornerRadius, bounds),
                              16, props.borderWidth.get(), props.borderColor.get())
  else:
    drawRectangleLines(bounds.asRectangle, props.borderWidth.get(),
                       props.borderColor.get())

proc drawThemedRect*(bounds: Rect, props: ThemeProps) =
  ## Draw a rectangle the way these ThemeProps describe it: whichever effect
  ## they ask for, then the border.
  let bgColor = props.backgroundColor.get(Color(r: 200, g: 200, b: 200, a: 255))
  let cornerRadius = props.cornerRadius.get(0.0)

  let effect = effectFor(props)
  if effect.isSome:
    effect.get().draw(bounds, props, bgColor, cornerRadius)
  else:
    drawPlainRect(bounds, bgColor, cornerRadius)

  drawThemedBorder(bounds, props, cornerRadius)

## ============================================================================
## Clipping / Scissor Mode (for ScrollView and other clipped content)
## ============================================================================

proc beginScissorMode*(clipRect: Rect) =
  ## Begin scissor mode - all drawing will be clipped to this rectangle.
  ## Used for ScrollView to clip content to viewport.
  beginScissorMode(
    int32(clipRect.x),
    int32(clipRect.y),
    int32(clipRect.width),
    int32(clipRect.height)
  )
