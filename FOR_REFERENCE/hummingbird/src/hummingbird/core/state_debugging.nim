# Debug overlay toggle with Ctrl+Shift+D
when defined(debug):
  if (keyPressed(KeyD) and keyDown(KeyLeftControl) and 
      keyDown(KeyLeftShift)):
    showDebugOverlay = not showDebugOverlay

  if showDebugOverlay:
    Panel:
      position = BottomRight
      width = 300
      height = fill
      background = theme.surface.withAlpha(0.95)

      ScrollView:
        StateInspector:
          data = state  # Shows all state values
        
        WidgetInspector:
          root = app.rootWidget