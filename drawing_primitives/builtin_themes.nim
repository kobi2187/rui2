## Built-in Themes for RUI2
##
## Five base themes with different personalities:
## - light: Modern light theme
## - dark: Modern dark theme
## - beos: Classic BeOS (sharp corners, classic colors)
## - joy: Playful (very rounded, vibrant)
## - wide: Spacious (larger padding/spacing)

import std/[tables, options]
import theme_sys_core
import ../core/types

proc makeThemeProps*(
  backgroundColor: Color = Color(),
  foregroundColor: Color = Color(),
  borderColor: Color = Color(),
  borderWidth: float32 = 0.0,
  cornerRadius: float32 = 0.0,
  fontSize: float32 = 0.0,
  spacing: float32 = 0.0,
  paddingAll: float32 = 0.0,
  paddingH: float32 = 0.0,
  paddingV: float32 = 0.0
): ThemeProps =
  result = ThemeProps()

  when defined(useGraphics):
    if backgroundColor.a > 0:
      result.backgroundColor = some(backgroundColor)
    if foregroundColor.a > 0:
      result.foregroundColor = some(foregroundColor)
    if borderColor.a > 0:
      result.borderColor = some(borderColor)

  if borderWidth > 0:
    result.borderWidth = some(borderWidth)
  if cornerRadius >= 0:
    result.cornerRadius = some(cornerRadius)
  if fontSize > 0:
    result.fontSize = some(fontSize)
  if spacing > 0:
    result.spacing = some(spacing)

  if paddingAll > 0:
    result.padding = some(EdgeInsets(top: paddingAll, right: paddingAll, bottom: paddingAll, left: paddingAll))
  elif paddingH > 0 or paddingV > 0:
    result.padding = some(EdgeInsets(top: paddingV, right: paddingH, bottom: paddingV, left: paddingH))

# Light Theme
proc createLightTheme*(): Theme =
  result = newTheme("Modern Light")

  when defined(useGraphics):
    result.base[Default] = makeThemeProps(
      backgroundColor = makeColor(255, 255, 255),
      foregroundColor = makeColor(33, 33, 33),
      borderColor = makeColor(224, 224, 224),
      borderWidth = 1.0,
      cornerRadius = 4.0,
      fontSize = 14.0,
      paddingAll = 8.0,
      spacing = 8.0
    )

    result.base[Info] = makeThemeProps(
      backgroundColor = makeColor(227, 242, 253),
      foregroundColor = makeColor(25, 118, 210)
    )

    result.base[Success] = makeThemeProps(
      backgroundColor = makeColor(232, 245, 233),
      foregroundColor = makeColor(46, 125, 50)
    )

    result.base[Warning] = makeThemeProps(
      backgroundColor = makeColor(255, 243, 224),
      foregroundColor = makeColor(230, 81, 0)
    )

    result.base[Danger] = makeThemeProps(
      backgroundColor = makeColor(255, 235, 238),
      foregroundColor = makeColor(198, 40, 40)
    )

    # State overrides
    result.states[Default][Disabled] = makeThemeProps(
      backgroundColor = makeColor(245, 245, 245),
      foregroundColor = makeColor(158, 158, 158)
    )

    result.states[Default][Hovered] = makeThemeProps(
      backgroundColor = makeColor(250, 250, 250)
    )

    result.states[Default][Pressed] = makeThemeProps(
      backgroundColor = makeColor(240, 240, 240)
    )

# Dark Theme
proc createDarkTheme*(): Theme =
  result = newTheme("Modern Dark")

  when defined(useGraphics):
    result.base[Default] = makeThemeProps(
      backgroundColor = makeColor(32, 32, 32),
      foregroundColor = makeColor(255, 255, 255),
      borderColor = makeColor(64, 64, 64),
      borderWidth = 1.0,
      cornerRadius = 4.0,
      fontSize = 14.0,
      paddingAll = 8.0,
      spacing = 8.0
    )

    result.base[Info] = makeThemeProps(
      backgroundColor = makeColor(30, 50, 70),
      foregroundColor = makeColor(100, 181, 246)
    )

    result.base[Success] = makeThemeProps(
      backgroundColor = makeColor(30, 70, 32),
      foregroundColor = makeColor(129, 199, 132)
    )

    result.base[Warning] = makeThemeProps(
      backgroundColor = makeColor(70, 50, 30),
      foregroundColor = makeColor(255, 183, 77)
    )

    result.base[Danger] = makeThemeProps(
      backgroundColor = makeColor(70, 30, 30),
      foregroundColor = makeColor(229, 115, 115)
    )

    # State overrides
    result.states[Default][Hovered] = makeThemeProps(
      backgroundColor = makeColor(48, 48, 48)
    )

    result.states[Default][Pressed] = makeThemeProps(
      backgroundColor = makeColor(24, 24, 24)
    )

