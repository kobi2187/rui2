## Bevels: the 3D edges of classic desktops (BeOS, Windows 98, early Mac OS).
##
## The one rectangle effect that is a style of its own rather than a surface
## finish: a theme's `bevelStyle` (Raised, Sunken, Ridge, Groove, BeRaised,
## BeSunken...) draws two rings of light and shade instead of an outline. Every
## other effect a control's box can have -- gloss, gradient, relief, shadows,
## glow, notches -- is a `BoxFinish` (sdf.nim), drawn by shapes.drawBox.

import std/options
import rui_core
import ../theme_types  # BevelStyle
import raylib


## ============================================================================
## 3D Bevel Effects (BeOS, Windows 98, Classic UIs)
## ============================================================================


type BevelEdges = object
    ## The four colours a bevel is: two for the outer ring, two for the inner.
    ##
    ## Raised and Sunken were 130 lines of identical geometry with the colours
    ## swapped. They are the same drawing with a different BevelEdges now, which
    ## is also why the six styles that used to `discard` can fall back to Raised
    ## in one line instead of staying invisible.
    outerTopLeft, outerBottomRight: Color
    innerTopLeft, innerBottomRight: Color

proc raisedEdges(highlight, shadow, darkShadow: Color): BevelEdges =
  ## Light above-left, dark below-right: the light source is up and to the left.
  BevelEdges(outerTopLeft: highlight, outerBottomRight: darkShadow,
             innerTopLeft: highlight, innerBottomRight: shadow)

proc sunkenEdges(highlight, shadow, darkShadow: Color): BevelEdges =
  ## The same light source, seen on a surface pressed into the screen.
  BevelEdges(outerTopLeft: darkShadow, outerBottomRight: highlight,
             innerTopLeft: shadow, innerBottomRight: highlight)

proc drawBevelEdges(bounds: Rect, edges: BevelEdges, bevelWidth: float32) =
  ## Two nested single-pixel rings. The coordinates are deliberately asymmetric
  ## -- the top and left stop one pixel short, the bottom and right run one
  ## past -- which is what makes the corners mitre instead of overlapping.
  let (x, y, w, h) = (bounds.x, bounds.y, bounds.width, bounds.height)

  drawLine(Vector2(x: x, y: y), Vector2(x: x + w - 1, y: y),
           1.0, edges.outerTopLeft)
  drawLine(Vector2(x: x, y: y), Vector2(x: x, y: y + h - 1),
           1.0, edges.outerTopLeft)
  drawLine(Vector2(x: x, y: y + h - 1), Vector2(x: x + w, y: y + h - 1),
           1.0, edges.outerBottomRight)
  drawLine(Vector2(x: x + w - 1, y: y), Vector2(x: x + w - 1, y: y + h),
           1.0, edges.outerBottomRight)

  if bevelWidth < 2.0:
    return

  drawLine(Vector2(x: x + 1, y: y + 1), Vector2(x: x + w - 2, y: y + 1),
           1.0, edges.innerTopLeft)
  drawLine(Vector2(x: x + 1, y: y + 1), Vector2(x: x + 1, y: y + h - 2),
           1.0, edges.innerTopLeft)
  drawLine(Vector2(x: x + 1, y: y + h - 2), Vector2(x: x + w - 1, y: y + h - 2),
           1.0, edges.innerBottomRight)
  drawLine(Vector2(x: x + w - 2, y: y + 1), Vector2(x: x + w - 2, y: y + h - 1),
           1.0, edges.innerBottomRight)

proc mixColors(a, b: Color, t: float32): Color =
  Color(r: uint8(a.r.float32 + (b.r.float32 - a.r.float32) * t),
        g: uint8(a.g.float32 + (b.g.float32 - a.g.float32) * t),
        b: uint8(a.b.float32 + (b.b.float32 - a.b.float32) * t), a: 255)

