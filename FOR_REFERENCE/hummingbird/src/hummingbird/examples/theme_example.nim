

# Usage in app
import quickui/themes/[base_theme, material, nord]

# Create custom theme
proc myAppTheme*(): ThemeDefinition =
  result = materialTheme()  # Start with material
  
  # Custom overrides
  result.colors[crPrimary] = rgb(255, 45, 85)
  result.spacing[srLarge] = 24.0

  # Add custom color roles
  result.colors["highlight"] = rgb(255, 200, 0)
  result.colors["sidebar"] = rgb(20, 20, 20)

# Using themes
app.run:
  # Set active theme
  theme = case state.theme.get():
    of tmLight: lightTheme()
    of tmDark: darkTheme()
    of tmNord: nordTheme()
  
  # Use theme values
  Panel:
    background = theme.colors[crBackground]
    padding = theme.spacing[srMedium]
    
    text("Hello",
      style = theme.typography[frHeadline])

# Component-specific theming
defineWidget CustomButton:
  props:
    variant: ButtonVariant
  
  render:
    let style = case widget.variant:
      of bvPrimary:
        ButtonStyle(
          background: theme.colors[crPrimary],
          textColor: WHITE
        )
      of bvSecondary:
        ButtonStyle(
          background: TRANSPARENT,
          textColor: theme.colors[crPrimary],
          border: some(Border(
            color: theme.colors[crPrimary],
            width: 1
          ))
        )

    container:
      background = style.background
      padding = theme.spacing[srMedium]
      # etc...