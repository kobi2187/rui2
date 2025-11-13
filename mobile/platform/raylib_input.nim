## Raylib Touch Input Provider
##
## Bridges raylib's touch input system to RUI's mobile gesture manager.
## Polls raylib touch functions and converts to touch events.

import ../types
import ../../core/types
import std/[tables, options]

when defined(useGraphics):
  import raylib
else:
  # Stubs for when raylib not available
  proc GetTouchPointCount(): int32 = 0
  proc GetTouchPosition(index: int32): Vector2 = Vector2(x: 0, y: 0)
  proc GetTouchPointId(index: int32): int32 = 0
  proc IsMouseButtonPressed(button: int32): bool = false
  proc IsMouseButtonDown(button: int32): bool = false
  proc IsMouseButtonReleased(button: int32): bool = false
  proc GetMousePosition(): Vector2 = Vector2(x: 0, y: 0)
  type Vector2 = object
    x*, y*: float32

# ============================================================================
# Raylib Input Provider
# ============================================================================

type
  RaylibInputProvider* = ref object
    gestureManager*: GestureManager

    # Touch tracking
    activeTouchIds: Table[int, int]  # raylib ID -> our internal ID
    nextInternalId: int

    # Mouse simulation mode (for desktop testing)
    mouseSimulation*: bool
    mousePressed: bool
    mouseId: int

# ============================================================================
# Initialization
# ============================================================================

proc newRaylibInputProvider*(gestureManager: GestureManager,
                             mouseSimulation: bool = true): RaylibInputProvider =
  ## Create a new raylib input provider
  ##
  ## mouseSimulation: If true, use mouse input to simulate touch on desktop
  result = RaylibInputProvider(
    gestureManager: gestureManager,
    activeTouchIds: initTable[int, int](),
    nextInternalId: 0,
    mouseSimulation: mouseSimulation,
    mousePressed: false,
    mouseId: -1
  )

# ============================================================================
# Touch Event Processing
# ============================================================================

proc getOrCreateInternalId(provider: RaylibInputProvider, raylibId: int): int =
  ## Map raylib touch ID to our internal ID
  if raylibId in provider.activeTouchIds:
    return provider.activeTouchIds[raylibId]
  else:
    let internalId = provider.nextInternalId
    provider.activeTouchIds[raylibId] = internalId
    inc provider.nextInternalId
    return internalId

proc removeInternalId(provider: RaylibInputProvider, raylibId: int) =
  ## Remove touch ID mapping
  provider.activeTouchIds.del(raylibId)

proc toPoint(v: Vector2): Point =
  ## Convert raylib Vector2 to our Point
  Point(x: v.x, y: v.y)

# ============================================================================
# Touch Input Polling
# ============================================================================

proc pollTouchInput*(provider: RaylibInputProvider) =
  ## Poll raylib for touch events and feed to gesture manager
  ## Call this every frame in your main loop

  if not provider.gestureManager.enabled:
    return

  when defined(useGraphics):
    let touchCount = GetTouchPointCount()

    # Track which touches are currently active
    var currentTouches: seq[int]

    # Process all active touches
    for i in 0..<touchCount:
      let raylibId = GetTouchPointId(i.int32).int
      let position = GetTouchPosition(i.int32).toPoint()
      let internalId = provider.getOrCreateInternalId(raylibId)

      currentTouches.add(raylibId)

      # Check if this is a new touch or update
      if internalId == provider.nextInternalId - 1:
        # New touch
        provider.gestureManager.addTouch(internalId, position)
      else:
        # Update existing touch
        provider.gestureManager.updateTouch(internalId, position)

    # Find touches that ended (were active last frame but not this frame)
    var endedTouches: seq[int]
    for raylibId in provider.activeTouchIds.keys:
      if raylibId notin currentTouches:
        endedTouches.add(raylibId)

    # Process ended touches
    for raylibId in endedTouches:
      if raylibId in provider.activeTouchIds:
        let internalId = provider.activeTouchIds[raylibId]
        provider.gestureManager.checkEndGestures(internalId)
        provider.gestureManager.removeTouch(internalId)
        provider.removeInternalId(raylibId)

# ============================================================================
# Mouse Simulation (Desktop Testing)
# ============================================================================

proc pollMouseAsTouch*(provider: RaylibInputProvider) =
  ## Use mouse input to simulate touch events (for desktop testing)
  ## Call this every frame when on desktop

  if not provider.mouseSimulation or not provider.gestureManager.enabled:
    return

  when defined(useGraphics):
    const MouseButton_Left = 0  # MOUSE_BUTTON_LEFT

    let mousePos = GetMousePosition().toPoint()
    let mouseDown = IsMouseButtonDown(MouseButton_Left)
    let mousePressed = IsMouseButtonPressed(MouseButton_Left)
    let mouseReleased = IsMouseButtonReleased(MouseButton_Left)

    if mousePressed:
      # Mouse button just pressed - start touch
      if provider.mouseId < 0:
        provider.mouseId = provider.nextInternalId
        inc provider.nextInternalId
      provider.gestureManager.addTouch(provider.mouseId, mousePos)
      provider.mousePressed = true

    elif mouseDown and provider.mousePressed:
      # Mouse button held - update touch
      provider.gestureManager.updateTouch(provider.mouseId, mousePos)

    elif mouseReleased and provider.mousePressed:
      # Mouse button released - end touch
      provider.gestureManager.checkEndGestures(provider.mouseId)
      provider.gestureManager.removeTouch(provider.mouseId)
      provider.mousePressed = false

# ============================================================================
# Combined Update
# ============================================================================

proc update*(provider: RaylibInputProvider) =
  ## Update input - call this every frame
  ## Automatically chooses between touch and mouse input

  when defined(useGraphics):
    let touchCount = GetTouchPointCount()

    if touchCount > 0:
      # Real touch input available - use it
      provider.pollTouchInput()
    elif provider.mouseSimulation:
      # No touch - use mouse simulation for desktop testing
      provider.pollMouseAsTouch()
  else:
    # No graphics - do nothing
    discard

  # Update gesture recognition
  provider.gestureManager.recognizeGestures()

# ============================================================================
# Utility Functions
# ============================================================================

proc reset*(provider: RaylibInputProvider) =
  ## Reset provider state
  provider.activeTouchIds.clear()
  provider.nextInternalId = 0
  provider.mousePressed = false
  provider.mouseId = -1
  provider.gestureManager.clear()

proc setMouseSimulation*(provider: RaylibInputProvider, enabled: bool) =
  ## Enable/disable mouse simulation
  provider.mouseSimulation = enabled
  if not enabled and provider.mousePressed:
    # Clean up mouse touch if disabling
    if provider.mouseId >= 0:
      provider.gestureManager.checkEndGestures(provider.mouseId)
      provider.gestureManager.removeTouch(provider.mouseId)
    provider.mousePressed = false

# ============================================================================
# Debug/Info Functions
# ============================================================================

proc getActiveTouchCount*(provider: RaylibInputProvider): int =
  ## Get number of active touches
  provider.activeTouchIds.len

proc isUsingMouseSimulation*(provider: RaylibInputProvider): bool =
  ## Check if currently using mouse simulation
  provider.mouseSimulation and provider.mousePressed
