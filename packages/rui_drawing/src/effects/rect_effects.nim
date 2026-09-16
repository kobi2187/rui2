## The six rectangle effects, as drawing code and nothing else.
##
## Split out of drawing_effects.nim, which was the largest file in the repo at
## 670 lines. The effects themselves concentrate genuine complexity -- 530
## lines of geometry and colour maths -- so they are not the accidental part.
## What was accidental was `drawThemedRect` sitting underneath them hard-coding
## which effects exist and in what order, so the largest file in the repo grew
## an `elif` every time one was added. That selection is now a table in
## themed_rect.nim, and this module is just the drawing.
##
## Usage in widget render:
##   drawBeveledRect(widget.bounds, Raised, cornerRadius=0.0)
##   drawShadowedRect(widget.bounds, bgColor, shadowOffset=(4.0, 4.0))

import std/options
import rui_core
import theme_types  # For BevelStyle - breaks circular dependency
import theme_sys_core
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

  let edges = bevelEdgesFor(bevelStyle, highlightColor, shadowColor,
                            darkShadowColor)
  if edges.isSome:
    drawBevelEdges(bounds, edges.get(), bevelWidth)



## ============================================================================
## Gradient Effects (Mac OS X Aqua, Modern UIs)
## ============================================================================


proc drawGradientRect*(
  bounds: Rect,
  gradientStart: Color,
  gradientEnd: Color,
  direction: GradientDirection = Vertical,
  cornerRadius: float32 = 0.0
) =
  ## Draws a rectangle with gradient fill.
  ## Used for Mac OS X Aqua, modern glossy buttons.

  # Note: Raylib doesn't have built-in rounded gradient rectangles
  # For rounded corners, we'd need to draw to a RenderTexture with shader
  # For now, only support non-rounded gradients

  if cornerRadius > 0:
    # TODO: Implement rounded gradient with RenderTexture + shader
    # For now, fall back to solid color (average of start/end)
    let avgColor = Color(
      r: uint8((int(gradientStart.r) + int(gradientEnd.r)) div 2),
      g: uint8((int(gradientStart.g) + int(gradientEnd.g)) div 2),
      b: uint8((int(gradientStart.b) + int(gradientEnd.b)) div 2),
      a: uint8((int(gradientStart.a) + int(gradientEnd.a)) div 2)
    )
    drawRectangleRounded(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      cornerRadius / min(bounds.width, bounds.height),
      16,
      avgColor
    )
  else:
    case direction
    of Vertical:
      drawRectangleGradientV(
        int32(bounds.x), int32(bounds.y),
        int32(bounds.width), int32(bounds.height),
        gradientStart, gradientEnd
      )
    of Horizontal:
      drawRectangleGradientH(
        int32(bounds.x), int32(bounds.y),
        int32(bounds.width), int32(bounds.height),
        gradientStart, gradientEnd
      )
    of Radial:
      # Raylib doesn't have radial gradient for rectangles
      # Draw concentric circles to fake it (very rough approximation)
      # TODO: Implement proper radial gradient with shader
      drawRectangleGradientV(
        int32(bounds.x), int32(bounds.y),
        int32(bounds.width), int32(bounds.height),
        gradientStart, gradientEnd
      )


## ============================================================================
## Shadow Effects (Modern Flat Design, Depth)
## ============================================================================


