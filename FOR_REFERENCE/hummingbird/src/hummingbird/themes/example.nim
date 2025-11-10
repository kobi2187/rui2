
# Usage in widgets
defineWidget CustomCard:
  props:
    title: string
    content: string
    
  render:
    Panel:
      padding = theme.spacing.unit * 2
      background = theme.colors.surface
      cornerRadius = 8
      elevation = 2
      
      vstack:
        spacing = theme.spacing.unit
        
        text(widget.title,
          style = theme.typography.h6,
          color = theme.colors.onSurface)
        
        text(widget.content,
          style = theme.typography.body2,
          color = theme.colors.onSurface.withAlpha(0.6))

# Application with theme switching
type AppState = object 
  isDark: Store[bool]
  customTheme: Store[bool]

proc main() =
  var state = AppState(
    isDark: Store[bool](value: false),
    customTheme: Store[bool](value: false)
  )

  app.run:
    # Theme selection
    theme = 
      if state.isDark.value:
        darkTheme()
      elif state.customTheme.value:
        customTheme()
      else:
        lightTheme()
