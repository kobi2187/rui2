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
## Usage in widget render:
##   drawBeveledRect(widget.bounds, Raised, cornerRadius=0.0)
##   drawShadowedRect(widget.bounds, bgColor, shadowOffset=(4.0, 4.0))

import std/options
import ../core/types
import theme_types  # For BevelStyle - breaks circular dependency

when defined(useGraphics):
  import raylib


## ============================================================================
## 3D Bevel Effects (BeOS, Windows 98, Classic UIs)
## ============================================================================

when defined(useGraphics):
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

    # 1. Draw background
    if cornerRadius > 0:
      drawRectangleRounded(
        Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
        cornerRadius / min(bounds.width, bounds.height),
        16,  # segments
        backgroundColor
      )
    else:
      drawRectangle(
        Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
        backgroundColor
      )

    # 2. Draw bevel edges
    case bevelStyle
    of Flat:
      discard  # No bevel

    of Raised:
      # Light on top-left, dark on bottom-right
      # Outer layer (1px from edge)
      # Top edge
      drawLine(
        Vector2(x: bounds.x, y: bounds.y),
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y),
        1.0,
        highlightColor
      )
      # Left edge
      drawLine(
        Vector2(x: bounds.x, y: bounds.y),
        Vector2(x: bounds.x, y: bounds.y + bounds.height - 1),
        1.0,
        highlightColor
      )
      # Bottom edge (dark)
      drawLine(
        Vector2(x: bounds.x, y: bounds.y + bounds.height - 1),
        Vector2(x: bounds.x + bounds.width, y: bounds.y + bounds.height - 1),
        1.0,
        darkShadowColor
      )
      # Right edge (dark)
      drawLine(
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y),
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y + bounds.height),
        1.0,
        darkShadowColor
      )

      # Inner layer (2px from edge)
      if bevelWidth >= 2.0:
        # Top inner
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + 1),
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + 1),
          1.0,
          highlightColor
        )
        # Left inner
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + 1),
          Vector2(x: bounds.x + 1, y: bounds.y + bounds.height - 2),
          1.0,
          highlightColor
        )
        # Bottom inner (gray shadow)
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + bounds.height - 2),
          Vector2(x: bounds.x + bounds.width - 1, y: bounds.y + bounds.height - 2),
          1.0,
          shadowColor
        )
        # Right inner (gray shadow)
        drawLine(
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + 1),
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + bounds.height - 1),
          1.0,
          shadowColor
        )

    of Sunken:
      # INVERTED: Dark on top-left, light on bottom-right
      # Outer layer
      # Top edge (dark)
      drawLine(
        Vector2(x: bounds.x, y: bounds.y),
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y),
        1.0,
        darkShadowColor
      )
      # Left edge (dark)
      drawLine(
        Vector2(x: bounds.x, y: bounds.y),
        Vector2(x: bounds.x, y: bounds.y + bounds.height - 1),
        1.0,
        darkShadowColor
      )
      # Bottom edge (light)
      drawLine(
        Vector2(x: bounds.x, y: bounds.y + bounds.height - 1),
        Vector2(x: bounds.x + bounds.width, y: bounds.y + bounds.height - 1),
        1.0,
        highlightColor
      )
      # Right edge (light)
      drawLine(
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y),
        Vector2(x: bounds.x + bounds.width - 1, y: bounds.y + bounds.height),
        1.0,
        highlightColor
      )

      # Inner layer
      if bevelWidth >= 2.0:
        # Top inner (gray shadow)
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + 1),
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + 1),
          1.0,
          shadowColor
        )
        # Left inner (gray shadow)
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + 1),
          Vector2(x: bounds.x + 1, y: bounds.y + bounds.height - 2),
          1.0,
          shadowColor
        )
        # Bottom inner (light)
        drawLine(
          Vector2(x: bounds.x + 1, y: bounds.y + bounds.height - 2),
          Vector2(x: bounds.x + bounds.width - 1, y: bounds.y + bounds.height - 2),
          1.0,
          highlightColor
        )
        # Right inner (light)
        drawLine(
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + 1),
          Vector2(x: bounds.x + bounds.width - 2, y: bounds.y + bounds.height - 1),
          1.0,
          highlightColor
        )

    of Ridge, Groove:
      # Ridge: raised-sunken-raised
      # Groove: sunken-raised-sunken
      # For now, just draw a simple double border
      # TODO: Implement proper ridge/groove effect
      drawRectangleLines(
        Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
        1.0,
        if bevelStyle == Ridge: highlightColor else: darkShadowColor
      )

    of Soft, Convex, Drop, Interior, Flatsoft, Flatconvex:
      # TODO: These bevel styles are not yet fully implemented
      # For now, fall back to a simple raised bevel
      discard


