# Example usage
let mainPanel = Panel(
  id: "mainPanel",
  rect: newRect(0, 0, 800, 600)
)
initConstraints(mainPanel)

let button = Button(
  id: "button",
  text: "Click me"
)
initConstraints(button)

# Add button to panel
mainPanel.addChild(button)

# Setup button constraints
button.centerX(mainPanel)
button.centerY(mainPanel)
button.width(120)
button.height(40)

# Later in the update/render cycle, constraints will be solved automatically
mainPanel.update()  # This will solve constraints recursively
mainPanel.render(ctx)
