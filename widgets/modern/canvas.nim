## Canvas Widget - RUI2
##
## Custom drawing surface for 2D graphics and visualizations.
## Supports drawing commands, render textures, and interactive drawing.
## Similar to HTML5 Canvas API but for Nim/Raylib.

import ../../core/widget_dsl_v2
import std/[options, sequtils, math]

when defined(useGraphics):
  import raylib

type
  DrawCommandKind* = enum
    dcLine
    dcRect
    dcRectFilled
    dcCircle
    dcCircleFilled
    dcEllipse
    dcTriangle
    dcPolygon
    dcText
    dcImage
    dcClear

  DrawCommand* = object
    case kind*: DrawCommandKind
    of dcLine:
      lineStart*: Vector2
      lineEnd*: Vector2
      lineColor*: Color
      lineThickness*: float

    of dcRect, dcRectFilled:
      rect*: Rectangle
      rectColor*: Color
      rectRounded*: bool
      rectRoundness*: float

    of dcCircle, dcCircleFilled:
      center*: Vector2
      radius*: float
      circleColor*: Color

    of dcEllipse:
      ellipseCenter*: Vector2
      radiusH*, radiusV*: float
      ellipseColor*: Color

    of dcTriangle:
      v1*, v2*, v3*: Vector2
      triangleColor*: Color

    of dcPolygon:
      points*: seq[Vector2]
      polygonColor*: Color
      polygonFilled*: bool

    of dcText:
      textContent*: string
      textPos*: Vector2
      textSize*: int
      textColor*: Color

    of dcImage:
      imagePath*: string
      imageRect*: Rectangle
      imageTint*: Color

    of dcClear:
      clearColor*: Color

  DrawingMode* = enum
    dmNone        # No active drawing
    dmFreehand    # Freehand drawing
    dmLine        # Draw straight lines
    dmRect        # Draw rectangles
    dmCircle      # Draw circles
    dmText        # Place text