proc drawBeLayers(bounds: Rect, topLeft, bottomRight: openArray[Color]) =
  ## BeOS draws a bevel as rings from the outside in, each ring one pixel: `topLeft`
  ## colours the top and left sides, `bottomRight` the bottom and right, and the two
  ## need not be the same depth (a raised button is dark-light-white-white above-left
  ## and dark-grey-lighter-grey below-right). Measured from R5.0.1 screenshots.
  let (x, y, w, h) = (bounds.x, bounds.y, bounds.width, bounds.height)
  let rings = int(min(w, h) / 2)          # a thin bar has room for fewer rings
  for i, c in topLeft:
    if i >= rings: break
    let o = float32(i)
    drawLine(Vector2(x: x + o, y: y + o), Vector2(x: x + w - o, y: y + o), 1.0, c)
    drawLine(Vector2(x: x + o, y: y + o), Vector2(x: x + o, y: y + h - o), 1.0, c)
  for i, c in bottomRight:
    if i >= rings: break
    let o = float32(i)
    drawLine(Vector2(x: x + o, y: y + h - 1 - o), Vector2(x: x + w - o, y: y + h - 1 - o), 1.0, c)
    drawLine(Vector2(x: x + w - 1 - o, y: y + o), Vector2(x: x + w - 1 - o, y: y + h - o), 1.0, c)

proc drawRidgeOrGroove(bounds: Rect, bevelStyle: BevelStyle,
                       highlight, darkShadow: Color) =
  ## Ridge is raised-sunken-raised and Groove is sunken-raised-sunken; both
  ## want three rings. This draws one, which reads as the right direction at
  ## small sizes and as a plain border at large ones.
  ## TODO: the real three-ring version.
  drawRectangleLines(
    Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
    1.0,
    if bevelStyle == Ridge: highlight else: darkShadow)

proc bevelEdgesFor(bevelStyle: BevelStyle,
                   highlight, shadow, darkShadow: Color): Option[BevelEdges] =
  ## `none` for the styles that are not edge-pairs: Flat has no bevel, and
  ## Ridge/Groove need three rings rather than two.
  case bevelStyle
  of Flat, Ridge, Groove:
    none(BevelEdges)
  of Sunken, Interior:
    # Interior is a sunken well -- an inset content area, not a raised control.
    some(sunkenEdges(highlight, shadow, darkShadow))
  else:
    # Raised, plus Soft, Convex, Drop, Flatsoft and Flatconvex. Those five each
    # want their own softened or rounded treatment and do not have one yet;
    # until they do they render as a plain raised bevel, which is the closest
    # of the implemented styles. They used to `discard` -- setting one of them
    # in a theme drew no bevel at all, despite the comment claiming a fallback.
    some(raisedEdges(highlight, shadow, darkShadow))

proc drawBeveledRect*(
  bounds: Rect,
  bevelStyle: BevelStyle,
  backgroundColor: Color,
  cornerRadius: float32 = 0.0,
  highlightColor: Color = Color(r: 255, g: 255, b: 255, a: 255),  # White
  shadowColor: Color = Color(r: 128, g: 128, b: 128, a: 255),     # Gray
  darkShadowColor: Color = Color(r: 0, g: 0, b: 0, a: 255),       # Black
  bevelWidth: float32 = 2.0
) =
  ## Draws a rectangle with 3D bevel effect.
  ## Used for authentic BeOS, Windows 98, classic Mac OS look.
  let rect = Rectangle(x: bounds.x, y: bounds.y,
                       width: bounds.width, height: bounds.height)
  if cornerRadius > 0:
    drawRectangleRounded(rect, cornerRadius / min(bounds.width, bounds.height),
                         16, backgroundColor)
  else:
    drawRectangle(rect, backgroundColor)

  if bevelStyle in {Ridge, Groove}:
    drawRidgeOrGroove(bounds, bevelStyle, highlightColor, darkShadowColor)
    return

  if bevelStyle in {BeRaised, BeSunken}:
    let soft = mixColors(backgroundColor, shadowColor, 0.2)
    if bevelStyle == BeRaised:
      drawBeLayers(bounds, [darkShadowColor, backgroundColor, highlightColor, highlightColor],
                   [darkShadowColor, shadowColor, soft])
    else:
      drawBeLayers(bounds, [darkShadowColor, shadowColor, soft],
                   [darkShadowColor, backgroundColor, highlightColor, highlightColor])
    return

  let edges = bevelEdgesFor(bevelStyle, highlightColor, shadowColor,
                            darkShadowColor)
  if edges.isSome:
    drawBevelEdges(bounds, edges.get(), bevelWidth)
