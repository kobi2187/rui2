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
## Textures live in a module-level `{.global.}` cache keyed by path, shared by
## every ImageWidget in the process, so the same logo in twenty rows is one
## upload. Nothing evicts from it -- naylib's Texture is move-only, and an image
## a widget still points at must not be unloaded underneath it. The cache is
## therefore bounded by the number of distinct paths an app ever shows.
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
import std/[options, tables]
import image_fit
export image_fit

import raylib

# Cache for loaded textures to avoid reloading
var textureCache {.global.}: Table[string, Texture2D]

definePrimitive(ImageWidget):
  props:
    imagePath: string = ""       # Path to image file
    width: float = 100.0          # Widget width
    height: float = 100.0         # Widget height
    fitMode: ImageFit = ImageFit.Contain
    tintColor: Color = Color()   # Default color (white/no tint when graphics enabled)
    disabled: bool = false

  state:
    textureLoaded: bool
    loadFailed: bool
    isPressed: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled and widget.onClick != nil:
        widget.isPressed = true
        return true
      return false

    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false
        if widget.onClick != nil:
          widget.onClick()
        return true
      return false

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
      let centerX = widget.bounds.x + widget.bounds.width / 2 - 20
      let centerY = widget.bounds.y + widget.bounds.height / 2 - 10
      drawText("No Image", centerX.int32, centerY.int32, 20'i32, GRAY)
      return

    # Try to load texture if not already loaded
    if not widget.textureLoaded and not widget.loadFailed:
      if widget.imagePath in textureCache:
        widget.textureLoaded = true
      else:
        try:
          let texture = loadTexture(widget.imagePath)
          if texture.id > 0:
            textureCache[widget.imagePath] = texture
            widget.textureLoaded = true
          else:
            widget.loadFailed = true
        except:
          widget.loadFailed = true

    # Draw the texture if loaded
    if widget.textureLoaded and widget.imagePath in textureCache:
      # Borrow the cached texture (naylib Texture is move-only)
      let texWidth = float(textureCache[widget.imagePath].width)
      let texHeight = float(textureCache[widget.imagePath].height)

      let sourceRect = Rectangle(x: 0, y: 0, width: texWidth, height: texHeight)
      let destRect = destinationFor(widget.fitMode, widget.bounds,
                                    texWidth, texHeight)

      # Draw the texture
      drawTexture(
        textureCache[widget.imagePath],
        sourceRect,
        destRect,
        Vector2(x: 0, y: 0),
        0.0,  # rotation
        widget.tintColor
      )

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
      let centerX = widget.bounds.x + widget.bounds.width / 2 - 30
      let centerY = widget.bounds.y + widget.bounds.height / 2 - 10
      drawText("Load Failed", centerX.int32, centerY.int32, 16, RED)