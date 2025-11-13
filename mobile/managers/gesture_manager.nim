## Gesture Recognition Manager
##
## Recognizes high-level gestures from raw touch events.
## Handles gesture state machines, conflict resolution, and configuration.

import ../types
import ../../core/types
import std/[tables, monotimes, times, math, options]

# ============================================================================
# Gesture Recognition State
# ============================================================================

type
  RecognizerState = enum
    rsIdle           # No gesture in progress
    rsPossible       # Gesture might be starting
    rsRecognized     # Gesture recognized
    rsFailed         # Gesture failed to recognize

  GestureRecognizer = ref object
    kind: GestureKind
    state: RecognizerState
    startTime: MonoTime
    touchPoints: seq[TouchPoint]
    initialDistance: float32  # For pinch
    initialAngle: float32     # For rotation
    accumulated: Point        # Accumulated movement

  GestureManager* = ref object
    config*: GestureRecognizerConfig
    activeTouches*: Table[int, TouchPoint]  # Touch ID -> TouchPoint
    recognizers: seq[GestureRecognizer]
    recognizedGestures*: seq[GestureData]
    enabled*: bool

    # Callbacks
    onGesture*: proc(gesture: GestureData)

# ============================================================================
# Initialization
# ============================================================================

proc newGestureManager*(config: GestureRecognizerConfig = defaultGestureConfig()): GestureManager =
  ## Create a new gesture manager with given configuration
  result = GestureManager(
    config: config,
    activeTouches: initTable[int, TouchPoint](),
    recognizers: @[],
    recognizedGestures: @[],
    enabled: true
  )

# ============================================================================
# Touch Event Processing
# ============================================================================

proc updateTouchPoint(tp: var TouchPoint, newPos: Point) =
  ## Update a touch point with new position
  tp.previousPosition = tp.position
  tp.position = newPos
  tp.timestamp = getMonoTime()

proc addTouch*(gm: GestureManager, touchId: int, position: Point) =
  ## Register a new touch point
  if not gm.enabled:
    return

  let touchPoint = TouchPoint(
    id: touchId,
    position: position,
    previousPosition: position,
    startPosition: position,
    timestamp: getMonoTime()
  )
  gm.activeTouches[touchId] = touchPoint

proc updateTouch*(gm: GestureManager, touchId: int, position: Point) =
  ## Update an existing touch point
  if not gm.enabled:
    return

  if touchId in gm.activeTouches:
    gm.activeTouches[touchId].updateTouchPoint(position)

proc removeTouch*(gm: GestureManager, touchId: int) =
  ## Remove a touch point (touch ended)
  if not gm.enabled:
    return

  gm.activeTouches.del(touchId)

# ============================================================================
# Math Helpers
# ============================================================================

proc distance(p1, p2: Point): float32 =
  ## Calculate distance between two points
  sqrt((p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y))

proc angle(p1, p2: Point): float32 =
  ## Calculate angle between two points (in radians)
  arctan2(p2.y - p1.y, p2.x - p1.x)

proc velocity(start, current: Point, duration: Duration): Point =
  ## Calculate velocity (pixels per second)
  let seconds = duration.inMilliseconds.float32 / 1000.0
  if seconds > 0:
    Point(
      x: (current.x - start.x) / seconds,
      y: (current.y - start.y) / seconds
    )
  else:
    Point(x: 0, y: 0)

proc twoPointCenter(p1, p2: Point): Point =
  ## Calculate center point between two points
  Point(
    x: (p1.x + p2.x) / 2.0,
    y: (p1.y + p2.y) / 2.0
  )

proc twoPointDistance(touches: seq[TouchPoint]): float32 =
  ## Calculate distance between first two touch points
  if touches.len >= 2:
    distance(touches[0].position, touches[1].position)
  else:
    0.0f32

proc twoPointAngle(touches: seq[TouchPoint]): float32 =
  ## Calculate angle between first two touch points
  if touches.len >= 2:
    angle(touches[0].position, touches[1].position)
  else:
    0.0f32