# BeOS Theme (Authentic)
proc createBeosTheme*(): Theme =
  result = newTheme("Classic BeOS (Authentic)")

  when defined(useGraphics):
    # Create base with 3D bevel for authentic BeOS look
    result.base[Default] = ThemeProps(
      backgroundColor: some(makeColor(217, 217, 217)),    # BeOS gray
      foregroundColor: some(makeColor(0, 0, 0)),
      bevelStyle: some(Raised),                           # 3D raised button
      highlightColor: some(makeColor(255, 255, 255)),     # White highlight
      shadowColor: some(makeColor(153, 153, 153)),        # Gray shadow
      darkShadowColor: some(makeColor(102, 102, 102)),    # Dark shadow
      cornerRadius: some(0.0),                            # Sharp corners!
      fontSize: some(12.0),
      padding: some(EdgeInsets(top: 4.0, right: 6.0, bottom: 4.0, left: 6.0)),
      spacing: some(6.0)
    )

    result.base[Info] = ThemeProps(
      backgroundColor: some(makeColor(255, 255, 200)),
      foregroundColor: some(makeColor(0, 0, 0)),
      bevelStyle: some(Raised),
      highlightColor: some(makeColor(255, 255, 255)),
      shadowColor: some(makeColor(200, 200, 150)),
      darkShadowColor: some(makeColor(150, 150, 100))
    )

    result.base[Success] = ThemeProps(
      backgroundColor: some(makeColor(200, 255, 200)),
      foregroundColor: some(makeColor(0, 100, 0)),
      bevelStyle: some(Raised),
      highlightColor: some(makeColor(255, 255, 255)),
      shadowColor: some(makeColor(150, 200, 150)),
      darkShadowColor: some(makeColor(100, 150, 100))
    )

    result.base[Warning] = ThemeProps(
      backgroundColor: some(makeColor(255, 200, 150)),
      foregroundColor: some(makeColor(100, 50, 0)),
      bevelStyle: some(Raised),
      highlightColor: some(makeColor(255, 255, 255)),
      shadowColor: some(makeColor(200, 150, 100)),
      darkShadowColor: some(makeColor(150, 100, 50))
    )

    result.base[Danger] = ThemeProps(
      backgroundColor: some(makeColor(255, 200, 200)),
      foregroundColor: some(makeColor(150, 0, 0)),
      bevelStyle: some(Raised),
      highlightColor: some(makeColor(255, 255, 255)),
      shadowColor: some(makeColor(200, 150, 150)),
      darkShadowColor: some(makeColor(150, 100, 100))
    )

    # State overrides - pressed buttons get sunken bevel
    result.states[Default][Pressed] = ThemeProps(
      bevelStyle: some(Sunken)  # Invert bevel when pressed!
    )
    result.states[Info][Pressed] = ThemeProps(bevelStyle: some(Sunken))
    result.states[Success][Pressed] = ThemeProps(bevelStyle: some(Sunken))
    result.states[Warning][Pressed] = ThemeProps(bevelStyle: some(Sunken))
    result.states[Danger][Pressed] = ThemeProps(bevelStyle: some(Sunken))

    # Disabled state - no bevel
    result.states[Default][Disabled] = ThemeProps(
      backgroundColor: some(makeColor(204, 204, 204)),
      foregroundColor: some(makeColor(153, 153, 153)),
      bevelStyle: some(Flat)
    )

# Joy Theme (Playful)
proc createJoyTheme*(): Theme =
  result = newTheme("Playful")

  when defined(useGraphics):
    result.base[Default] = makeThemeProps(
      backgroundColor = makeColor(255, 253, 250),
      foregroundColor = makeColor(50, 50, 50),
      borderColor = makeColor(255, 200, 100),
      borderWidth = 2.0,
      cornerRadius = 12.0,  # Very rounded!
      fontSize = 15.0,
      paddingAll = 12.0,
      spacing = 10.0
    )

    result.base[Info] = makeThemeProps(
      backgroundColor = makeColor(200, 230, 255),
      foregroundColor = makeColor(0, 100, 200)
    )

    result.base[Success] = makeThemeProps(
      backgroundColor = makeColor(200, 255, 220),
      foregroundColor = makeColor(0, 150, 50)
    )

    result.base[Warning] = makeThemeProps(
      backgroundColor = makeColor(255, 240, 200),
      foregroundColor = makeColor(200, 100, 0)
    )

    result.base[Danger] = makeThemeProps(
      backgroundColor = makeColor(255, 220, 220),
      foregroundColor = makeColor(200, 50, 50)
    )

# Wide Theme (Spacious)
proc createWideTheme*(): Theme =
  result = newTheme("Spacious")

  when defined(useGraphics):
    result.base[Default] = makeThemeProps(
      backgroundColor = makeColor(250, 250, 250),
      foregroundColor = makeColor(33, 33, 33),
      borderColor = makeColor(224, 224, 224),
      borderWidth = 1.0,
      cornerRadius = 8.0,
      fontSize = 16.0,  # Larger text
      paddingH = 16.0,
      paddingV = 12.0,  # More padding
      spacing = 16.0   # More spacing
    )

    result.base[Info] = makeThemeProps(
      backgroundColor = makeColor(240, 247, 255),
      foregroundColor = makeColor(25, 118, 210)
    )

    result.base[Success] = makeThemeProps(
      backgroundColor = makeColor(240, 255, 244),
      foregroundColor = makeColor(46, 125, 50)
    )

    result.base[Warning] = makeThemeProps(
      backgroundColor = makeColor(255, 250, 240),
      foregroundColor = makeColor(230, 81, 0)
    )

    result.base[Danger] = makeThemeProps(
      backgroundColor = makeColor(255, 245, 245),
      foregroundColor = makeColor(198, 40, 40)
    )

# Theme registry
var builtinThemes* = initTable[string, Theme]()

proc initBuiltinThemes*() =
  builtinThemes["light"] = createLightTheme()
  builtinThemes["dark"] = createDarkTheme()
  builtinThemes["beos"] = createBeosTheme()
  builtinThemes["joy"] = createJoyTheme()
  builtinThemes["wide"] = createWideTheme()

# Automatically initialize when module is imported
initBuiltinThemes()

proc getBuiltinTheme*(name: string): Theme =
  if name in builtinThemes:
    result = builtinThemes[name]
  else:
    # Default to light theme
    result = builtinThemes["light"]
