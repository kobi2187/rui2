## Momentum Scroll
##
## iOS-style scrolling with inertia, bounce, and smooth deceleration.
## Provides natural touch-based scrolling for mobile interfaces.

import ../types
import ../../core/types
import std/[math, monotimes, times]

# ============================================================================
# Momentum Scroll Types
# ============================================================================

type
  ScrollPhase* = enum
    spIdle          # Not scrolling
    spTouching      # User is touching and dragging
    spDecelerating  # Coasting with momentum
    spBouncing      # Bouncing at boundary

  MomentumScroll* = ref object of Widget
    phase*: ScrollPhase

    # Scroll state
    scrollOffset*: Point          # Current scroll position
    velocity*: Point              # Current velocity (pixels/second)
    maxVelocity*: float32         # Max velocity cap

    # Touch tracking
    lastTouchPos*: Point
    lastTouchTime*: MonoTime
    isDragging*: bool

    # Configuration
    friction*: float32            # Deceleration factor (0-1)
    bounceEnabled*: bool          # Enable bounce at edges
    bounceStiffness*: float32     # Spring constant for bounce
    bounceDamping*: float32       # Damping for bounce

    # Boundaries
    contentSize*: Size            # Size of scrollable content
    viewportSize*: Size           # Size of visible area
    minScrollOffset*: Point       # Minimum scroll (usually 0,0)
    maxScrollOffset*: Point       # Maximum scroll

    # Callbacks
    onScroll*: proc(offset: Point)
    onScrollStart*: proc()
    onScrollEnd*: proc()

    # Content widget
    contentWidget*: Widget

# ============================================================================
# Initialization
# ============================================================================

proc newMomentumScroll*(contentWidget: Widget = nil): MomentumScroll =
  ## Create a new momentum scroll container
  result = MomentumScroll(
    id: newWidgetId(),
    phase: spIdle,
    scrollOffset: Point(x: 0, y: 0),
    velocity: Point(x: 0, y: 0),
    maxVelocity: 5000.0f32,
    friction: 0.95f32,
    bounceEnabled: true,
    bounceStiffness: 0.3f32,
    bounceDamping: 0.7f32,
    isDragging: false,
    contentWidget: contentWidget,
    visible: true,
    enabled: true
  )

  if contentWidget != nil:
    contentWidget.parent = result
    result.children = @[contentWidget]

# ============================================================================
# Boundary Calculations
# ============================================================================

proc updateScrollBounds*(ms: MomentumScroll) =
  ## Recalculate scroll boundaries based on content and viewport size
  ms.minScrollOffset = Point(x: 0, y: 0)
  ms.maxScrollOffset = Point(
    x: max(0, ms.contentSize.width - ms.viewportSize.width),
    y: max(0, ms.contentSize.height - ms.viewportSize.height)
  )

proc isOutOfBounds*(ms: MomentumScroll): bool =
  ## Check if scroll position is outside valid bounds
  ms.scrollOffset.x < ms.minScrollOffset.x or
  ms.scrollOffset.x > ms.maxScrollOffset.x or
  ms.scrollOffset.y < ms.minScrollOffset.y or
  ms.scrollOffset.y > ms.maxScrollOffset.y

proc clampToBounds(ms: MomentumScroll, offset: Point): Point =
  ## Clamp offset to valid scroll bounds
  Point(
    x: clamp(offset.x, ms.minScrollOffset.x, ms.maxScrollOffset.x),
    y: clamp(offset.y, ms.minScrollOffset.y, ms.maxScrollOffset.y)
  )

# ============================================================================
# Touch Handling
# ============================================================================

proc onTouchStart*(ms: MomentumScroll, position: Point) =
  ## User started touching
  ms.isDragging = true
  ms.lastTouchPos = position
  ms.lastTouchTime = getMonoTime()
  ms.velocity = Point(x: 0, y: 0)  # Stop momentum
  ms.phase = spTouching

  if ms.onScrollStart != nil:
    ms.onScrollStart()

