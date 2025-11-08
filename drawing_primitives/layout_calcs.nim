# Size helpers
type
  Size* = object
    width*, height*: float32

proc `+`*(a, b: Size): Size =
  Size(width: a.width + b.width, height: a.height + b.height)

proc sumSizes*(sizes: openArray[Size]): Size =
  for s in sizes: result = result + s

proc maxSize*(sizes: openArray[Size]): Size =
  for s in sizes:
    result.width = max(result.width, s.width)
    result.height = max(result.height, s.height)

# Widget measurement helpers
proc totalWidth*(widgets: openArray[Widget]): float32 =
  for w in widgets: result += w.measure().width

proc totalHeight*(widgets: openArray[Widget]): float32 =
  for w in widgets: result += w.measure().height

proc maxWidth*(widgets: openArray[Widget]): float32 =
  for w in widgets: result = max(result, w.measure().width)

proc maxHeight*(widgets: openArray[Widget]): float32 =
  for w in widgets: result = max(result, w.measure().height)

# Spacing calculations
proc totalSpacing*(itemCount: int, spacing: float32): float32 =
  if itemCount <= 1: 0.0 
  else: spacing * float32(itemCount - 1)

proc spaceBetween*(available, content: float32, items: int): float32 =
  if items <= 1: 0.0
  else: (available - content) / float32(items - 1)

proc spaceAround*(available, content: float32, items: int): float32 =
  (available - content) / float32(items + 1)

proc spaceEvenly*(available, content: float32, items: int): float32 =
  (available - content) / float32(items + 2)

# Alignment helpers
proc alignedX*(width, containerWidth: float32, align: Alignment): float32 =
  case align
  of Leading, Left: 0.0
  of Center: (containerWidth - width) / 2
  of Trailing, Right: containerWidth - width
  else: 0.0

proc alignedY*(height, containerHeight: float32, align: Alignment): float32 =
  case align
  of Top: 0.0
  of Center: (containerHeight - height) / 2
  of Bottom: containerHeight - height
  else: 0.0

# Layout measurement
proc measureLine*(widgets: openArray[Widget], spacing: float32): Size =
  result.width = totalWidth(widgets) + totalSpacing(widgets.len, spacing)
  result.height = maxHeight(widgets)

# Layout position helpers
proc distributeHorizontal*(widgets: openArray[Widget], 
                         rect: Rect, 
                         justify: Justify,
                         spacing: float32): seq[float32] =
  ## Returns x coordinates for each widget
  let totalWidth = totalWidth(widgets)
  let space = case justify
    of SpaceBetween: spaceBetween(rect.width, totalWidth, widgets.len)
    of SpaceAround: spaceAround(rect.width, totalWidth, widgets.len)
    of SpaceEvenly: spaceEvenly(rect.width, totalWidth, widgets.len)
    else: spacing
  
  var x = rect.x + case justify
    of Start: 0.0
    of Center: (rect.width - totalWidth - totalSpacing(widgets.len, space)) / 2
    of End: rect.width - totalWidth - totalSpacing(widgets.len, space)
    of SpaceAround: space
    of SpaceEvenly: space
    else: 0.0
  
  for w in widgets:
    result.add(x)
    x += w.measure().width + space

# Now the layout code becomes very clear:
proc layoutHStack(stack: HStack) =
  let sizes = stack.children.mapIt(it.measure())
  let totalSize = measureLine(stack.children, stack.spacing)
  let xs = distributeHorizontal(
    stack.children, 
    stack.rect,
    stack.justify, 
    stack.spacing
  )
  
  for i, child in stack.children:
    let y = stack.rect.y + alignedY(
      sizes[i].height,
      stack.rect.height,
      stack.align
    )
    child.setPosition(xs[i], y)



proc layoutVStack(stack: VStack) =
  let sizes = stack.children.mapIt(it.measure())
  let ys = distributeVertical(
    stack.children, stack.rect, stack.justify, stack.spacing
  )
  for i, child in stack.children:
    child.setPosition(
      stack.rect.x + alignedX(sizes[i].width, stack.rect.width, stack.align),
      ys[i])

# Grid layout:
proc layoutGrid(grid: GridWidget) =
  let cellSize = Size(
    width: grid.rect.width / grid.columns.float32,
    height: grid.rect.height / grid.rows.float32
  )
  
  var row, col: int
  for child in grid.children:
    let size = child.measure()
    let x = grid.rect.x + cellSize.width * col.float32 + 
            alignedX(size.width, cellSize.width, grid.align)
    let y = grid.rect.y + cellSize.height * row.float32 + 
            alignedY(size.height, cellSize.height, grid.align)
    
    child.setPosition(x, y)
    inc col
    if col >= grid.columns:
      col = 0
      inc row

# Wrap layout (FlowLayout):
proc layoutWrap(wrap: WrapWidget) =
  var lineStart = wrap.rect.x
  var x = lineStart
  var y = wrap.rect.y
  var lineHeight = 0.0
  var lineWidgets: seq[Widget]
  
  template finishLine() =
    if lineWidgets.len > 0:
      let lineWidth = totalWidth(lineWidgets) + 
                     totalSpacing(lineWidgets.len, wrap.spacing)
      let startX = lineStart + 
                   alignedX(lineWidth, wrap.rect.width, wrap.align)
      
      var currentX = startX
      for w in lineWidgets:
        let size = w.measure()
        w.setPosition(currentX, 
          y + alignedY(size.height, lineHeight, wrap.align))
        currentX += size.width + wrap.spacing
      
      y += lineHeight + wrap.lineSpacing
      lineWidgets.setLen(0)
      lineHeight = 0.0
      x = lineStart
  
  for child in wrap.children:
    let size = child.measure()
    if x + size.width > wrap.rect.x + wrap.rect.width:
      finishLine()  # Complete current line
    
    lineWidgets.add(child)
    lineHeight = max(lineHeight, size.height)
    x += size.width + wrap.spacing
  
  finishLine()  # Handle last line

# Dock layout:
type DockPosition = enum
  Left, Top, Right, Bottom, Fill

proc layoutDock(dock: DockWidget) =
  var remainingRect = dock.rect
  
  # First pass: Position docked widgets
  for pos in [Left, Top, Right, Bottom]:
    for child in dock.children:
      if child.dockPos != pos: continue
      let size = child.measure()
      
      case pos
      of Left:
        child.setPosition(remainingRect.x, remainingRect.y)
        remainingRect.x += size.width + dock.spacing
        remainingRect.width -= size.width + dock.spacing
      of Top:
        child.setPosition(remainingRect.x, remainingRect.y)
        remainingRect.y += size.height + dock.spacing
        remainingRect.height -= size.height + dock.spacing
      of Right:
        child.setPosition(
          remainingRect.x + remainingRect.width - size.width,
          remainingRect.y)
        remainingRect.width -= size.width + dock.spacing
      of Bottom:
        child.setPosition(
          remainingRect.x,
          remainingRect.y + remainingRect.height - size.height)
        remainingRect.height -= size.height + dock.spacing
      else: discard
  
  # Second pass: Fill remaining space
  for child in dock.children:
    if child.dockPos == Fill:
      child.setPosition(remainingRect.x, remainingRect.y)
      child.resize(remainingRect.width, remainingRect.height)

# Overlay/Layer layout:
proc layoutOverlay(overlay: OverlayWidget) =
  for child in overlay.children:
    let size = child.measure()
    child.setPosition(
      overlay.rect.x + alignedX(size.width, overlay.rect.width, child.align),
      overlay.rect.y + alignedY(size.height, overlay.rect.height, child.align)
    )