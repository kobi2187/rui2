# For HStack layout calculation
proc layoutHStack(stack: HStack, availableWidth, availableHeight: float32) =
  var x = stack.padding.left
  let y = stack.padding.top
  
  # First pass: measure children
  var totalWidth = 0.0
  var maxHeight = 0.0
  for child in stack.children:
    let size = child.measure()
    totalWidth += size.width
    maxHeight = max(maxHeight, size.height)
  
  # Add spacing between elements
  totalWidth += stack.spacing * float32(max(0, stack.children.len - 1))
  
  # Calculate vertical positions based on alignment
  for child in stack.children:
    let size = child.measure()
    var childY = case stack.align:
      of Top: y
      of Center: y + (maxHeight - size.height) / 2
      of Bottom: y + maxHeight - size.height
      of Stretch: 
        child.height = maxHeight
        y
      else: y
    
    child.setPosition(x, childY)
    x += size.width + stack.spacing

# For VStack layout calculation
proc layoutVStack(stack: VStack, availableWidth, availableHeight: float32) =
  let x = stack.padding.left
  var y = stack.padding.top
  
  # First pass: measure children
  var maxWidth = 0.0
  var totalHeight = 0.0
  for child in stack.children:
    let size = child.measure()
    maxWidth = max(maxWidth, size.width)
    totalHeight += size.height
  
  # Add spacing
  totalHeight += stack.spacing * float32(max(0, stack.children.len - 1))
  
  # Calculate horizontal positions based on alignment
  for child in stack.children:
    let size = child.measure()
    var childX = case stack.align:
      of Left: x
      of Center: x + (maxWidth - size.width) / 2
      of Right: x + maxWidth - size.width
      of Stretch:
        child.width = maxWidth
        x
      else: x
    
    child.setPosition(childX, y)
    y += size.height + stack.spacing

# For Container with wrapping
proc layoutContainer(container: Container, availableWidth, availableHeight: float32) =
  var currentLineItems: seq[Widget]
  var lineStart = container.padding.left
  var y = container.padding.top
  var x = lineStart
  var lineHeight = 0.0
  
  template finishLine() =
    # Position items in current line based on justify
    let totalWidth = currentLineItems.sumOf(w => w.width)
    let spacing = case container.layout.justify:
      of SpaceBetween: 
        if currentLineItems.len > 1:
          (availableWidth - totalWidth) / float32(currentLineItems.len - 1)
        else: 0.0
      of SpaceAround:
        (availableWidth - totalWidth) / float32(currentLineItems.len + 1)
      of SpaceEvenly:
        (availableWidth - totalWidth) / float32(currentLineItems.len + 2)
      else: container.layout.spacing
    
    x = case container.layout.justify:
      of Start: lineStart
      of Center: lineStart + (availableWidth - totalWidth - spacing * float32(currentLineItems.len - 1)) / 2
      of End: lineStart + availableWidth - totalWidth - spacing * float32(currentLineItems.len - 1)
      else: lineStart
    
    for item in currentLineItems:
      let size = item.measure()
      item.setPosition(x, y)
      x += size.width + spacing
    
    y += lineHeight + container.layout.spacing
    lineHeight = 0.0
    currentLineItems.setLen(0)
    x = lineStart

  # Layout with wrapping
  for child in container.children:
    let size = child.measure()
    
    if container.layout.wrap and x + size.width > availableWidth - container.padding.right:
      finishLine()  # Complete current line
    
    currentLineItems.add(child)
    lineHeight = max(lineHeight, size.height)
    x += size.width + container.layout.spacing
  
  if currentLineItems.len > 0:
    finishLine()  # Handle last line