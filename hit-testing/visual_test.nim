## Visual Interactive Hit-Testing Demo
##
## Click to create widgets
## Move mouse to see hit-testing in action
## Press 'C' to clear all widgets
## Press 'R' to create random widgets
## Press 'S' to show stats

import hittest_system
import raylib
import std/[random, strformat, strutils]

const
  SCREEN_WIDTH = 1200
  SCREEN_HEIGHT = 800
  MAX_WIDGETS = 100

type
  DemoWidget = object
    widget: Widget
    color: Color

var
  system = newHitTestSystem()
  widgets: seq[DemoWidget]
  nextId = 1
  showStats = false

proc randomColor(): Color =
  Color(
    r: uint8(rand(150) + 50),
    g: uint8(rand(150) + 50),
    b: uint8(rand(150) + 50),
    a: 200
  )

proc addRandomWidget() =
  if widgets.len >= MAX_WIDGETS:
    return

  let x = float32(rand(SCREEN_WIDTH - 100))
  let y = float32(rand(SCREEN_HEIGHT - 100))
  let w = float32(rand(80) + 20)
  let h = float32(rand(80) + 20)
  let z = rand(10)

  let widget = Widget(
    id: WidgetId(nextId),
    bounds: newRect(x, y, w, h),
    zIndex: z
  )

  system.insertWidget(widget)
  widgets.add(DemoWidget(widget: widget, color: randomColor()))
  inc nextId

proc addWidgetAt(x, y: float32) =
  if widgets.len >= MAX_WIDGETS:
    return

  let w = float32(rand(60) + 40)
  let h = float32(rand(60) + 40)
  let z = rand(10)

  let widget = Widget(
    id: WidgetId(nextId),
    bounds: newRect(x - w/2, y - h/2, w, h),
    zIndex: z
  )

  system.insertWidget(widget)
  widgets.add(DemoWidget(widget: widget, color: randomColor()))
  inc nextId

proc clearAll() =
  system.clear()
  widgets.setLen(0)
  nextId = 1

proc main() =
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hit-Testing System - Visual Demo")
  setTargetFPS(60)
  randomize()

  # Add some initial widgets
  for i in 0..<10:
    addRandomWidget()

  var mousePos = Vector2(x: 0, y: 0)
  var hitWidgets: seq[Widget] = @[]

  while not windowShouldClose():
    # Update
    mousePos = getMousePosition()

    # Input handling
    if isKeyPressed(KeyboardKey.C):
      clearAll()

    if isKeyPressed(KeyboardKey.R):
      for i in 0..<5:
        addRandomWidget()

    if isKeyPressed(KeyboardKey.S):
      showStats = not showStats

    if isMouseButtonPressed(MouseButton.Left):
      addWidgetAt(mousePos.x, mousePos.y)

    # Query hit-testing system
    hitWidgets = system.findWidgetsAt(mousePos.x, mousePos.y)

    # Drawing
    beginDrawing()
    clearBackground(Color(r: 30, g: 30, b: 35, a: 255))

    # Draw all widgets
    for dw in widgets:
      let bounds = dw.widget.bounds

      # Check if this widget is under mouse
      var isHit = false
      for hw in hitWidgets:
        if hw.id == dw.widget.id:
          isHit = true
          break

      # Draw widget with highlight if under mouse
      if isHit:
        # Draw highlight border
        drawRectangle(
          int32(bounds.x - 2),
          int32(bounds.y - 2),
          int32(bounds.width + 4),
          int32(bounds.height + 4),
          YELLOW
        )
        drawRectangle(
          int32(bounds.x),
          int32(bounds.y),
          int32(bounds.width),
          int32(bounds.height),
          dw.color
        )
      else:
        drawRectangle(
          int32(bounds.x),
          int32(bounds.y),
          int32(bounds.width),
          int32(bounds.height),
          dw.color
        )

      # Draw z-index
      let zText = $dw.widget.zIndex
      let textWidth = measureText(zText, 16'i32)
      drawText(
        zText,
        int32(bounds.x + bounds.width/2 - float32(textWidth)/2),
        int32(bounds.y + bounds.height/2 - 8),
        16'i32,
        WHITE
      )

    # Draw crosshair at mouse
    drawLine(
      int32(mousePos.x) - 10,
      int32(mousePos.y),
      int32(mousePos.x) + 10,
      int32(mousePos.y),
      WHITE
    )
    drawLine(
      int32(mousePos.x),
      int32(mousePos.y) - 10,
      int32(mousePos.x),
      int32(mousePos.y) + 10,
      WHITE
    )

    # Draw info panel
    let panelX = 10'i32
    var panelY = 10'i32
    let lineHeight = 22'i32

    drawRectangle(panelX - 5, panelY - 5, 300, 180, Color(r: 0, g: 0, b: 0, a: 150))

    drawText("Hit-Testing Demo", panelX, panelY, 20'i32, LIME)
    panelY += lineHeight + 5

    drawText(&"Total widgets: {widgets.len}", panelX, panelY, 18'i32, WHITE)
    panelY += lineHeight

    drawText(&"Widgets at cursor: {hitWidgets.len}", panelX, panelY, 18'i32, WHITE)
    panelY += lineHeight

    if hitWidgets.len > 0:
      let topWidget = hitWidgets[0]
      drawText(&"Top widget: ID={topWidget.id.int} Z={topWidget.zIndex}", panelX, panelY, 18'i32, YELLOW)
      panelY += lineHeight

    drawText("", panelX, panelY, 18'i32, GRAY)
    panelY += lineHeight

    drawText("[LMB] Create widget", panelX, panelY, 16'i32, GRAY)
    panelY += lineHeight - 2

    drawText("[C] Clear all", panelX, panelY, 16'i32, GRAY)
    panelY += lineHeight - 2

    drawText("[R] Add 5 random", panelX, panelY, 16'i32, GRAY)
    panelY += lineHeight - 2

    drawText("[S] Toggle stats", panelX, panelY, 16'i32, GRAY)

    # Draw stats if enabled
    if showStats:
      let statsText = system.getStats()
      let statsX = SCREEN_WIDTH - 350
      let statsY = 10
      drawRectangle(int32(statsX - 5), int32(statsY - 5), 340'i32, 140'i32, Color(r: 0, g: 0, b: 0, a: 150))

      var yPos = statsY
      for line in statsText.splitLines():
        drawText(line, int32(statsX), int32(yPos), 16'i32, WHITE)
        yPos += 20

    # Draw FPS
    drawFPS(SCREEN_WIDTH - 100, SCREEN_HEIGHT - 30)

    endDrawing()

  closeWindow()

when isMainModule:
  main()
