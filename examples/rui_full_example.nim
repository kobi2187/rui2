## Full RUI Example
##
## Demonstrates a complete app using the rui module
## with widgets, themes, and layout

import ../rui  # Single import!

proc main() =
  echo ruiVersionString()
  echo "Creating a themed button app..."
  echo ""

  # Create app
  let app = newApp(
    title = "RUI Full Example - Themed Buttons",
    width = 800,
    height = 600,
    resizable = true,
    minWidth = 600,
    minHeight = 400
  )

  # Get a built-in theme
  let theme = createDarkTheme()

  # TODO: Create some widgets when widget system is ready
  # For now just show the app window

  app.run()

when isMainModule:
  main()