proc drawShadowedRect*(
  bounds: Rect,
  backgroundColor: Color,
  cornerRadius: float32 = 0.0,
  shadowOffsetX: float32 = 4.0,
  shadowOffsetY: float32 = 4.0,
  shadowBlur: float32 = 8.0,
  shadowOpacity: float32 = 0.3
) =
  ## Draws a rectangle with soft drop shadow.
  ## Creates calming depth effect for modern UIs.

  # Note: Raylib doesn't have built-in shadow blur
  # We approximate with multiple semi-transparent rectangles
  # For proper shadows, would need shader

  let shadowColor = Color(
    r: 0, g: 0, b: 0,
    a: uint8(shadowOpacity * 255.0)
  )

  # Draw shadow layers (approximating blur)
  let blurSteps = 3
  for i in 0..<blurSteps:
    let offset = float32(i) * (shadowBlur / float32(blurSteps))
    let alpha = shadowOpacity * (1.0 - float32(i) / float32(blurSteps))
    let layerColor = Color(r: 0, g: 0, b: 0, a: uint8(alpha * 255.0))

    let shadowBounds = Rect(
      x: bounds.x + shadowOffsetX + offset,
      y: bounds.y + shadowOffsetY + offset,
      width: bounds.width,
      height: bounds.height
    )

    if cornerRadius > 0:
      drawRectangleRounded(
        Rectangle(x: shadowBounds.x, y: shadowBounds.y,
                  width: shadowBounds.width, height: shadowBounds.height),
        cornerRadius / min(shadowBounds.width, shadowBounds.height),
        16,
        layerColor
      )
    else:
      drawRectangle(
        Rectangle(x: shadowBounds.x, y: shadowBounds.y,
                  width: shadowBounds.width, height: shadowBounds.height),
        layerColor
      )

  # Draw main rectangle on top
  if cornerRadius > 0:
    drawRectangleRounded(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      cornerRadius / min(bounds.width, bounds.height),
      16,
      backgroundColor
    )
  else:
    drawRectangle(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      backgroundColor
    )


## ============================================================================
## Glow Effects (Focus States, Highlights)
## ============================================================================


proc drawGlowRect*(
  bounds: Rect,
  backgroundColor: Color,
  glowColor: Color,
  cornerRadius: float32 = 0.0,
  glowRadius: float32 = 8.0,
  glowOpacity: float32 = 0.5
) =
  ## Draws a rectangle with outer glow effect.
  ## Creates welcoming highlight for focused elements.

  # Draw glow layers (expanding outward)
  let glowSteps = 4
  for i in 0..<glowSteps:
    let expansion = float32(glowSteps - i) * (glowRadius / float32(glowSteps))
    let alpha = glowOpacity * (float32(i + 1) / float32(glowSteps))
    let layerColor = Color(
      r: glowColor.r,
      g: glowColor.g,
      b: glowColor.b,
      a: uint8(alpha * 255.0)
    )

    let glowBounds = Rect(
      x: bounds.x - expansion,
      y: bounds.y - expansion,
      width: bounds.width + expansion * 2,
      height: bounds.height + expansion * 2
    )

    if cornerRadius > 0:
      drawRectangleRounded(
        Rectangle(x: glowBounds.x, y: glowBounds.y,
                  width: glowBounds.width, height: glowBounds.height),
        (cornerRadius + expansion) / min(glowBounds.width, glowBounds.height),
        16,
        layerColor
      )
    else:
      drawRectangle(
        Rectangle(x: glowBounds.x, y: glowBounds.y,
                  width: glowBounds.width, height: glowBounds.height),
        layerColor
      )

  # Draw main rectangle on top
  if cornerRadius > 0:
    drawRectangleRounded(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      cornerRadius / min(bounds.width, bounds.height),
      16,
      backgroundColor
    )
  else:
    drawRectangle(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      backgroundColor
    )


## ============================================================================
## Inner Shadow Effects (Inset Depth)
## ============================================================================


