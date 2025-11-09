import std/[options, strutils, tables]

import theme_sys_core
import ../core/types

proc withProps(name: string, baseProps: openArray[(ThemeIntent, ThemeProps)]): Theme =
  result = newTheme(name)
  for (intent, props) in baseProps:
    result.base[intent] = props

proc themedProps(
    bg: tuple[r, g, b: int],
    fg: tuple[r, g, b: int],
    border: tuple[r, g, b: int] = (224, 224, 224),
    paddingValue = 8.0,
    spacingValue = 8.0,
    borderWidthValue = 1.0,
    cornerRadiusValue = 4.0,
    fontSizeValue = 14.0,
    fontFamilyValue = "sans-serif"
  ): ThemeProps =
  result = ThemeProps()
  result.backgroundColor = some(makeColor(bg.r, bg.g, bg.b))
  result.foregroundColor = some(makeColor(fg.r, fg.g, fg.b))
  result.borderColor = some(makeColor(border.r, border.g, border.b))
  result.borderWidth = some(borderWidthValue.float32)
  result.cornerRadius = some(cornerRadiusValue.float32)
  result.fontSize = some(fontSizeValue.float32)
  result.fontFamily = some(fontFamilyValue)
  result.padding = some(edgeInsets(paddingValue.float32))
  result.spacing = some(spacingValue.float32)

proc makeLightTheme(): Theme =
  withProps("Modern Light", [
    (Default, themedProps((255, 255, 255), (33, 33, 33))),
    (Info, themedProps((227, 242, 253), (25, 118, 210))),
    (Success, themedProps((232, 245, 233), (46, 125, 50))),
    (Warning, themedProps((255, 243, 224), (230, 81, 0))),
    (Danger, themedProps((255, 235, 238), (198, 40, 40)))
  ])

proc makeDarkTheme(): Theme =
  withProps("Modern Dark", [
    (Default, themedProps((32, 32, 32), (255, 255, 255), border = (64, 64, 64))),
    (Info, themedProps((30, 50, 70), (100, 181, 246))),
    (Success, themedProps((30, 70, 32), (129, 199, 132))),
    (Warning, themedProps((70, 50, 30), (255, 183, 77))),
    (Danger, themedProps((70, 30, 30), (229, 115, 115)))
  ])

proc makeBeosTheme(): Theme =
  withProps("Classic BeOS", [
    (Default, themedProps((217, 217, 217), (0, 0, 0), border = (180, 180, 180), paddingValue = 4.0, spacingValue = 6.0, fontSizeValue = 12.0, cornerRadiusValue = 0.0)),
    (Info, themedProps((255, 255, 200), (0, 0, 0))),
    (Success, themedProps((200, 255, 200), (0, 100, 0))),
    (Warning, themedProps((255, 200, 150), (100, 50, 0))),
    (Danger, themedProps((255, 200, 200), (150, 0, 0)))
  ])

proc makeJoyTheme(): Theme =
  withProps("Playful", [
    (Default, themedProps((255, 253, 250), (50, 50, 50), border = (255, 200, 100), paddingValue = 12.0, spacingValue = 10.0, borderWidthValue = 2.0, cornerRadiusValue = 12.0, fontSizeValue = 15.0)),
    (Info, themedProps((200, 230, 255), (0, 100, 200))),
    (Success, themedProps((200, 255, 220), (0, 150, 50))),
    (Warning, themedProps((255, 240, 200), (200, 100, 0))),
    (Danger, themedProps((255, 220, 220), (200, 50, 50)))
  ])

proc makeWideTheme(): Theme =
  withProps("Spacious", [
    (Default, themedProps((250, 250, 250), (33, 33, 33), paddingValue = 12.0, spacingValue = 16.0, cornerRadiusValue = 8.0, fontSizeValue = 16.0)),
    (Info, themedProps((240, 247, 255), (25, 118, 210))),
    (Success, themedProps((240, 255, 244), (46, 125, 50))),
    (Warning, themedProps((255, 250, 240), (230, 81, 0))),
    (Danger, themedProps((255, 245, 245), (198, 40, 40)))
  ])

proc builtInTheme*(name: string): Theme =
  case name.toLowerAscii()
  of "light":
    makeLightTheme()
  of "dark":
    makeDarkTheme()
  of "beos":
    makeBeosTheme()
  of "joy":
    makeJoyTheme()
  of "wide":
    makeWideTheme()
  else:
    raise newException(ValueError, "Unknown built-in theme: " & name)