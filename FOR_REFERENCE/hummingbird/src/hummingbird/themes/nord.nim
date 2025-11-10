# themes/nord.nim
import quickui/themes/types

proc nordTheme*(): Theme =
  const
    nord0 = rgb(46, 52, 64)    # Polar Night
    nord1 = rgb(59, 66, 82)
    nord4 = rgb(216, 222, 233) # Snow Storm
    nord7 = rgb(143, 188, 187) # Frost
    nord8 = rgb(136, 192, 208)
    nord11 = rgb(191, 97, 106) # Aurora
    nord14 = rgb(163, 190, 140)

  Theme(
    colors: ColorScheme(
      primary: nord8,
      secondary: nord7,
      background: nord0,
      surface: nord1,
      onPrimary: nord0,
      onSurface: nord4,
      error: nord11,
      success: nord14
    ),
    typography: TypographyScheme(
      fontFamily: "Fira Code",
      h1: TextStyle(size: 32, weight: Light),
      body1: TextStyle(size: 16, weight: Regular)
    ),
    spacing: SpacingScheme(
      unit: 8.0,
      scale: [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]
    )
  )

# themes/solarized.nim
proc solarizedLight*(): Theme =
  const
    base03 = rgb(0, 43, 54)
    base3 = rgb(253, 246, 227)
    blue = rgb(38, 139, 210)
    cyan = rgb(42, 161, 152)
    red = rgb(220, 50, 47)

  Theme(
    colors: ColorScheme(
      primary: blue,
      secondary: cyan,
      background: base3,
      # ...
    )
    # ...
  )

# themes/custom_corporate.nim
proc corporateTheme*(): Theme =
  const 
    brandBlue = rgb(0, 82, 204)  # Your company's colors
    brandGray = rgb(66, 82, 110)

  Theme(
    colors: ColorScheme(
      primary: brandBlue,
      secondary: brandGray,
      # ...
    ),
    typography: TypographyScheme(
      fontFamily: "Helvetica Neue",
      # ...
    )
  )

# Usage in your app
import themes/[nord, solarized, custom_corporate]

type ThemeKind = enum
  tkLight, tkDark, tkNord, tkSolarized, tkCorporate

# In app:
var currentTheme = Store[ThemeKind](value: tkLight)

app.run:
  theme = case currentTheme.get()
  of tkLight: lightTheme()
  of tkDark: darkTheme()
  of tkNord: nordTheme()
  of tkSolarized: solarizedLight()
  of tkCorporate: corporateTheme()