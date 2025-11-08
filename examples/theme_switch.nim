## Theme Switch Demo
##
## Press SPACE to toggle between light and dark themes loaded from disk.

import raylib
import std/[options, os, strformat]

import ../drawing_primitives/theme_load
import ../drawing_primitives/theme_sys_core

proc colorOr(defaultColor: Color, opt: Option[Color]): Color =
  if opt.isSome:
    opt.get()
  else:
    defaultColor

proc floatOr(defaultValue: float32, opt: Option[float32]): float32 =
  if opt.isSome:
    opt.get()
  else:
    defaultValue

proc main() =
  let projectDir = parentDir(getAppDir())
  let lightThemePath = joinPath(projectDir, "examples/themes/light.yaml")
  let darkThemePath = joinPath(projectDir, "examples/themes/dark.yaml")

  var lightTheme = loadThemeFromFile(lightThemePath)
  var darkTheme = loadThemeFromFile(darkThemePath)
  var useDark = false

  initWindow(800, 600, "RUI Theme Switch Demo")
  defer: closeWindow()
  setTargetFPS(60)

  while not windowShouldClose():
    if isKeyPressed(KeyboardKey.Space):
      useDark = not useDark

    let activeTheme = if useDark: darkTheme else: lightTheme
    let defaultProps = activeTheme.getThemeProps(Default, Normal)
    let hoveredProps = activeTheme.getThemeProps(Default, Hovered)

    let backgroundColor = colorOr(RayWhite, defaultProps.backgroundColor)
    let foregroundColor = colorOr(Color(r: 35, g: 35, b: 35, a: 255), defaultProps.foregroundColor)
    let hoveredColor = colorOr(Color(r: 200, g: 200, b: 200, a: 255), hoveredProps.backgroundColor)
    let borderColor = colorOr(Color(r: 120, g: 120, b: 120, a: 255), defaultProps.borderColor)
    let cornerRadius = floatOr(8.0, defaultProps.cornerRadius)

    beginDrawing()
    clearBackground(Color(r: 32, g: 32, b: 42, a: 255))

    drawText("Press SPACE to toggle theme", 20, 20, 24, RAYWHITE)
    drawText(fmt"Active theme: {activeTheme.name}", 20, 50, 18, RAYWHITE)

    let previewRect = Rectangle(x: 220, y: 180, width: 360, height: 200)
    drawRectangleRounded(previewRect, cornerRadius / min(previewRect.width, previewRect.height), 12, backgroundColor)
    drawRectangleRoundedLines(previewRect, cornerRadius / min(previewRect.width, previewRect.height), 12, 2, borderColor)

    let hoveredRect = Rectangle(x: 250, y: 230, width: 300, height: 120)
    drawRectangleRounded(hoveredRect, cornerRadius / min(hoveredRect.width, hoveredRect.height), 12, hoveredColor)

    let textColor = colorOr(Color(r: 0, g: 0, b: 0, a: 255), defaultProps.foregroundColor)
    drawText("Default", int32(hoveredRect.x) + 16, int32(hoveredRect.y) + 16, 20, foregroundColor)
    drawText("Hovered state", int32(hoveredRect.x) + 16, int32(hoveredRect.y) + 52, 20, textColor)

    endDrawing()

when isMainModule:
  main()

