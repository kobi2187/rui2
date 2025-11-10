

# src/themes/presets/light.nim
import ../base
import ../palettes/material

proc lightTheme*(): Theme =
  result = Theme(
    colors: ColorScheme(
      primary: Blue[500],
      secondary: Blue[700],
      background: Gray[50],
      surface: WHITE,
      onPrimary: WHITE,
      onBackground: Gray[900],
      error: rgb(211, 47, 47)
    ),
    typography: defaultTypography(),
    spacing: defaultSpacing()
  )