defineWidget(Canvas):
  props:
    enableDrawing: bool = true           # Allow user to draw
    drawingMode: DrawingMode = dmNone
    defaultColor: Color = Color(r: 0, g: 0, b: 0, a: 255)
    defaultThickness: float = 2.0
    backgroundColor: Color = Color(r: 255, g: 255, b: 255, a: 255)
    showGrid: bool = false
    gridSize: float = 20.0
    gridColor: Color = Color(r: 240, g: 240, b: 240, a: 255)
    antialiasing: bool = true

  state:
    commands: seq[DrawCommand]           # All draw commands
    isDrawing: bool                      # Currently drawing
    drawStart: Vector2                   # Start point of current draw
    currentPath: seq[Vector2]            # For freehand drawing
    undoStack: seq[seq[DrawCommand]]     # For undo functionality
    renderTexture: int                   # RenderTexture2D ID (simplified)

  actions:
    onDraw(command: DrawCommand)
    onDrawComplete(commands: seq[DrawCommand])
    onClear()
    onUndo()

  layout:
    discard

  render:
    when defined(useGraphics):
      # Draw background
      DrawRectangleRec(widget.bounds, widget.backgroundColor)

      # Draw grid if enabled
      if widget.showGrid:
        let gridSize = widget.gridSize

        # Vertical lines
        var x = widget.bounds.x
        while x <= widget.bounds.x + widget.bounds.width:
          DrawLineEx(
            Vector2(x: x, y: widget.bounds.y),
            Vector2(x: x, y: widget.bounds.y + widget.bounds.height),
            1.0,
            widget.gridColor
          )
          x += gridSize

        # Horizontal lines
        var y = widget.bounds.y
        while y <= widget.bounds.y + widget.bounds.height:
          DrawLineEx(
            Vector2(x: widget.bounds.x, y: y),
            Vector2(x: widget.bounds.x + widget.bounds.width, y: y),
            1.0,
            widget.gridColor
          )
          y += gridSize

      # Begin scissor mode for clipping
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      # Execute all draw commands
      for cmd in widget.commands.get():
        case cmd.kind
        of dcLine:
          DrawLineEx(cmd.lineStart, cmd.lineEnd, cmd.lineThickness, cmd.lineColor)

        of dcRect:
          if cmd.rectRounded:
            DrawRectangleRoundedLines(
              cmd.rect,
              cmd.rectRoundness,
              16,
              2.0,
              cmd.rectColor
            )
          else:
            DrawRectangleLinesEx(cmd.rect, 2.0, cmd.rectColor)

        of dcRectFilled:
          if cmd.rectRounded:
            DrawRectangleRounded(cmd.rect, cmd.rectRoundness, 16, cmd.rectColor)
          else:
            DrawRectangleRec(cmd.rect, cmd.rectColor)

        of dcCircle:
          DrawCircleLines(
            cmd.center.x.cint,
            cmd.center.y.cint,
            cmd.radius,
            cmd.circleColor
          )

        of dcCircleFilled:
          DrawCircleV(cmd.center, cmd.radius, cmd.circleColor)

        of dcEllipse:
          DrawEllipse(
            cmd.ellipseCenter.x.cint,
            cmd.ellipseCenter.y.cint,
            cmd.radiusH,
            cmd.radiusV,
            cmd.ellipseColor
          )

        of dcTriangle:
          DrawTriangle(cmd.v1, cmd.v2, cmd.v3, cmd.triangleColor)

        of dcPolygon:
          if cmd.points.len >= 3:
            if cmd.polygonFilled:
              # Draw filled polygon (triangulate)
              for i in 1..<cmd.points.len-1:
                DrawTriangle(
                  cmd.points[0],
                  cmd.points[i],
                  cmd.points[i+1],
                  cmd.polygonColor
                )
            else:
              # Draw polygon outline
              for i in 0..<cmd.points.len:
                let next = (i + 1) mod cmd.points.len
                DrawLineEx(
                  cmd.points[i],
                  cmd.points[next],
                  2.0,
                  cmd.polygonColor
                )

        of dcText:
          DrawText(
            cmd.textContent.cstring,
            cmd.textPos.x.cint,
            cmd.textPos.y.cint,
            cmd.textSize.cint,
            cmd.textColor
          )

        of dcImage:
          # Would load and draw texture (simplified here)
          DrawRectangleRec(cmd.imageRect, cmd.imageTint)

        of dcClear:
          DrawRectangleRec(widget.bounds, cmd.clearColor)

      # Handle interactive drawing
      if widget.enableDrawing and widget.drawingMode != dmNone:
        let mousePos = GetMousePosition()
        let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)

        if mouseInBounds:
          # Start drawing
          if IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
            widget.isDrawing.set(true)
            widget.drawStart.set(mousePos)

            if widget.drawingMode == dmFreehand:
              widget.currentPath.set(@[mousePos])

          # Continue drawing
          if widget.isDrawing.get() and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
            case widget.drawingMode
            of dmFreehand:
              var path = widget.currentPath.get()
              path.add(mousePos)
              widget.currentPath.set(path)

              # Draw current path
              if path.len >= 2:
                for i in 0..<path.len-1:
                  DrawLineEx(
                    path[i],
                    path[i+1],
                    widget.defaultThickness,
                    widget.defaultColor
                  )

            of dmLine:
              # Draw preview line
              DrawLineEx(
                widget.drawStart.get(),
                mousePos,
                widget.defaultThickness,
                ColorAlpha(widget.defaultColor, 0.5)
              )

            of dmRect:
              # Draw preview rectangle
              let start = widget.drawStart.get()
              let previewRect = Rectangle(
                x: min(start.x, mousePos.x),
                y: min(start.y, mousePos.y),
                width: abs(mousePos.x - start.x),
                height: abs(mousePos.y - start.y)
              )
              DrawRectangleLinesEx(
                previewRect,
                2.0,
                ColorAlpha(widget.defaultColor, 0.5)
              )

            of dmCircle:
              # Draw preview circle
              let start = widget.drawStart.get()
              let radius = sqrt(
                pow(mousePos.x - start.x, 2) +
                pow(mousePos.y - start.y, 2)
              )
              DrawCircleLines(
                start.x.cint,
                start.y.cint,
                radius,
                ColorAlpha(widget.defaultColor, 0.5)
              )

            else:
              discard

          # End drawing
          if IsMouseButtonReleased(MOUSE_LEFT_BUTTON) and widget.isDrawing.get():
            widget.isDrawing.set(false)

            var newCommand: DrawCommand

            case widget.drawingMode
            of dmFreehand:
              let path = widget.currentPath.get()
              if path.len >= 2:
                # Convert path to multiple line commands
                var cmds = widget.commands.get()
                for i in 0..<path.len-1:
                  cmds.add(DrawCommand(
                    kind: dcLine,
                    lineStart: path[i],
                    lineEnd: path[i+1],
                    lineColor: widget.defaultColor,
                    lineThickness: widget.defaultThickness
                  ))
                widget.commands.set(cmds)

                if widget.onDrawComplete.isSome:
                  widget.onDrawComplete.get()(cmds)

              widget.currentPath.set(@[])

            of dmLine:
              newCommand = DrawCommand(
                kind: dcLine,
                lineStart: widget.drawStart.get(),
                lineEnd: mousePos,
                lineColor: widget.defaultColor,
                lineThickness: widget.defaultThickness
              )

              var cmds = widget.commands.get()
              cmds.add(newCommand)
              widget.commands.set(cmds)

              if widget.onDraw.isSome:
                widget.onDraw.get()(newCommand)

            of dmRect:
              let start = widget.drawStart.get()
              newCommand = DrawCommand(
                kind: dcRectFilled,
                rect: Rectangle(
                  x: min(start.x, mousePos.x),
                  y: min(start.y, mousePos.y),
                  width: abs(mousePos.x - start.x),
                  height: abs(mousePos.y - start.y)
                ),
                rectColor: widget.defaultColor,
                rectRounded: false,
                rectRoundness: 0.0
              )

              var cmds = widget.commands.get()
              cmds.add(newCommand)
              widget.commands.set(cmds)

              if widget.onDraw.isSome:
                widget.onDraw.get()(newCommand)

            of dmCircle:
              let start = widget.drawStart.get()
              let radius = sqrt(
                pow(mousePos.x - start.x, 2) +
                pow(mousePos.y - start.y, 2)
              )

              newCommand = DrawCommand(
                kind: dcCircleFilled,
                center: start,
                radius: radius,
                circleColor: widget.defaultColor
              )

              var cmds = widget.commands.get()
              cmds.add(newCommand)
              widget.commands.set(cmds)

              if widget.onDraw.isSome:
                widget.onDraw.get()(newCommand)

            else:
              discard

      EndScissorMode()

      # Draw border
      DrawRectangleLinesEx(
        widget.bounds,
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

    else:
      # Non-graphics mode
      echo "Canvas:"
      echo "  Drawing mode: ", widget.drawingMode
      echo "  Commands: ", widget.commands.get().len
      echo "  Drawing: ", widget.isDrawing.get()
      echo "  Grid: ", widget.showGrid

      if widget.commands.get().len > 0:
        echo "  Recent commands:"
        for i, cmd in widget.commands.get()[max(0, widget.commands.get().len - 5)..^1]:
          echo "    ", i, ": ", cmd.kind
