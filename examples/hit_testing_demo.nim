## Hit-Testing Visual Demo with Widget Tree
##
## Shows real widgets being hit-tested with proper rendering
## Uses drawing_primitives for actual widget appearance
##
## Controls:
## - Mouse to hover/click widgets
## - Number keys 1-4 to switch between example UIs
## - H to toggle hit info display
## - ESC to quit

import raylib
import ../core/[types, widget_builder]
import ../drawing_primitives/drawing_primitives
import ui_examples
import std/[strformat, options]

# Import hit-testing
import "../hit-testing/hittest_system"

const
  SCREEN_WIDTH = 1200
  SCREEN_HEIGHT = 800

type
  AppState = object
    currentExample: int
    tree: WidgetTree
    hitTestSystem: HitTestSystem
    showHitInfo: bool

var state: AppState

# ============================================================================
# Widget Rendering
# ============================================================================

proc renderWidget(widget: Widget) =
  ## Render a widget using drawing primitives
  if not widget.visible:
    return

  let bounds = widget.bounds

  case widget.kind:
  of wkPanel, wkContainer:
    # Draw panel background
    let bgColor = if widget.backgroundColor.isSome:
      widget.backgroundColor.get()
    else:
      Color(r: 50, g: 50, b: 50, a: 200)
    drawRect(bounds, bgColor, filled = true)

    # Draw border if hovered
    if widget.hovered:
      drawRect(bounds, YELLOW, filled = false)

  of wkButton:
    # Button background
    var bgColor = if widget.backgroundColor.isSome:
      widget.backgroundColor.get()
    else:
      Color(r: 70, g: 70, b: 70, a: 255)

    # Adjust for state
    if widget.pressed:
      bgColor.r = uint8(int(bgColor.r) * 80 div 100)
      bgColor.g = uint8(int(bgColor.g) * 80 div 100)
      bgColor.b = uint8(int(bgColor.b) * 80 div 100)
    elif widget.hovered:
      bgColor.r = uint8(min(255, int(bgColor.r) * 120 div 100))
      bgColor.g = uint8(min(255, int(bgColor.g) * 120 div 100))
      bgColor.b = uint8(min(255, int(bgColor.b) * 120 div 100))

    if not widget.enabled:
      bgColor.a = 128

    drawRoundedRect(bounds, 4.0, bgColor, filled = true)

    # Button text
    if widget.text.len > 0:
      let textColor = if widget.textColor.isSome:
        widget.textColor.get()
      elif not widget.enabled:
        GRAY
      else:
        WHITE

      let textWidth = measureText(widget.text, 18'i32)
      let textX = bounds.x + (bounds.width - float32(textWidth)) / 2
      let textY = bounds.y + (bounds.height - 18) / 2
      drawText(widget.text, int32(textX), int32(textY), 18'i32, textColor)

  of wkLabel:
    # Label text
    if widget.text.len > 0:
      let textColor = if widget.textColor.isSome:
        widget.textColor.get()
      else:
        BLACK

      drawText(widget.text, int32(bounds.x), int32(bounds.y + 2), 18'i32, textColor)

  of wkTextInput:
    # Input background
    var bgColor = if widget.backgroundColor.isSome:
      widget.backgroundColor.get()
    else:
      WHITE

    drawRoundedRect(bounds, 3.0, bgColor, filled = true)

    # Border
    let borderColor = if widget.focused:
      Color(r: 52, g: 152, b: 219, a: 255)
    elif widget.hovered:
      Color(r: 189, g: 195, b: 199, a: 255)
    else:
      Color(r: 220, g: 220, b: 220, a: 255)

    drawRoundedRect(bounds, 3.0, borderColor, filled = false)

    # Placeholder/text
    if widget.text.len > 0:
      let textColor = Color(r: 150, g: 150, b: 150, a: 255)
      drawText(widget.text, int32(bounds.x + 8), int32(bounds.y + 8), 16'i32, textColor)

  of wkCheckbox:
    # Checkbox box
    let boxSize = 20.0'f32
    let boxRect = Rect(x: bounds.x, y: bounds.y, width: boxSize, height: boxSize)

    drawRect(boxRect, WHITE, filled = true)
    drawRect(boxRect, if widget.hovered: Color(r: 52, g: 152, b: 219, a: 255) else: GRAY, filled = false)

    # Label text
    if widget.text.len > 0:
      drawText(widget.text, int32(bounds.x + boxSize + 8), int32(bounds.y + 2), 16'i32, BLACK)

  else:
    # Generic rendering
    drawRect(bounds, GRAY, filled = true)

  # Render children
  for child in widget.children:
    renderWidget(child)

# ============================================================================
# Hit-Testing Integration
# ============================================================================

proc updateHitTesting() =
  ## Update hit-testing system from widget tree
  state.hitTestSystem.rebuildFromWidgets(state.tree.getAllWidgets())

proc updateHoverStates(mouseX, mouseY: float32) =
  ## Update hover states based on hit-testing
  # Clear all hover states first
  for widget in state.tree.walkTree():
    widget.hovered = false

  # Set hover for widgets under mouse
  let hitWidgets = state.hitTestSystem.findWidgetsAt(mouseX, mouseY)
  for widget in hitWidgets:
    widget.hovered = true

proc handleMouseClick(mouseX, mouseY: float32) =
  ## Handle mouse click on widgets
  let topWidget = state.hitTestSystem.findTopWidgetAt(mouseX, mouseY)

  if topWidget != nil and topWidget.enabled:
    echo &"Clicked: {topWidget.stringId} (kind={topWidget.kind})"

    # Set pressed state
    topWidget.pressed = true

    # Call onClick handler if present
    if topWidget.onClick != nil:
      topWidget.onClick()

proc handleMouseRelease() =
  ## Clear pressed states
  for widget in state.tree.walkTree():
    widget.pressed = false

# ============================================================================
# Example UI Switching
# ============================================================================

proc loadExample(exampleNum: int) =
  state.currentExample = exampleNum

  case exampleNum:
  of 1:
    echo "Loading: Simple Button Panel"
    state.tree = createSimpleButtonPanel()
  of 2:
    echo "Loading: Login Form"
    state.tree = createLoginForm()
  of 3:
    echo "Loading: Dashboard"
    state.tree = createDashboard()
  of 4:
    echo "Loading: Overlapping Test (Z-Index)"
    state.tree = createOverlappingTest()
  else:
    return

  # Setup click handlers
  for widget in state.tree.walkTree():
    if widget.kind == wkButton:
      let widgetId = widget.stringId  # Capture for closure
      widget.onClick = proc() =
        echo &"Button clicked: {widgetId}"

  updateHitTesting()

# ============================================================================
# UI Overlay
# ============================================================================

proc drawOverlay(mouseX, mouseY: float32) =
  # Draw crosshair
  drawLine(mouseX - 10, mouseY, mouseX + 10, mouseY, WHITE, 1.0)
  drawLine(mouseX, mouseY - 10, mouseX, mouseY + 10, WHITE, 1.0)

  # Info panel
  let panelX = 10'i32
  var panelY = 10'i32
  let lineHeight = 22'i32

  drawRectangle(panelX - 5, panelY - 5, 350, 180, Color(r: 0, g: 0, b: 0, a: 150))

  drawText("Hit-Testing Demo", panelX, panelY, 20'i32, LIME)
  panelY += lineHeight + 5

  let exampleName = case state.currentExample:
    of 1: "Button Panel"
    of 2: "Login Form"
    of 3: "Dashboard"
    of 4: "Overlapping (Z-Index)"
    else: "None"

  drawText(&"Example: {exampleName}", panelX, panelY, 16'i32, WHITE)
  panelY += lineHeight

  let widgetCount = state.tree.getAllWidgets().len
  drawText(&"Widgets: {widgetCount}", panelX, panelY, 16'i32, WHITE)
  panelY += lineHeight

  # Hit info
  if state.showHitInfo:
    let hitWidgets = state.hitTestSystem.findWidgetsAt(mouseX, mouseY)
    drawText(&"Widgets at cursor: {hitWidgets.len}", panelX, panelY, 16'i32, YELLOW)
    panelY += lineHeight

    if hitWidgets.len > 0:
      let top = hitWidgets[0]
      drawText(&"Top: {top.stringId} (Z={top.zIndex})", panelX, panelY, 14'i32, YELLOW)
      panelY += lineHeight - 4

      for i, widget in hitWidgets:
        if i > 0:  # Skip first (already shown)
          drawText(&"  [{i}] {widget.stringId} (Z={widget.zIndex})", panelX, panelY, 12'i32, GRAY)
          panelY += lineHeight - 6

  drawText("", panelX, panelY, 16'i32, GRAY)
  panelY += 8

  drawText("[1-4] Switch examples", panelX, panelY, 14'i32, GRAY)
  panelY += lineHeight - 4

  drawText("[H] Toggle hit info", panelX, panelY, 14'i32, GRAY)
  panelY += lineHeight - 4

  drawText("[ESC] Quit", panelX, panelY, 14'i32, GRAY)

  # FPS
  drawFPS(SCREEN_WIDTH - 100, SCREEN_HEIGHT - 30)

# ============================================================================
# Main Loop
# ============================================================================

proc main() =
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "RUI Hit-Testing Demo with Widget Tree")
  setTargetFPS(60)

  # Initialize
  state = AppState(
    currentExample: 1,
    hitTestSystem: newHitTestSystem(),
    showHitInfo: true
  )

  loadExample(1)

  echo ""
  echo "Controls:"
  echo "  1-4: Switch between example UIs"
  echo "  H: Toggle hit info display"
  echo "  Mouse: Hover and click widgets"
  echo ""

  while not windowShouldClose():
    let mousePos = getMousePosition()

    # Input handling
    if isKeyPressed(KeyboardKey.Num1) or isKeyPressed(KeyboardKey.Kp1):
      loadExample(1)

    if isKeyPressed(KeyboardKey.Num2) or isKeyPressed(KeyboardKey.Kp2):
      loadExample(2)

    if isKeyPressed(KeyboardKey.Num3) or isKeyPressed(KeyboardKey.Kp3):
      loadExample(3)

    if isKeyPressed(KeyboardKey.Num4) or isKeyPressed(KeyboardKey.Kp4):
      loadExample(4)

    if isKeyPressed(KeyboardKey.H):
      state.showHitInfo = not state.showHitInfo

    # Update hover states
    updateHoverStates(mousePos.x, mousePos.y)

    # Mouse clicks
    if isMouseButtonPressed(MouseButton.Left):
      handleMouseClick(mousePos.x, mousePos.y)

    if isMouseButtonReleased(MouseButton.Left):
      handleMouseRelease()

    # Rendering
    beginDrawing()
    clearBackground(Color(r: 245, g: 245, b: 245, a: 255))

    # Render widget tree
    if state.tree != nil and state.tree.root != nil:
      renderWidget(state.tree.root)

    # Render overlay
    drawOverlay(mousePos.x, mousePos.y)

    endDrawing()

  closeWindow()

when isMainModule:
  main()
