# test/themes/test_theme_changes.nim
suite "Theme Tests":
  test "Theme changes are applied":
    var themeChanged = false
    
    # Set up observer
    app.onThemeChanged = proc() =
      themeChanged = true
    
    # Change theme
    app.setTheme(darkTheme())
    
    # Verify change was applied
    check themeChanged
    check app.theme.colors.background == DarkTheme.background

  test "Widget updates with theme":
    let button = Button()
    let initialColor = button.getComputedStyle().backgroundColor
    
    # Change theme
    app.setTheme(darkTheme())
    
    # Verify button updated
    check button.getComputedStyle().backgroundColor != initialColor