proc drawInsetRect*(
  bounds: Rect,
  backgroundColor: Color,
  cornerRadius: float32 = 0.0,
  insetDepth: float32 = 2.0,
  insetOpacity: float32 = 0.2
) =
  ## Draws a rectangle with inner shadow (recessed appearance).
  ## Creates subtle tactile depth.

  # Draw background
  if cornerRadius > 0:
    drawRectangleRounded(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      cornerRadius / min(bounds.width, bounds.height),
      16,
      backgroundColor
    )
  else:
    drawRectangle(
      Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
      backgroundColor
    )

  # Draw inner shadow (top and left edges darker)
  let shadowColor = Color(
    r: 0, g: 0, b: 0,
    a: uint8(insetOpacity * 255.0)
  )

  # Top shadow
  for i in 0..<int(insetDepth):
    let alpha = insetOpacity * (1.0 - float32(i) / insetDepth)
    let layerColor = Color(r: 0, g: 0, b: 0, a: uint8(alpha * 255.0))
    drawLine(
      Vector2(x: bounds.x, y: bounds.y + float32(i)),
      Vector2(x: bounds.x + bounds.width, y: bounds.y + float32(i)),
      1.0,
      layerColor
    )

  # Left shadow
  for i in 0..<int(insetDepth):
    let alpha = insetOpacity * (1.0 - float32(i) / insetDepth)
    let layerColor = Color(r: 0, g: 0, b: 0, a: uint8(alpha * 255.0))
    drawLine(
      Vector2(x: bounds.x + float32(i), y: bounds.y),
      Vector2(x: bounds.x + float32(i), y: bounds.y + bounds.height),
      1.0,
      layerColor
    )


## ============================================================================
## Neumorphism (Soft UI Style)
## ============================================================================


proc drawNeumorphicRect*(
  bounds: Rect,
  baseColor: Color,
  cornerRadius: float32 = 12.0,
  raised: bool = true,
  depth: float32 = 4.0
) =
  ## Draws a rectangle with neumorphic (soft UI) effect.
  ## Elements appear to extrude from same-color background.
  ## Very calming aesthetic.

  # Calculate light and dark colors (slightly lighter/darker than base)
  let lightColor = Color(
    r: uint8(min(255, int(baseColor.r) + 20)),
    g: uint8(min(255, int(baseColor.g) + 20)),
    b: uint8(min(255, int(baseColor.b) + 20)),
    a: baseColor.a
  )
  let darkColor = Color(
    r: uint8(max(0, int(baseColor.r) - 20)),
    g: uint8(max(0, int(baseColor.g) - 20)),
    b: uint8(max(0, int(baseColor.b) - 20)),
    a: baseColor.a
  )

  if raised:
    # Light shadow on top-left, dark shadow on bottom-right
    # Draw dark shadow (bottom-right)
    let shadowBounds = Rect(
      x: bounds.x + depth,
      y: bounds.y + depth,
      width: bounds.width,
      height: bounds.height
    )
    drawRectangleRounded(
      Rectangle(x: shadowBounds.x, y: shadowBounds.y,
                width: shadowBounds.width, height: shadowBounds.height),
      cornerRadius / min(shadowBounds.width, shadowBounds.height),
      16,
      darkColor
    )

    # Draw light shadow (top-left)
    let highlightBounds = Rect(
      x: bounds.x - depth,
      y: bounds.y - depth,
      width: bounds.width,
      height: bounds.height
    )
    drawRectangleRounded(
      Rectangle(x: highlightBounds.x, y: highlightBounds.y,
                width: highlightBounds.width, height: highlightBounds.height),
      cornerRadius / min(highlightBounds.width, highlightBounds.height),
      16,
      lightColor
    )
  else:
    # Inverted for pressed state
    # Light shadow on bottom-right, dark shadow on top-left
    let shadowBounds = Rect(
      x: bounds.x - depth,
      y: bounds.y - depth,
      width: bounds.width,
      height: bounds.height
    )
    drawRectangleRounded(
      Rectangle(x: shadowBounds.x, y: shadowBounds.y,
                width: shadowBounds.width, height: shadowBounds.height),
      cornerRadius / min(shadowBounds.width, shadowBounds.height),
      16,
      darkColor
    )

    let highlightBounds = Rect(
      x: bounds.x + depth,
      y: bounds.y + depth,
      width: bounds.width,
      height: bounds.height
    )
    drawRectangleRounded(
      Rectangle(x: highlightBounds.x, y: highlightBounds.y,
                width: highlightBounds.width, height: highlightBounds.height),
      cornerRadius / min(highlightBounds.width, highlightBounds.height),
      16,
      lightColor
    )

  # Draw main element on top
  drawRectangleRounded(
    Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
    cornerRadius / min(bounds.width, bounds.height),
    16,
    baseColor
  )
