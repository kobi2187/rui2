## ImageWidget - Display images from files
##
## A widget for displaying images (PNG, JPG, BMP, etc.) with various fit modes.
## Supports onClick actions and automatic texture loading/caching.
##
## Usage:
##   ImageWidget(
##     imagePath = "assets/logo.png",
##     width = 200.0,
##     height = 200.0,
##     fitMode = ImageFit.Contain
##   )

import ../../../core/widget_dsl
import std/[options, tables]

when defined(useGraphics):
  import raylib

# Image fit modes (similar to CSS object-fit)
type
  ImageFit* = enum
    Contain  ## Scale to fit within bounds, maintaining aspect ratio
    Cover    ## Scale to cover bounds, maintaining aspect ratio (may crop)
    Fill     ## Stretch to fill bounds (may distort)
    None     ## Display at original size (may crop)
    ScaleDown ## Like Contain but never scale up

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
      if not widget.disabled and widget.onClick.isSome:
        widget.isPressed = true
        return true
      return false

    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false
        if widget.onClick.isSome:
          widget.onClick.get()()
        return true
      return false

  render:
    when defined(useGraphics):
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
            let texture = loadTexture(widget.imagePath.cstring)
            if texture.id > 0:
              textureCache[widget.imagePath] = texture
              widget.textureLoaded = true
            else:
              widget.loadFailed = true
          except:
            widget.loadFailed = true

      # Draw the texture if loaded
      if widget.textureLoaded and widget.imagePath in textureCache:
        let texture = textureCache[widget.imagePath]
        let texWidth = float(texture.width)
        let texHeight = float(texture.height)

        var destRect: Rectangle
        var sourceRect = Rectangle(x: 0, y: 0, width: texWidth, height: texHeight)

        case widget.fitMode:
        of ImageFit.Fill:
          # Stretch to fill entire bounds
          destRect = Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y,
            width: widget.bounds.width,
            height: widget.bounds.height
          )

        of ImageFit.Contain:
          # Scale to fit within bounds, maintaining aspect ratio
          let widgetAspect = widget.bounds.width / widget.bounds.height
          let imageAspect = texWidth / texHeight

          if imageAspect > widgetAspect:
            # Image is wider - fit to width
            let scaledHeight = widget.bounds.width / imageAspect
            destRect = Rectangle(
              x: widget.bounds.x,
              y: widget.bounds.y + (widget.bounds.height - scaledHeight) / 2,
              width: widget.bounds.width,
              height: scaledHeight
            )
          else:
            # Image is taller - fit to height
            let scaledWidth = widget.bounds.height * imageAspect
            destRect = Rectangle(
              x: widget.bounds.x + (widget.bounds.width - scaledWidth) / 2,
              y: widget.bounds.y,
              width: scaledWidth,
              height: widget.bounds.height
            )

        of ImageFit.Cover:
          # Scale to cover bounds, maintaining aspect ratio (may crop)
          let widgetAspect = widget.bounds.width / widget.bounds.height
          let imageAspect = texWidth / texHeight

          if imageAspect > widgetAspect:
            # Image is wider - fit to height and crop sides
            let scaledWidth = widget.bounds.height * imageAspect
            destRect = Rectangle(
              x: widget.bounds.x + (widget.bounds.width - scaledWidth) / 2,
              y: widget.bounds.y,
              width: scaledWidth,
              height: widget.bounds.height
            )
          else:
            # Image is taller - fit to width and crop top/bottom
            let scaledHeight = widget.bounds.width / imageAspect
            destRect = Rectangle(
              x: widget.bounds.x,
              y: widget.bounds.y + (widget.bounds.height - scaledHeight) / 2,
              width: widget.bounds.width,
              height: scaledHeight
            )

        of ImageFit.None:
          # Display at original size (centered, may crop)
          destRect = Rectangle(
            x: widget.bounds.x + (widget.bounds.width - texWidth) / 2,
            y: widget.bounds.y + (widget.bounds.height - texHeight) / 2,
            width: texWidth,
            height: texHeight
          )

        of ImageFit.ScaleDown:
          # Like Contain but never scale up
          if texWidth <= widget.bounds.width and texHeight <= widget.bounds.height:
            # Image fits - center it at original size
            destRect = Rectangle(
              x: widget.bounds.x + (widget.bounds.width - texWidth) / 2,
              y: widget.bounds.y + (widget.bounds.height - texHeight) / 2,
              width: texWidth,
              height: texHeight
            )
          else:
            # Image too large - scale down like Contain
            let widgetAspect = widget.bounds.width / widget.bounds.height
            let imageAspect = texWidth / texHeight

            if imageAspect > widgetAspect:
              let scaledHeight = widget.bounds.width / imageAspect
              destRect = Rectangle(
                x: widget.bounds.x,
                y: widget.bounds.y + (widget.bounds.height - scaledHeight) / 2,
                width: widget.bounds.width,
                height: scaledHeight
              )
            else:
              let scaledWidth = widget.bounds.height * imageAspect
              destRect = Rectangle(
                x: widget.bounds.x + (widget.bounds.width - scaledWidth) / 2,
                y: widget.bounds.y,
                width: scaledWidth,
                height: widget.bounds.height
              )

        # Draw the texture
        drawTexturePro(
          texture,
          sourceRect,
          destRect,
          Vector2(x: 0, y: 0),
          0.0,  # rotation
          widget.tintColor
        )

        # Optional: Draw border when hovered (if clickable)
        if widget.onClick.isSome: # and widget.isHovered.get():
          drawRectangleLines(
            widget.bounds.x.int32,
            widget.bounds.y.int32,
            widget.bounds.width.int32,
            widget.bounds.height.int32,
            Color(r: 100, g: 100, b: 255, a: 200)
          )

      elif widget.loadFailed:
        # Failed to load - draw error placeholder
        DrawRectangle(
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
        drawText("Load Failed".cstring, centerX.int32, centerY.int32, 16, RED)
    else:
      # Non-graphics mode fallback
      if widget.imagePath.len > 0:
        echo "ImageWidget: [", widget.imagePath, "] ", widget.width, "x", widget.height
      else:
        echo "ImageWidget: [No image]"
