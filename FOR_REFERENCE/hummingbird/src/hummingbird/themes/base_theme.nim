
# src/quickui/themes/base_theme.nim
proc baseTheme*(): ThemeDefinition =
  ## Base theme that others can extend
  result.colors = {
    crPrimary: rgb(0, 122, 255),
    crSecondary: rgb(142, 142, 147),
    crBackground: rgb(255, 255, 255)
    # etc...
  }.toTable

  result.spacing = {
    srSmall: 4.0,
    srMedium: 8.0,
    srLarge: 16.0
  }.toTable
