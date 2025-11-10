## DragDropArea Widget - RUI2
##
## Modern drag-and-drop area for file uploads and drag interactions.
## Provides visual feedback during drag-over and handles file drops.
## Also supports click-to-browse as fallback.

import ../../core/widget_dsl_v2
import std/[options, sets, os, strutils]

when defined(useGraphics):
  import raylib

type
  DropMode* = enum
    dmFiles          # Accept file drops
    dmDirectories    # Accept directory drops
    dmBoth          # Accept both files and directories

  DroppedItem* = object
    path*: string
    isDirectory*: bool
    size*: int64

defineWidget(DragDropArea):
  props:
    mode: DropMode = dmFiles
    acceptedExtensions: seq[string] = @[]  # e.g., @[".txt", ".nim", ".png"]
    maxFileSize: int64 = 100_000_000       # 100MB default
    multiple: bool = true                   # Allow multiple files
    promptText: string = "Drag & drop files here\nor click to browse"
    hoverText: string = "Drop files here"
    backgroundColor: Color = Color(r: 250, g: 250, b: 250, a: 255)
    hoverColor: Color = Color(r: 230, g: 240, b: 255, a: 255)
    borderColor: Color = Color(r: 200, g: 200, b: 200, a: 255)
    borderColorHover: Color = Color(r: 100, g: 150, b: 255, a: 255)
    textColor: Color = Color(r: 100, g: 100, b: 100, a: 255)
    iconColor: Color = Color(r: 150, g: 150, b: 150, a: 255)
    borderWidth: float = 2.0
    borderDashed: bool = true
    cornerRadius: float = 8.0

  state:
    isDragOver: bool
    isHovered: bool
    lastDroppedFiles: seq[DroppedItem]
    errorMessage: string

  actions:
    onFilesDropped(files: seq[DroppedItem])
    onFilesRejected(files: seq[string], reason: string)
    onClick()
    onDragEnter()
    onDragLeave()

  layout:
    # No children to layout
    discard

  render:
    when defined(useGraphics):
      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)

      # Update hover state
      if mouseInBounds != widget.isHovered.get():
        widget.isHovered.set(mouseInBounds)

      # Check for file drops (simplified - raylib provides IsFileDropped)
      if IsFileDropped():
        var droppedFiles = GetDroppedFiles()
        var validFiles: seq[DroppedItem] = @[]
        var rejectedFiles: seq[string] = @[]
        var rejectionReason = ""

        for i in 0..<droppedFiles.count:
          let filePath = $droppedFiles.paths[i]
          let isDir = directoryExists(filePath)

          # Check mode compatibility
          if widget.mode == dmFiles and isDir:
            rejectedFiles.add(filePath)
            rejectionReason = "Directories not accepted"
            continue
          elif widget.mode == dmDirectories and not isDir:
            rejectedFiles.add(filePath)
            rejectionReason = "Only directories accepted"
            continue

          # Check extension if specified
          if widget.acceptedExtensions.len > 0 and not isDir:
            let ext = splitFile(filePath).ext
            if ext notin widget.acceptedExtensions:
              rejectedFiles.add(filePath)
              rejectionReason = "File type not accepted: " & ext
              continue

          # Check file size
          if not isDir:
            try:
              let fileSize = getFileSize(filePath)
              if fileSize > widget.maxFileSize:
                rejectedFiles.add(filePath)
                rejectionReason = "File too large: " & $(fileSize div 1_000_000) & "MB"
                continue

              validFiles.add(DroppedItem(
                path: filePath,
                isDirectory: false,
                size: fileSize
              ))
            except:
              rejectedFiles.add(filePath)
              rejectionReason = "Could not read file"
          else:
            validFiles.add(DroppedItem(
              path: filePath,
              isDirectory: true,
              size: 0
            ))

        ClearDroppedFiles()

        # Handle results
        if validFiles.len > 0:
          if not widget.multiple and validFiles.len > 1:
            validFiles = @[validFiles[0]]

          widget.lastDroppedFiles.set(validFiles)
          widget.errorMessage.set("")

          if widget.onFilesDropped.isSome:
            widget.onFilesDropped.get()(validFiles)

        if rejectedFiles.len > 0 and widget.onFilesRejected.isSome:
          widget.onFilesRejected.get()(rejectedFiles, rejectionReason)
          widget.errorMessage.set(rejectionReason)

        widget.isDragOver.set(false)

      # Determine colors based on state
      let isDragOver = widget.isDragOver.get()
      let isHovered = widget.isHovered.get()

      let bgColor = if isDragOver: widget.hoverColor else: widget.backgroundColor
      let borderCol = if isDragOver: widget.borderColorHover else: widget.borderColor

      # Draw background with rounded corners
      DrawRectangleRounded(
        widget.bounds,
        widget.cornerRadius / widget.bounds.height,
        16,
        bgColor
      )

      # Draw border (dashed if specified)
      if widget.borderDashed:
        # Draw dashed border manually
        let dashLength = 10.0
        let gapLength = 8.0
        let rect = widget.bounds

        # Top edge
        var x = rect.x
        while x < rect.x + rect.width:
          let endX = min(x + dashLength, rect.x + rect.width)
          DrawLineEx(
            Vector2(x: x, y: rect.y),
            Vector2(x: endX, y: rect.y),
            widget.borderWidth,
            borderCol
          )
          x += dashLength + gapLength

        # Right edge
        var y = rect.y
        while y < rect.y + rect.height:
          let endY = min(y + dashLength, rect.y + rect.height)
          DrawLineEx(
            Vector2(x: rect.x + rect.width, y: y),
            Vector2(x: rect.x + rect.width, y: endY),
            widget.borderWidth,
            borderCol
          )
          y += dashLength + gapLength

        # Bottom edge
        x = rect.x + rect.width
        while x > rect.x:
          let endX = max(x - dashLength, rect.x)
          DrawLineEx(
            Vector2(x: endX, y: rect.y + rect.height),
            Vector2(x: x, y: rect.y + rect.height),
            widget.borderWidth,
            borderCol
          )
          x -= dashLength + gapLength

        # Left edge
        y = rect.y + rect.height
        while y > rect.y:
          let endY = max(y - dashLength, rect.y)
          DrawLineEx(
            Vector2(x: rect.x, y: endY),
            Vector2(x: rect.x, y: y),
            widget.borderWidth,
            borderCol
          )
          y -= dashLength + gapLength
      else:
        # Solid border
        DrawRectangleRoundedLines(
          widget.bounds,
          widget.cornerRadius / widget.bounds.height,
          16,
          widget.borderWidth,
          borderCol
        )

      # Draw upload icon (simplified cloud/arrow icon)
      let centerX = widget.bounds.x + widget.bounds.width / 2.0
      let centerY = widget.bounds.y + widget.bounds.height / 2.0 - 20.0

      # Draw cloud icon using circles and rectangles
      let cloudY = centerY
      DrawCircle((centerX - 15.0).cint, cloudY.cint, 12.0, widget.iconColor)
      DrawCircle((centerX + 15.0).cint, cloudY.cint, 12.0, widget.iconColor)
      DrawCircle(centerX.cint, (cloudY - 8.0).cint, 15.0, widget.iconColor)
      DrawRectangle(
        (centerX - 15.0).cint,
        cloudY.cint,
        30.0.cint,
        12.0.cint,
        widget.iconColor
      )

      # Draw arrow pointing up (upload)
      let arrowY = centerY + 15.0
      DrawLineEx(
        Vector2(x: centerX, y: arrowY),
        Vector2(x: centerX, y: arrowY - 20.0),
        3.0,
        widget.iconColor
      )
      # Arrow head
      DrawLineEx(
        Vector2(x: centerX, y: arrowY - 20.0),
        Vector2(x: centerX - 8.0, y: arrowY - 12.0),
        3.0,
        widget.iconColor
      )
      DrawLineEx(
        Vector2(x: centerX, y: arrowY - 20.0),
        Vector2(x: centerX + 8.0, y: arrowY - 12.0),
        3.0,
        widget.iconColor
      )

      # Draw text
      let displayText = if isDragOver: widget.hoverText else: widget.promptText
      let textLines = displayText.split('\n')
      var textY = centerY + 35.0

      for line in textLines:
        let textWidth = MeasureText(line.cstring, 14)
        DrawText(
          line.cstring,
          (centerX - textWidth.float / 2.0).cint,
          textY.cint,
          14,
          widget.textColor
        )
        textY += 20.0

      # Draw error message if present
      let errorMsg = widget.errorMessage.get()
      if errorMsg.len > 0:
        let errorTextWidth = MeasureText(errorMsg.cstring, 12)
        DrawText(
          errorMsg.cstring,
          (centerX - errorTextWidth.float / 2.0).cint,
          (widget.bounds.y + widget.bounds.height - 20.0).cint,
          12,
          Color(r: 200, g: 50, b: 50, a: 255)
        )

      # Show last dropped files count
      let lastFiles = widget.lastDroppedFiles.get()
      if lastFiles.len > 0:
        let countText = $lastFiles.len & " file(s) uploaded"
        let countWidth = MeasureText(countText.cstring, 11)
        DrawText(
          countText.cstring,
          (centerX - countWidth.float / 2.0).cint,
          (widget.bounds.y + widget.bounds.height - 35.0).cint,
          11,
          Color(r: 50, g: 150, b: 50, a: 255)
        )

      # Handle click (to trigger file dialog)
      if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
        if widget.onClick.isSome:
          widget.onClick.get()()

      # Simulated drag detection (in real impl, need OS integration)
      # For now, use hover as proxy for drag-over
      if mouseInBounds and not widget.isDragOver.get():
        # Could trigger onDragEnter
        if widget.onDragEnter.isSome:
          widget.onDragEnter.get()()
        widget.isDragOver.set(true)
      elif not mouseInBounds and widget.isDragOver.get():
        if widget.onDragLeave.isSome:
          widget.onDragLeave.get()()
        widget.isDragOver.set(false)

    else:
      # Non-graphics mode
      echo "DragDropArea:"
      echo "  Mode: ", widget.mode
      echo "  Multiple: ", widget.multiple
      echo "  Accepted extensions: ", widget.acceptedExtensions
      echo "  Max file size: ", widget.maxFileSize div 1_000_000, "MB"
      echo "  Drag over: ", widget.isDragOver.get()

      let lastFiles = widget.lastDroppedFiles.get()
      if lastFiles.len > 0:
        echo "  Last dropped files:"
        for file in lastFiles:
          let typeStr = if file.isDirectory: "[DIR]" else: "[FILE]"
          echo "    ", typeStr, " ", file.path, " (", file.size, " bytes)"

      let errorMsg = widget.errorMessage.get()
      if errorMsg.len > 0:
        echo "  Error: ", errorMsg