proc onTouchMove*(ms: MomentumScroll, position: Point) =
  ## User is dragging
  if not ms.isDragging:
    return

  let now = getMonoTime()
  let delta = Point(
    x: position.x - ms.lastTouchPos.x,
    y: position.y - ms.lastTouchPos.y
  )

  # Update scroll offset (invert delta for natural scrolling)
  ms.scrollOffset.x -= delta.x
  ms.scrollOffset.y -= delta.y

  # Apply bounce resistance if out of bounds
  if ms.bounceEnabled and ms.isOutOfBounds():
    let clamped = ms.clampToBounds(ms.scrollOffset)
    let overscroll = Point(
      x: ms.scrollOffset.x - clamped.x,
      y: ms.scrollOffset.y - clamped.y
    )
    # Reduce overscroll by damping
    ms.scrollOffset.x = clamped.x + overscroll.x * ms.bounceDamping
    ms.scrollOffset.y = clamped.y + overscroll.y * ms.bounceDamping

  # Calculate velocity
  let timeDelta = now - ms.lastTouchTime
  let seconds = timeDelta.inMicroseconds.float32 / 1_000_000.0
  if seconds > 0:
    ms.velocity.x = -delta.x / seconds
    ms.velocity.y = -delta.y / seconds

  ms.lastTouchPos = position
  ms.lastTouchTime = now

  if ms.onScroll != nil:
    ms.onScroll(ms.scrollOffset)

  ms.isDirty = true

proc onTouchEnd*(ms: MomentumScroll) =
  ## User stopped touching
  ms.isDragging = false

  # Check if velocity is significant enough for momentum
  let speed = sqrt(ms.velocity.x * ms.velocity.x + ms.velocity.y * ms.velocity.y)

  if speed > 50.0f32:  # Minimum velocity threshold
    ms.phase = spDecelerating
    # Cap velocity
    if speed > ms.maxVelocity:
      let scale = ms.maxVelocity / speed
      ms.velocity.x *= scale
      ms.velocity.y *= scale
  else:
    # No significant momentum
    if ms.isOutOfBounds():
      ms.phase = spBouncing
    else:
      ms.phase = spIdle
      if ms.onScrollEnd != nil:
        ms.onScrollEnd()

# ============================================================================
# Physics Update
# ============================================================================

proc updateDeceleration(ms: MomentumScroll, deltaTime: float32) =
  ## Update momentum deceleration
  # Apply friction
  ms.velocity.x *= ms.friction
  ms.velocity.y *= ms.friction

  # Update position
  ms.scrollOffset.x += ms.velocity.x * deltaTime
  ms.scrollOffset.y += ms.velocity.y * deltaTime

  # Check if velocity is negligible
  let speed = sqrt(ms.velocity.x * ms.velocity.x + ms.velocity.y * ms.velocity.y)
  if speed < 1.0f32:
    ms.velocity = Point(x: 0, y: 0)

    # Check if out of bounds
    if ms.isOutOfBounds():
      ms.phase = spBouncing
    else:
      ms.phase = spIdle
      if ms.onScrollEnd != nil:
        ms.onScrollEnd()
  elif ms.isOutOfBounds():
    # Hit boundary while decelerating
    ms.phase = spBouncing

proc updateBounce(ms: MomentumScroll, deltaTime: float32) =
  ## Update bounce back animation
  let clamped = ms.clampToBounds(ms.scrollOffset)
  let overscroll = Point(
    x: ms.scrollOffset.x - clamped.x,
    y: ms.scrollOffset.y - clamped.y
  )

  # Apply spring force towards bounds
  let forceX = -overscroll.x * ms.bounceStiffness
  let forceY = -overscroll.y * ms.bounceStiffness

  # Update velocity with spring force
  ms.velocity.x += forceX
  ms.velocity.y += forceY

  # Apply damping
  ms.velocity.x *= ms.bounceDamping
  ms.velocity.y *= ms.bounceDamping

  # Update position
  ms.scrollOffset.x += ms.velocity.x * deltaTime
  ms.scrollOffset.y += ms.velocity.y * deltaTime

  # Check if settled
  let speed = sqrt(ms.velocity.x * ms.velocity.x + ms.velocity.y * ms.velocity.y)
  let dist = sqrt(overscroll.x * overscroll.x + overscroll.y * overscroll.y)

  if speed < 1.0f32 and dist < 0.5f32:
    ms.scrollOffset = clamped
    ms.velocity = Point(x: 0, y: 0)
    ms.phase = spIdle
    if ms.onScrollEnd != nil:
      ms.onScrollEnd()

