## Simple RUI Example
##
## Demonstrates using the single rui module import
## instead of importing individual modules

import ../rui  # Single import gives access to everything!

proc main() =
  # Create app using rui module
  let app = newApp(
    title = "Simple RUI Example",
    width = 600,
    height = 400,
    resizable = true,
    minWidth = 400,
    minHeight = 300
  )

  echo ruiVersionString()
  echo ""

  # Run the app
  app.run()

when isMainModule:
  main()
