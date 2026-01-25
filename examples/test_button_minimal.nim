## Minimal Button Test - Debug Version
## Tests basic button widget

import ../rui

proc main() =
  echo "Starting Button Test..."
  
  let app = newApp("Button Test", 600, 400)
  
  # Create button with all parameters
  let btn = newButton(
    text = "Click Me!",
    bgColor = raylib.GRAY,
    textColor = raylib.WHITE,
    disabled = false
  )
  
  btn.bounds = Rect(x: 200, y: 150, width: 200, height: 60)
  
  # Check if button type is correct
  echo "Button type: ", btn.getTypeName()
  echo "Button text: ", btn.text
  echo "Button visible: ", btn.visible
  echo "Button enabled: ", btn.enabled
  
  app.tree.root = btn
  app.run()

when isMainModule:
  main()