proc update*(ms: MomentumScroll, deltaTime: float32) =
  ## Update scroll physics (call every frame with delta time in seconds)
  case ms.phase
  of spDecelerating:
    ms.updateDeceleration(deltaTime)
    if ms.onScroll != nil:
      ms.onScroll(ms.scrollOffset)
    ms.isDirty = true

  of spBouncing:
    if ms.bounceEnabled:
      ms.updateBounce(deltaTime)
      if ms.onScroll != nil:
        ms.onScroll(ms.scrollOffset)
      ms.isDirty = true
    else:
      # No bounce - just clamp
      ms.scrollOffset = ms.clampToBounds(ms.scrollOffset)
      ms.velocity = Point(x: 0, y: 0)
      ms.phase = spIdle
      if ms.onScrollEnd != nil:
        ms.onScrollEnd()

  else:
    discard

# ============================================================================
# Gesture Integration
# ============================================================================

proc handleGesture*(ms: MomentumScroll, gesture: GestureData): bool =
  ## Handle gesture from gesture manager
  case gesture.kind
  of gkPan:
    case gesture.state
    of gsBegan:
      ms.onTouchStart(gesture.position)
      return true

    of gsChanged:
      ms.onTouchMove(gesture.position)
      return true

    of gsEnded:
      ms.onTouchEnd()
      return true

    of gsCancelled:
      ms.isDragging = false
      ms.phase = spIdle
      return true

  else:
    return false

  return false

# ============================================================================
# Programmatic Scrolling
# ============================================================================

proc scrollTo*(ms: MomentumScroll, offset: Point, animated: bool = true) =
  ## Scroll to specific offset
  if animated:
    # Calculate velocity needed to reach target
    let delta = Point(
      x: offset.x - ms.scrollOffset.x,
      y: offset.y - ms.scrollOffset.y
    )
    ms.velocity = Point(x: delta.x * 5.0f32, y: delta.y * 5.0f32)
    ms.phase = spDecelerating
  else:
    ms.scrollOffset = ms.clampToBounds(offset)
    ms.velocity = Point(x: 0, y: 0)
    ms.phase = spIdle

  if ms.onScroll != nil:
    ms.onScroll(ms.scrollOffset)
  ms.isDirty = true

proc scrollBy*(ms: MomentumScroll, delta: Point, animated: bool = true) =
  ## Scroll by delta amount
  let newOffset = Point(
    x: ms.scrollOffset.x + delta.x,
    y: ms.scrollOffset.y + delta.y
  )
  ms.scrollTo(newOffset, animated)

# ============================================================================
# Layout
# ============================================================================

method layout*(ms: MomentumScroll) =
  ## Layout content with scroll offset
  if ms.contentWidget != nil:
    # Update viewport size
    ms.viewportSize = Size(width: ms.bounds.width, height: ms.bounds.height)

    # Position content with scroll offset
    let contentBounds = Rect(
      x: ms.bounds.x - ms.scrollOffset.x,
      y: ms.bounds.y - ms.scrollOffset.y,
      width: ms.contentSize.width,
      height: ms.contentSize.height
    )
    ms.contentWidget.bounds = contentBounds

# ============================================================================
# Utility Functions
# ============================================================================

proc isScrolling*(ms: MomentumScroll): bool =
  ## Check if currently scrolling
  ms.phase != spIdle

proc stopScrolling*(ms: MomentumScroll) =
  ## Stop all scrolling immediately
  ms.velocity = Point(x: 0, y: 0)
  ms.phase = spIdle
  ms.isDragging = false

proc reset*(ms: MomentumScroll) =
  ## Reset to top
  ms.scrollTo(Point(x: 0, y: 0), animated = false)
  ms.stopScrolling()
