layout:
  # Main window layout
  panel:
    # Basic size constraints
    width = 800
    height = 600
    minWidth = 400
    maxWidth = 1200
    minHeight = 300

    # Relative to parent
    left = parent.left + 16
    right = parent.right - 16
    top = parent.top + 16
    bottom = parent.bottom - 16

    # Percentage based
    width = 80%      # Of parent
    height = 90%

    # Fill available space
    width = fill
    height = fill

    # Center in parent
    center in parent  # Both X and Y
    centerX = parent.centerX  # Just X
    centerY = parent.centerY  # Just Y

    # Aspect ratio
    height = width * 0.5  # 2:1 ratio

    # Stack layouts
    vstack:
      spacing = 16
      alignment = Leading  # Start, Center, End

      # Header
      panel:
        height = 60
        width = fill

      # Content with horizontal split
      hstack:
        spacing = 16
        height = fill

        # Sidebar
        panel:
          width = 200
          height = fill

        # Main content with grid
        grid:
          columns = 3
          spacing = 16
          width = fill
          height = fill

          # Grid items automatically flow
          for i in 0..8:
            panel:
              width = fill
              height = 100
              padding = EdgeInsets(all: 8)

    # Flex layout example
    hstack:
      spacing = 8
      alignItems = Center  # Cross-axis alignment
      justifyContent = SpaceBetween  # Main-axis alignment

      # Flex children
      panel:
        width = 100
        flexGrow = 1    # Take extra space
        flexShrink = 1  # Allow shrinking
        flexBasis = 0   # Base size

      panel:
        width = 200
        flexGrow = 2    # Take twice as much extra space

    # Absolute positioning
    panel:
      position = Absolute
      left = 16
      top = 16
      width = 32
      height = 32

    # Using EdgeInsets for margins/padding
    panel:
      margin = EdgeInsets(
        left: 16,
        right: 16,
        top: 8,
        bottom: 8
      )
      padding = EdgeInsets(
        horizontal: 16,
        vertical: 8
      )

    # Relative to other widgets
    button1:
      width = 100
      height = 40
      left = parent.left + 16
      top = parent.top + 16

    button2:
      width = 100
      height = 40
      left = button1.right + 8  # 8px gap
      top = button1.top        # Align tops

    # Constraint priorities
    panel:
      # Strong constraints (rarely broken)
      width >= 100 @csStrong
      height >= 100 @csStrong

      # Medium constraints (balance)
      width = 200 @csMedium

      # Weak constraints (preferences)
      centerX = parent.centerX @csWeak

    # Responsive breakpoints
    responsive:
      phone:
        width = fill
        padding = 16
      
      tablet:
        width = 80%
        center in parent
      
      desktop:
        width = 960
        center in parent
