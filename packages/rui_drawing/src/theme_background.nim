## A theme's picture behind everything: tiled over the canvas colour.
##
## ```yaml
## background:
##   image: paper.png     # relative to the theme file
##   opacity: 0.6         # over the canvas colour (1 when left out)
##   scale: 2             # each tile at twice its size (1 when left out)
## ```
##
## or in code: `theme.assets.backgroundPattern = some("paper.png")`. The App
## draws it after clearing to the canvas colour and before the widget tree, so
## widgets that paint their own background cover it and the rest show it. One
## quad: the texture repeats (the GPU wraps its coordinates), however many tiles
## the window holds. A picture that cannot be loaded leaves the plain colour.

import std/[options, sets]
import raylib
import rui_core
import theme_sys_core
import textures

var wrapped {.global.}: HashSet[string]   # textures already set to repeat

proc hasBackgroundPicture*(theme: Theme): bool =
  theme.assets.backgroundPattern.isSome and theme.assets.backgroundPattern.get.len > 0

proc drawThemeBackground*(theme: Theme, area: Rect) =
  ## The theme's picture tiled over `area` (the window), the first tile at
  ## its top-left corner. Nothing when the theme has none, or it will not load.
  if not theme.hasBackgroundPicture or area.width <= 0 or area.height <= 0: return
  let path = theme.assets.backgroundPattern.get
  let tex = textureFor(path)
  if tex == nil: return
  if path notin wrapped:
    setTextureWrap(tex[], TextureWrap.Repeat)
    wrapped.incl path
  let scale = max(0.01'f32, theme.assets.backgroundScale.get(1.0))
  let opacity = clamp(theme.assets.backgroundPatternOpacity.get(1.0), 0, 1)
  # A source rectangle larger than the texture: the GPU repeats it.
  let src = Rectangle(x: 0, y: 0, width: area.width / scale, height: area.height / scale)
  drawTexture(tex[], src, Rectangle(x: area.x, y: area.y, width: area.width, height: area.height),
              Vector2(x: 0, y: 0), 0.0, Color(r: 255, g: 255, b: 255, a: uint8(opacity * 255)))
