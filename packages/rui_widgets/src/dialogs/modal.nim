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
  if currentTheme.titleColor.isSome:
    # A coloured title *tab*, as in BeOS: only as wide as its caption, with a light
    # edge above-left and a dark one below-right, on the panel's own colour.
    let face = currentTheme.titleColor.get
    let style = result.captionStyle(Color(r: 0, g: 0, b: 0, a: 255), action = true)
    let tabW = min(panel.width, measureText(title, style).width + 56)
    let tab = Rect(x: panel.x, y: panel.y, width: tabW, height: TitleBarHeight)
    drawRect(tab, face)
    drawBeveledRect(tab, BeRaised, face, 0.0, Color(r: 255, g: 255, b: 80, a: 255),
                    Color(r: 152, g: 152, b: 152, a: 255), Color(r: 152, g: 152, b: 152, a: 255), 2.0)
    drawStyledText(title, tab.x + 32, tab.y + (tab.height - style.fontSize) / 2, style)
    return
  let titleProps = currentTheme.getThemeProps(intent, Selected)
  drawThemedBackground(titleRect, titleProps)
  drawThemedPaddedText(title, titleRect, titleProps, selected = true)
