
# src/themes/presets/dark.nim
proc darkTheme*(): Theme =
  result = Theme(
    colors: ColorScheme(
      primary: Blue[400],
      secondary: Blue[300],
      background: rgb(18, 18, 18),
      surface: rgb(30, 30, 30),
      onPrimary: BLACK,
      onBackground: WHITE,
      error: rgb(255, 82, 82)
    ),
    typography: defaultTypography(),
    spacing: defaultSpacing()
  )
