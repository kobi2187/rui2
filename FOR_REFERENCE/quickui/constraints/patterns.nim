# constraints/patterns.nim
proc sidebar*(widget: Widget, side: Side = sLeft, width: float32) =
  ## Creates a sidebar pattern with fixed width
  widget.addConstraints:
    case side
    of sLeft:
      left = parent.left
      width = width.fixed
      top = parent.top
      bottom = parent.bottom
    of sRight:
      right = parent.right
      width = width.fixed
      top = parent.top
      bottom = parent.bottom

proc content*(widget: Widget, sidebar: Widget) =
  ## Content area that adapts to sidebar
  widget.addConstraints:
    if sidebar.side == sLeft:
      left = sidebar.right + parent.spacing.medium
    else:
      right = sidebar.left - parent.spacing.medium
    top = parent.top
    bottom = parent.bottom
    width = fill  # Takes remaining space

proc toolbar*(widget: Widget, height: float32 = 40) =
  ## Fixed height toolbar at top
  widget.addConstraints:
    top = parent.top
    left = parent.left
    right = parent.right
    height = height.fixed

proc statusbar*(widget: Widget, height: float32 = 24) =
  ## Fixed height status bar at bottom
  widget.addConstraints:
    bottom = parent.bottom
    left = parent.left
    right = parent.right
    height = height.fixed

proc split*(first, second: Widget, direction: Direction, ratio: float32 = 0.5) =
  ## Split container into two parts
  case direction
  of dHorizontal:
    first.addConstraints:
      left = parent.left
      top = parent.top
      bottom = parent.bottom
      width = parent.width * ratio
    second.addConstraints:
      right = parent.right
      top = parent.top
      bottom = parent.bottom
      width = parent.width * (1 - ratio)
  of dVertical:
    first.addConstraints:
      top = parent.top
      left = parent.left
      right = parent.right
      height = parent.height * ratio
    second.addConstraints:
      bottom = parent.bottom
      left = parent.left
      right = parent.right
      height = parent.height * (1 - ratio)

proc grid*(widget: Widget, columns: int, spacing: float32 = 8) =
  ## Arrange children in a grid
  let columnWidth = (parent.width - (columns-1).float32 * spacing) / columns.float32
  
  for i, child in widget.children:
    let col = i mod columns
    let row = i div columns
    
    child.addConstraints:
      left = parent.left + (columnWidth + spacing) * col.float32
      top = parent.top + (child.height + spacing) * row.float32
      width = columnWidth

proc masonry*(widget: Widget, columns: int, spacing: float32 = 8) =
  ## Masonry layout (like Pinterest)
  var columnHeights = newSeq[float32](columns)
  let columnWidth = (parent.width - (columns-1).float32 * spacing) / columns.float32
  
  for child in widget.children:
    # Find shortest column
    let col = columnHeights.minIndex
    
    child.addConstraints:
      left = parent.left + (columnWidth + spacing) * col.float32
      top = parent.top + columnHeights[col]
      width = columnWidth
    
    columnHeights[col] += child.height + spacing

proc card*(widget: Widget) =
  ## Card with shadow and rounded corners
  widget.addConstraints:
    width >= 200
    height >= 100
    padding = parent.spacing.medium
    cornerRadius = 8
    shadow = (
      offset: (x: 0, y: 2),
      blur: 4,
      color: rgba(0, 0, 0, 0.1)
    )

proc modal*(widget: Widget, width: float32 = 400) =
  ## Centered modal dialog
  widget.addConstraints:
    centerInParent()
    width = width.fixed
    maxHeight = parent.height * 0.9
    padding = parent.spacing.large
    cornerRadius = 8
    shadow = (
      offset: (x: 0, y: 4),
      blur: 12,
      color: rgba(0, 0, 0, 0.2)
    )

proc form*(widget: Widget) =
  ## Vertical form layout with proper spacing
  widget.addConstraints:
    direction = dVertical
    spacing = parent.spacing.medium
    align = aStretch
  
  for child in widget.children:
    child.addConstraints:
      width = fill
      if child of Label:
        height = 24
      elif child of Input:
        height = 32
      elif child of Button:
        height = 36

# Usage examples:
let mainWindow = window:
  toolbar(height = 40):
    hstack:
      spacing = 8
      button("New")
      button("Open")
      button("Save")
  
  hsplit:
    sidebar(width = 200):
      vstack:
        treeView()
    
    content:
      vstack:
        card:
          form:
            label("Name")
            textInput()
            label("Email")
            textInput()
            button("Submit")
        
        grid(columns = 3):
          for i in 0..8:
            card:
              label($i)
  
  statusbar()

let dialog = modal(width = 400):
  vstack:
    spacing = 16
    label("Confirm Action")
    text("Are you sure you want to proceed?")
    hstack:
      spacing = 8
      button("Cancel")
      button("OK")