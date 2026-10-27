## ImageWidget - Display images from files
##
## A widget for displaying images (PNG, JPG, BMP, etc.) with various fit modes.
## Supports onClick actions and automatic texture loading/caching.
##
## Loading happens on the first `render`, not in the constructor, and that is
## load-bearing: constructing a widget must not require a GL context, or the
## widget could not be built or unit-tested before the window opens. A missing
## file sets `loadFailed` and draws the placeholder rather than raising.
##
## Textures come from rui_drawing's shared cache (textures.nim `textureFor`),
## keyed by path and shared with every other widget that shows a picture (an
## Avatar), so the same logo in twenty rows is one upload.
##
## The fit modes follow CSS object-fit, and all five are computed against
## `bounds`, which `render` overwrites from the `width`/`height` props each
## frame. An ImageWidget does not size itself to its image: it sizes the image
## to itself.
##
## Usage:
##   ImageWidget(
##     imagePath = "assets/logo.png",
##     width = 200.0,
##     height = 200.0,
##     fitMode = ImageFit.Contain
##   )

import rui_core
import ../press
import std/options
import image_fit
import rui_drawing
export image_fit

import raylib


template drawNotice(widget: untyped, message: string, tint: Color) =
  ## A short message centred in the image's box, in the real font. These used
  ## raylib's bitmap drawText at a guessed offset, which clipped in any box
  ## narrower than the guess ("Load Faile").
  drawText(message, widget.bounds,
           TextStyle(fontFamily: "", fontSize: 12.0, color: tint),
           TextAlign.Center)

definePrimitive(ImageWidget):
  props:
    imagePath: string = ""       # Path to image file
    width: float = 100.0          # Widget width
    height: float = 100.0         # Widget height
    fitMode: ImageFit = ImageFit.Contain
    tintColor: Color = WHITE     # Multiplies the image; white leaves it as it is
    disabled: bool = false

  state:
    textureLoaded: bool
    loadFailed: bool

  actions:
    onClick()

  init:
    widget.makePressable(keyboard = false)

  events:
    on_mouse_down: return widget.pressDown(event, not widget.disabled and widget.onClick != nil)

    on_mouse_up:
      return widget.pressUp(event):
        if widget.onClick != nil: widget.onClick()

  render:
    # Update bounds to match width/height props
    widget.bounds.width = widget.width
    widget.bounds.height = widget.height

    if widget.imagePath.len == 0:
      # No image path - draw placeholder
      drawRectangleLines(
        widget.bounds.x.int32,
        widget.bounds.y.int32,
        widget.bounds.width.int32,
        widget.bounds.height.int32,
        Color(r: 200, g: 200, b: 200, a: 255)
      )
      widget.drawNotice("No image", GRAY)
      return

    # The picture, from the shared cache (loaded on first use).
    let tex = textureFor(widget.imagePath)
    widget.textureLoaded = tex != nil
    widget.loadFailed = textureFailed(widget.imagePath)
    if tex != nil:
      let texWidth = float(tex[].width)
      let texHeight = float(tex[].height)
      let sourceRect = Rectangle(x: 0, y: 0, width: texWidth, height: texHeight)
      let destRect = destinationFor(widget.fitMode, widget.bounds, texWidth, texHeight)
      drawTexture(tex[], sourceRect, destRect, Vector2(x: 0, y: 0), 0.0, widget.tintColor)

      # Optional: Draw border when hovered (if clickable)
      if widget.onClick != nil: # and widget.isHovered.get():
        drawRectangleLines(
          widget.bounds.x.int32,
          widget.bounds.y.int32,
          widget.bounds.width.int32,
          widget.bounds.height.int32,
          Color(r: 100, g: 100, b: 255, a: 200)
        )

    elif widget.loadFailed:
      # Failed to load - draw error placeholder
      drawRectangle(
        widget.bounds.x.int32,
        widget.bounds.y.int32,
        widget.bounds.width.int32,
        widget.bounds.height.int32,
        Color(r: 240, g: 240, b: 240, a: 255)
      )
      drawRectangleLines(
        widget.bounds.x.int32,
        widget.bounds.y.int32,
        widget.bounds.width.int32,
        widget.bounds.height.int32,
        Color(r: 200, g: 100, b: 100, a: 255)
      )
      widget.drawNotice("Load failed", RED)