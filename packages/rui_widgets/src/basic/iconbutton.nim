## IconButton Widget - RUI2
##
## A square button showing an icon, either a text glyph (emoji / Unicode) or a
## texture loaded from disk.
##
## For a hover tip, pair it with the Tooltip widget: a button cannot draw one
## itself, because renderPass clips every widget to its own bounds.

import rui_core
import rui_drawing
import std/[options, tables]

import raylib

# Shared with the Image widget's approach: naylib textures are move-only, so
# they live in a global table and are borrowed for drawing.
var textureCache {.global.}: Table[string, Texture2D]

definePrimitive(IconButton):
  props:
    iconText: string = ""         # Text icon (e.g. "*", "OK", an emoji)
    iconTexturePath: string = ""  # Path to an icon image file
    size: float32 = 24.0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    isPressed: bool
    textureLoaded: bool
    loadFailed: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if widget.disabled:
        return false
      widget.isPressed = true
      widget.isDirty = true
      return true

    on_mouse_up:
      if not widget.isPressed or widget.disabled:
        return false
      widget.isPressed = false
      widget.isDirty = true
      if widget.onClick.isSome:
        widget.onClick.get()()
      return true

  layout:
    # Square by construction; `size` is the whole story.
    if widget.bounds.width <= 0:
      widget.bounds.width = widget.size
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.size

  render:
    let state = if widget.disabled: Disabled
                elif widget.isPressed: Pressed
                elif widget.hovered: Hovered
                elif widget.focused: Focused
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    drawInteractiveBox(widget.bounds, props, widget.isPressed,
                       widget.hovered, widget.focused)

    if widget.iconTexturePath.len > 0 and not widget.loadFailed:
      if not widget.textureLoaded:
        if widget.iconTexturePath in textureCache:
          widget.textureLoaded = true
        else:
          try:
            let texture = loadTexture(widget.iconTexturePath)
            if texture.id > 0:
              textureCache[widget.iconTexturePath] = texture
              widget.textureLoaded = true
            else:
              widget.loadFailed = true
          except CatchableError:
            widget.loadFailed = true

      if widget.textureLoaded:
        let texW = float32(textureCache[widget.iconTexturePath].width)
        let texH = float32(textureCache[widget.iconTexturePath].height)
        drawTexture(
          textureCache[widget.iconTexturePath],
          Rectangle(x: 0, y: 0, width: texW, height: texH),
          Rectangle(x: widget.bounds.x, y: widget.bounds.y,
                    width: widget.bounds.width, height: widget.bounds.height),
          Vector2(x: 0, y: 0),
          0.0,
          WHITE
        )
    elif widget.iconText.len > 0:
      drawThemedCenteredText(widget.iconText, widget.bounds, props)

    if widget.disabled:
      drawDisabledOverlay(widget.bounds)
