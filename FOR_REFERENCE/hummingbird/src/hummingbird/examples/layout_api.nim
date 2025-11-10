# All available layout features
layout:
  panel:
    # Size constraints
    width = 800
    height = 600
    minWidth = 400
    maxWidth = 1200
    minHeight = 300
    maxHeight = 900

    # Position constraints
    left = parent.left + 10
    right = parent.right - 10
    top = parent.top + 10
    bottom = parent.bottom - 10
    
    # Center alignment
    centerX = parent.centerX
    centerY = parent.centerY
    center in parent  # Both X and Y

    # Margins & padding
    margin = EdgeInsets(all: 16)
    padding = EdgeInsets(
      horizontal: 16,
      vertical: 8
    )

    # Relative sizing
    width = parent.width * 0.8  # 80%
    height = fill              # Fill available space
    
    # Aspect ratio
    height = width * 0.5  # 2:1 ratio

    # Grid layout
    grid:
      columns = 3
      spacing = 16
      
      for i in 0..8:
        panel:
          width = fill
          height = width  # Square cells

    # Flex layout
    hstack:  # or vstack
      spacing = 8
      wrap = true
      justifyContent = SpaceBetween
      alignItems = Center
      
      # Flex items
      panel:
        width = 100
        grow = 1    # Take available space
        shrink = 1  # Allow shrinking
        basis = 0   # Base size
      
      panel:
        width = 200
        grow = 2    # Take twice as much space

    # Stack layout
    vstack:
      spacing = 16
      alignment = Leading
      
      text("Header")
      
      hstack:
        spacing = 8
        
        button("Save")
        button("Cancel")

# Common layout patterns
proc centerInParent*(widget: Widget) =
  widget.addConstraints:
    centerX = parent.centerX
    centerY = parent.centerY

proc fillParent*(widget: Widget, margin: float32 = 0) =
  widget.addConstraints:
    left = parent.left + margin
    right = parent.right - margin
    top = parent.top + margin
    bottom = parent.bottom - margin

# Animation support
proc animateLayout*(widget: Widget, duration: float32) =
  animate:
    widget.left:
      to = 100
      duration = duration
    widget.width:
      to = 200
      duration = duration

# Layout debugging
when defined(debug):
  proc debugLayout*(widget: Widget) =
    echo "Widget: ", widget.id
    echo "Position: ", widget.rect
    echo "Constraints:"
    for c in widget.constraints:
      echo "  ", c

# Complex example combining features
defineWidget Dashboard:
  render:
    grid:
      columns = 2
      spacing = 16
      padding = 16
      
      # Stats panel
      panel:
        width = fill
        height = 200
        
        hstack:
          spacing = 24
          padding = 16
          
          for stat in stats:
            panel:
              width = fill
              height = fill
              padding = 12
              
              vstack:
                spacing = 8
                text(stat.label)
                text(stat.value,
                  style = theme.headline4)

      # Chart panel
      panel:
        width = fill
        height = 400
        columnSpan = 2
        
        vstack:
          spacing = 16
          padding = 16
          
          text("Chart Title")
          chart:
            width = fill
            height = fill

      # Table panel
      panel:
        width = fill
        height = fill
        columnSpan = 2
        
        table:
          width = fill
          height = fill
          columns = @[
            Column(width = 200),
            Column(width = fill),
            Column(width = 100)
          ]