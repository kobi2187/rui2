

# src/themes/custom.nim
# Create custom themes by extending base themes
proc customTheme*(): Theme =
  result = lightTheme()  # Start from light theme
  result.colors.primary = rgb(103, 58, 183)  # Purple
  result.colors.secondary = rgb(81, 45, 168)
  result.typography.fontFamily = "Roboto"