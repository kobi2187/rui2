## Built-in Themes for RUI2
##
## The branded themes (brand_themes.nim) -- daylight, midnight, aurora, ocean,
## forest, rose, ember, graphite -- plus three with a different construction:
## - light: the Daylight brand
## - dark: the Midnight brand
## - beos: Classic BeOS (sharp corners, classic colors)
## - joy: Playful (very rounded, vibrant)
## - wide: Spacious (larger padding/spacing)

import std/[tables, options]
import theme_sys_core
import rui_core
import brand_themes
export brand_themes

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
  paddingV: float32 = 0.0,
  focusRingColor: Color = Color(),
  focusRingWidth: float32 = 0.0,
  focusGlowRadius: float32 = 0.0,
  focusGlowColor: Color = Color()
): ThemeProps =
  result = ThemeProps()

  if backgroundColor.a > 0:
    result.backgroundColor = some(backgroundColor)
  if foregroundColor.a > 0:
    result.foregroundColor = some(foregroundColor)
  if borderColor.a > 0:
    result.borderColor = some(borderColor)
  if focusRingColor.a > 0:
    result.focusRingColor = some(focusRingColor)
  if focusGlowColor.a > 0:
    result.focusGlowColor = some(focusGlowColor)

  if borderWidth > 0:
    result.borderWidth = some(borderWidth)
  if cornerRadius >= 0:
    result.cornerRadius = some(cornerRadius)
  if fontSize > 0:
    result.fontSize = some(fontSize)
  if spacing > 0:
    result.spacing = some(spacing)
  if focusRingWidth > 0:
    result.focusRingWidth = some(focusRingWidth)
  if focusGlowRadius > 0:
    result.focusGlowRadius = some(focusGlowRadius)

  if paddingAll > 0:
    result.padding = some(EdgeInsets(top: paddingAll, right: paddingAll, bottom: paddingAll, left: paddingAll))
  elif paddingH > 0 or paddingV > 0:
    result.padding = some(EdgeInsets(top: paddingV, right: paddingH, bottom: paddingV, left: paddingH))

# Light Theme
proc createLightTheme*(): Theme =
  ## "light": the Daylight brand (brand_themes.nim).
  result = brandTheme(daylightSpec())

proc createDarkTheme*(): Theme =
  ## "dark": the Midnight brand (brand_themes.nim).
  result = brandTheme(midnightSpec())

const beosFontFamily = "Nimbus Sans, Liberation Sans, Helvetica, Arial, sans-serif"
  ## BeOS shipped Swiss 721, a Helvetica-class sans. Pango takes this list in
  ## order and uses the first family the machine has, so the look holds where
  ## only the common fallbacks are installed.

proc createBeosTheme*(): Theme =
  ## BeOS R4/R5: the grey panel, one-pixel bevels (white inside the top-left,
  ## soft grey inside the bottom-right), square corners, 12px sans, no hover
  ## effect, a pushed button gone darker with its bevel inverted, text fields
  ## and troughs sunk, and the Be blue (0, 0, 229) for focus and fills.
  ## The greys are Be's own tints of the 216 panel: 255, 232, 216, 184, 152, 96.
  let panel = Color(r: 216, g: 216, b: 216, a: 255)
  let white = Color(r: 255, g: 255, b: 255, a: 255)
  let grey152 = Color(r: 152, g: 152, b: 152, a: 255)
  let grey96 = Color(r: 96, g: 96, b: 96, a: 255)
  let pushed = Color(r: 216, g: 216, b: 216, a: 255)
  let black = Color(r: 0, g: 0, b: 0, a: 255)
  let beBlue = Color(r: 0, g: 0, b: 229, a: 255)

  var spec = BrandSpec(
    name: "BeOS", accent: beBlue, onAccent: white,
    canvas: panel, surface: Color(r: 232, g: 232, b: 232, a: 255), text: black, border: grey96, radius: 0,
    fontFamily: beosFontFamily, fontSize: 12, padding: 4, paddingX: 10, borderWidth: 2, focusRingWidth: 1,
    controlHeight: 22, indicatorSize: 14, trackThickness: 6, thumbSize: 14,
    progressHeight: 14, rowHeight: 18, scrollbarThickness: 14, noTransitions: true)
  result = brandTheme(spec)
  result.name = "Classic BeOS"
  result.titleColor = some(Color(r: 255, g: 203, b: 0, a: 255))   # the yellow window tab

  proc bevelled(p: var ThemeProps) =
    p.bevelStyle = some(BeRaised)
    p.highlightColor = some(white)
    p.shadowColor = some(grey152)
    p.darkShadowColor = some(grey96)
    p.cornerRadius = some(0.0'f32)
    p.dropShadowOffset = none(tuple[x, y: float32])
    p.borderWidth = some(2.0'f32)
    p.focusRingColor = some(beBlue)
    p.focusRingWidth = some(1.0'f32)

  for intent in ThemeIntent:
    var base = result.base[intent]
    bevelled(base)
    base.backgroundColor = some(Color(r: 232, g: 232, b: 232, a: 255))   # R5 buttons are lighter than the panel
    base.foregroundColor = some(black)
    base.borderColor = some(grey96)
    base.activeColor = some(beBlue)
    base.hoverColor = base.backgroundColor   # Be shows no hover effect
    base.pressedColor = some(pushed)
    base.fontFamily = none(string)
    result.base[intent] = base
    # Pressed: darker face, the bevel pushed in. Hover changes nothing.
    result.states[intent][Hovered] = ThemeProps(backgroundColor: base.backgroundColor)
    result.states[intent][Pressed] = ThemeProps(backgroundColor: some(pushed),
                                                bevelStyle: some(BeSunken))
    result.states[intent][Focused] = ThemeProps(borderColor: some(grey96),
                                                focusRingColor: some(beBlue))
    result.states[intent][Selected] = ThemeProps(backgroundColor: some(grey152),
                                                 foregroundColor: some(black))
    # R5's disabled label grey is 128 (its own B_DISABLED_LABEL_COLOR), measured on
    # the disabled "Open" in the file dialog screenshot.
    var off = ThemeProps(backgroundColor: some(panel),
                         foregroundColor: some(Color(r: 128, g: 128, b: 128, a: 255)),
                         bevelStyle: some(BeRaised))
    result.states[intent][Disabled] = off

# Joy Theme (Playful)
proc createJoyTheme*(): Theme =
  result = newTheme("Playful")

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
  for (key, theme) in brandThemes():
    builtinThemes[key] = theme

# Automatically initialize when module is imported
initBuiltinThemes()

proc getBuiltinTheme*(name: string): Theme =
  if name in builtinThemes:
    result = builtinThemes[name]
  else:
    # Default to light theme
    result = builtinThemes["light"]