# ============================================================================
# Gesture Recognition - Tap
# ============================================================================

proc recognizeTap(gm: GestureManager, touch: TouchPoint): Option[GestureData] =
  ## Recognize single tap gesture
  let duration = getMonoTime() - touch.timestamp
  let movement = distance(touch.startPosition, touch.position)

  if duration <= gm.config.tapMaxDuration and movement <= gm.config.tapMaxMovement:
    return some(GestureData(
      kind: gkTap,
      state: gsEnded,
      position: touch.position,
      numberOfTouches: 1,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Gesture Recognition - Long Press
# ============================================================================

proc recognizeLongPress(gm: GestureManager, touch: TouchPoint): Option[GestureData] =
  ## Recognize long press gesture
  let duration = getMonoTime() - touch.timestamp
  let movement = distance(touch.startPosition, touch.position)

  if duration >= gm.config.longPressMinDuration and
     movement <= gm.config.longPressMaxMovement:
    return some(GestureData(
      kind: gkLongPress,
      state: gsEnded,
      position: touch.position,
      numberOfTouches: 1,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Gesture Recognition - Swipe
# ============================================================================

proc getSwipeDirection(delta: Point): SwipeDirection =
  ## Determine swipe direction from delta
  if abs(delta.x) > abs(delta.y):
    if delta.x > 0: sdRight else: sdLeft
  else:
    if delta.y > 0: sdDown else: sdUp

proc recognizeSwipe(gm: GestureManager, touch: TouchPoint): Option[GestureData] =
  ## Recognize swipe gesture
  let delta = Point(
    x: touch.position.x - touch.startPosition.x,
    y: touch.position.y - touch.startPosition.y
  )
  let dist = distance(touch.startPosition, touch.position)
  let duration = getMonoTime() - touch.timestamp
  let vel = velocity(touch.startPosition, touch.position, duration)
  let speed = sqrt(vel.x * vel.x + vel.y * vel.y)

  if dist >= gm.config.swipeMinDistance and speed >= gm.config.swipeMinVelocity:
    return some(GestureData(
      kind: gkSwipe,
      state: gsEnded,
      position: touch.position,
      delta: delta,
      velocity: vel,
      direction: getSwipeDirection(delta),
      numberOfTouches: 1,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Gesture Recognition - Pan
# ============================================================================

proc recognizePan(gm: GestureManager, touch: TouchPoint, state: GestureState): Option[GestureData] =
  ## Recognize pan/drag gesture
  let delta = Point(
    x: touch.position.x - touch.previousPosition.x,
    y: touch.position.y - touch.previousPosition.y
  )
  let totalDist = distance(touch.startPosition, touch.position)

  if totalDist >= gm.config.panMinDistance or state == gsEnded:
    let duration = getMonoTime() - touch.timestamp
    let vel = velocity(touch.startPosition, touch.position, duration)

    return some(GestureData(
      kind: gkPan,
      state: state,
      position: touch.position,
      delta: delta,
      velocity: vel,
      numberOfTouches: 1,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Gesture Recognition - Pinch
# ============================================================================

proc recognizePinch(gm: GestureManager, touches: seq[TouchPoint],
                    initialDistance: float32, state: GestureState): Option[GestureData] =
  ## Recognize pinch (zoom) gesture
  if touches.len < 2:
    return none(GestureData)

  let currentDistance = twoPointDistance(touches)
  let scale = if initialDistance > 0: currentDistance / initialDistance else: 1.0f32

  if abs(scale - 1.0) >= gm.config.pinchMinScaleChange or state == gsEnded:
    let center = twoPointCenter(touches[0].position, touches[1].position)

    return some(GestureData(
      kind: gkPinch,
      state: state,
      position: center,
      scale: scale,
      numberOfTouches: 2,
      touchPoints: touches,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Gesture Recognition - Rotate
# ============================================================================

proc recognizeRotate(gm: GestureManager, touches: seq[TouchPoint],
                     initialAngle: float32, state: GestureState): Option[GestureData] =
  ## Recognize rotation gesture
  if touches.len < 2:
    return none(GestureData)

  let currentAngle = twoPointAngle(touches)
  let rotation = currentAngle - initialAngle

  if abs(rotation) >= gm.config.rotateMinAngleChange or state == gsEnded:
    let center = twoPointCenter(touches[0].position, touches[1].position)

    return some(GestureData(
      kind: gkRotate,
      state: state,
      position: center,
      rotation: rotation,
      numberOfTouches: 2,
      touchPoints: touches,
      timestamp: getMonoTime()
    ))

  return none(GestureData)

# ============================================================================
# Main Recognition Update
# ============================================================================

proc recognizeGestures*(gm: GestureManager) =
  ## Main gesture recognition loop - call this every frame
  if not gm.enabled:
    return

  gm.recognizedGestures.setLen(0)

  let touchCount = gm.activeTouches.len

  if touchCount == 0:
    return

  # Collect current touches
  var touches: seq[TouchPoint]
  for touch in gm.activeTouches.values:
    touches.add(touch)

  # Single touch gestures
  if touchCount == 1:
    let touch = touches[0]

    # Try to recognize gestures in priority order
    # Check for ongoing pan first
    let panGesture = gm.recognizePan(touch, gsChanged)
    if panGesture.isSome:
      gm.recognizedGestures.add(panGesture.get)

  # Two-finger gestures
  elif touchCount == 2:
    # Calculate initial distance and angle if not already done
    # (In a full implementation, this would be tracked in recognizer state)
    let initialDist = twoPointDistance(touches)
    let initialAngle = twoPointAngle(touches)

    # Try pinch
    let pinchGesture = gm.recognizePinch(touches, initialDist, gsChanged)
    if pinchGesture.isSome:
      gm.recognizedGestures.add(pinchGesture.get)

    # Try rotate
    let rotateGesture = gm.recognizeRotate(touches, initialAngle, gsChanged)
    if rotateGesture.isSome:
      gm.recognizedGestures.add(rotateGesture.get)

  # Call callback for each recognized gesture
  if gm.onGesture != nil:
    for gesture in gm.recognizedGestures:
      gm.onGesture(gesture)

proc checkEndGestures*(gm: GestureManager, touchId: int) =
  ## Check for gesture completion when a touch ends
  if not gm.enabled or touchId notin gm.activeTouches:
    return

  let touch = gm.activeTouches[touchId]

  # Check for tap (prioritize over swipe)
  let tapGesture = gm.recognizeTap(touch)
  if tapGesture.isSome:
    if gm.onGesture != nil:
      gm.onGesture(tapGesture.get)
    return

  # Check for long press
  let longPressGesture = gm.recognizeLongPress(touch)
  if longPressGesture.isSome:
    if gm.onGesture != nil:
      gm.onGesture(longPressGesture.get)
    return

  # Check for swipe
  let swipeGesture = gm.recognizeSwipe(touch)
  if swipeGesture.isSome:
    if gm.onGesture != nil:
      gm.onGesture(swipeGesture.get)
    return

  # Check for pan end
  let panGesture = gm.recognizePan(touch, gsEnded)
  if panGesture.isSome:
    if gm.onGesture != nil:
      gm.onGesture(panGesture.get)

# ============================================================================
# Utility Functions
# ============================================================================

proc clear*(gm: GestureManager) =
  ## Clear all active touches and recognizers
  gm.activeTouches.clear()
  gm.recognizers.setLen(0)
  gm.recognizedGestures.setLen(0)

proc getTouchCount*(gm: GestureManager): int =
  ## Get number of active touches
  gm.activeTouches.len

proc enable*(gm: GestureManager) =
  ## Enable gesture recognition
  gm.enabled = true

proc disable*(gm: GestureManager) =
  ## Disable gesture recognition
  gm.enabled = false
  gm.clear()
