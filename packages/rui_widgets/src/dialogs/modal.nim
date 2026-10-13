## Shared geometry for modal dialogs.
##
## A modal sizes its `bounds` to the whole screen, because that is the only way
## to dim what is behind it: renderPass draws each widget into a render texture
## sized to its own bounds, so a dialog sized to its panel could not paint an
## overlay around itself. The panel is then centred inside those bounds.

import rui_core
import rui_drawing

import raylib

const TitleBarHeight* = 30.0'f32

proc overlayBounds*(): Rect =
  ## The full-screen rect a modal should occupy.
  Rect(x: 0, y: 0,
       width: float32(getScreenWidth()),
       height: float32(getScreenHeight()))

proc panelRect*(bounds: Rect, width, height: float32): Rect =
  ## The dialog box, centred in the overlay.
  Rect(x: bounds.x + (bounds.width - width) / 2,
       y: bounds.y + (bounds.height - height) / 2,
       width: width, height: height)

proc drawModalFrame*(bounds, panel: Rect, title: string, intent = ThemeIntent.Default): ThemeProps =
  ## What every modal paints first: the dim backdrop over `bounds`, then the
  ## shadowed themed panel with its title bar. Returns the panel's props so the
  ## caller can draw its own content in the same colours.
  drawRect(bounds, Color(r: 0, g: 0, b: 0, a: 128))
  result = currentTheme.getThemeProps(intent, Normal)
  drawShadow(panel, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                           color: Color(r: 0, g: 0, b: 0, a: 60)))
  drawThemedBackground(panel, result)
  drawThemedBorder(panel, result)
  let titleRect = Rect(x: panel.x, y: panel.y, width: panel.width, height: TitleBarHeight)
  let titleProps = currentTheme.getThemeProps(intent, Selected)
  drawThemedBackground(titleRect, titleProps)
  drawThemedPaddedText(title, titleRect, titleProps, selected = true)
