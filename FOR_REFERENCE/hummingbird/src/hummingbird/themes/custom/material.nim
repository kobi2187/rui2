
# src/quickui/themes/custom/material.nim
proc materialTheme*(): ThemeDefinition =
  ## Material Design theme
  result = baseTheme()  # Inherit base
  
  # Override colors
  result.colors[crPrimary] = rgb(98, 0, 238)
  result.colors[crSecondary] = rgb(3, 218, 198)
  # etc...