## ============================================================================
## Gradient Effects (Mac OS X Aqua, Modern UIs)
## ============================================================================

when defined(useGraphics):
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

when defined(useGraphics):
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

when defined(useGraphics):
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

when defined(useGraphics):
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

when defined(useGraphics):
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


## ============================================================================
## Convenience: Draw Themed Rectangle
## ============================================================================

when defined(useGraphics):
  proc drawThemedRect*(
    bounds: Rect,
    props: ThemeProps
  ) =
    ## Convenience function that draws a rectangle using ThemeProps.
    ## Automatically applies the appropriate effect based on props.

    let bgColor = props.backgroundColor.get(Color(r: 200, g: 200, b: 200, a: 255))
    let cornerRadius = props.cornerRadius.get(0.0)

    # Check for special effects
    if props.bevelStyle.isSome and props.bevelStyle.get() != Flat:
      # 3D Bevel effect
      drawBeveledRect(
        bounds,
        props.bevelStyle.get(),
        bgColor,
        cornerRadius,
        props.highlightColor.get(Color(r: 255, g: 255, b: 255, a: 255)),
        props.shadowColor.get(Color(r: 128, g: 128, b: 128, a: 255)),
        props.darkShadowColor.get(Color(r: 0, g: 0, b: 0, a: 255))
      )
    elif props.gradientStart.isSome and props.gradientEnd.isSome:
      # Gradient effect
      drawGradientRect(
        bounds,
        props.gradientStart.get(),
        props.gradientEnd.get(),
        props.gradientDirection.get(Vertical),
        cornerRadius
      )
    elif props.dropShadowOffset.isSome:
      # Drop shadow effect
      let offset = props.dropShadowOffset.get()
      drawShadowedRect(
        bounds,
        bgColor,
        cornerRadius,
        offset.x,
        offset.y,
        props.dropShadowBlur.get(8.0),
        0.3  # Default opacity
      )
    elif props.glowColor.isSome:
      # Glow effect
      drawGlowRect(
        bounds,
        bgColor,
        props.glowColor.get(),
        cornerRadius,
        props.glowRadius.get(8.0)
      )
    elif props.insetShadowDepth.isSome:
      # Inset shadow effect
      drawInsetRect(
        bounds,
        bgColor,
        cornerRadius,
        props.insetShadowDepth.get(),
        props.insetShadowOpacity.get(0.2)
      )
    else:
      # Plain rectangle
      if cornerRadius > 0:
        DrawRectangleRounded(
          Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
          cornerRadius / min(bounds.width, bounds.height),
          16,
          bgColor
        )
      else:
        DrawRectangleRec(
          Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
          bgColor
        )

    # Draw border if specified
    if props.borderColor.isSome and props.borderWidth.isSome and props.borderWidth.get() > 0:
      if cornerRadius > 0:
        DrawRectangleRoundedLines(
          Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
          cornerRadius / min(bounds.width, bounds.height),
          16,
          props.borderWidth.get(),
          props.borderColor.get()
        )
      else:
        DrawRectangleLinesEx(
          Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
          props.borderWidth.get(),
          props.borderColor.get()
        )


## ============================================================================
## Clipping / Scissor Mode (for ScrollView and other clipped content)
## ============================================================================

when defined(useGraphics):
  proc beginScissorMode*(clipRect: Rect) =
    ## Begin scissor mode - all drawing will be clipped to this rectangle.
    ## Used for ScrollView to clip content to viewport.
    beginScissorMode(
      int32(clipRect.x),
      int32(clipRect.y),
      int32(clipRect.width),
      int32(clipRect.height)
    )
