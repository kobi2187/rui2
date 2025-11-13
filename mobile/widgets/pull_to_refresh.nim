## Pull to Refresh Widget
##
## Mobile pattern for refreshing content by pulling down.
## Common in social media and news apps.

import ../types
import ../../core/types
import std/[monotimes, times, math]

# ============================================================================
# Pull to Refresh Types
# ============================================================================

type
  RefreshState* = enum
    rsIdle         # Not pulling
    rsPulling      # User is pulling down
    rsReady        # Pulled enough to trigger refresh
    rsRefreshing   # Currently refreshing
    rsCompleting   # Refresh complete, animating back

  PullToRefresh* = ref object of Widget
    state*: RefreshState
    pullDistance*: float32        # Current pull distance
    triggerDistance*: float32     # Distance to trigger refresh (default: 80px)
    maxPullDistance*: float32     # Max pull distance (default: 150px)
    damping*: float32             # Pull resistance factor (0-1)

    # Animation
    animationProgress*: float32
    animationStartTime: MonoTime
    animationDuration*: float32   # seconds

    # State
    isRefreshing*: bool
    isPulling*: bool
    startY*: float32
    currentY*: float32

    # Callbacks
    onRefresh*: proc()            # Called when refresh triggered
    onStateChange*: proc(oldState, newState: RefreshState)

    # Child content
    contentWidget*: Widget

# ============================================================================
# Initialization
# ============================================================================

proc newPullToRefresh*(contentWidget: Widget): PullToRefresh =
  ## Create a new pull-to-refresh wrapper
  result = PullToRefresh(
    id: newWidgetId(),
    state: rsIdle,
    pullDistance: 0.0f32,
    triggerDistance: 80.0f32,
    maxPullDistance: 150.0f32,
    damping: 0.5f32,
    animationDuration: 0.3f32,
    isRefreshing: false,
    isPulling: false,
    contentWidget: contentWidget,
    visible: true,
    enabled: true
  )

  if contentWidget != nil:
    contentWidget.parent = result
    result.children = @[contentWidget]

# ============================================================================
# State Management
# ============================================================================

proc setState(ptr: PullToRefresh, newState: RefreshState) =
  ## Change refresh state with callback
  if ptr.state != newState:
    let oldState = ptr.state
    ptr.state = newState

    if ptr.onStateChange != nil:
      ptr.onStateChange(oldState, newState)

    ptr.isDirty = true

proc startRefresh*(ptr: PullToRefresh) =
  ## Start refresh programmatically
  if ptr.state in {rsIdle, rsPulling, rsReady}:
    ptr.setState(rsRefreshing)
    ptr.isRefreshing = true

    if ptr.onRefresh != nil:
      ptr.onRefresh()

proc completeRefresh*(ptr: PullToRefresh) =
  ## Complete refresh and animate back
  if ptr.state == rsRefreshing:
    ptr.setState(rsCompleting)
    ptr.isRefreshing = false
    ptr.animationStartTime = getMonoTime()
    ptr.animationProgress = 0.0f32

# ============================================================================
# Pull Gesture Handling
# ============================================================================

proc calculateDampedPull(ptr: PullToRefresh, rawPull: float32): float32 =
  ## Apply damping to pull distance
  if rawPull <= 0:
    return 0.0f32

  # Apply exponential damping as pull increases
  let normalized = rawPull / ptr.maxPullDistance
  let damped = pow(normalized, 1.0 + ptr.damping)
  result = damped * ptr.maxPullDistance

  # Clamp to max
  result = min(result, ptr.maxPullDistance)

proc onPullStart*(ptr: PullToRefresh, y: float32) =
  ## User started pulling
  if ptr.state in {rsRefreshing, rsCompleting}:
    return

  ptr.isPulling = true
  ptr.startY = y
  ptr.currentY = y
  ptr.setState(rsPulling)

proc onPullMove*(ptr: PullToRefresh, y: float32) =
  ## User is pulling
  if not ptr.isPulling or ptr.state notin {rsPulling, rsReady}:
    return

  ptr.currentY = y
  let rawPull = y - ptr.startY

  # Only allow downward pulls
  if rawPull > 0:
    ptr.pullDistance = ptr.calculateDampedPull(rawPull)

    # Check if reached trigger threshold
    if ptr.pullDistance >= ptr.triggerDistance and ptr.state != rsReady:
      ptr.setState(rsReady)
    elif ptr.pullDistance < ptr.triggerDistance and ptr.state == rsReady:
      ptr.setState(rsPulling)

    ptr.isDirty = true

proc onPullEnd*(ptr: PullToRefresh) =
  ## User stopped pulling
  if not ptr.isPulling:
    return

  ptr.isPulling = false

  # Check if should trigger refresh
  if ptr.state == rsReady and ptr.pullDistance >= ptr.triggerDistance:
    ptr.startRefresh()
  else:
    # Animate back to idle
    ptr.setState(rsCompleting)
    ptr.animationStartTime = getMonoTime()
    ptr.animationProgress = 0.0f32

# ============================================================================
# Animation Update
# ============================================================================

proc update*(ptr: PullToRefresh) =
  ## Update animations (call every frame)
  case ptr.state
  of rsCompleting:
    # Animate pull distance back to 0
    let elapsed = getMonoTime() - ptr.animationStartTime
    let elapsedSec = elapsed.inMilliseconds.float32 / 1000.0
    ptr.animationProgress = elapsedSec / ptr.animationDuration

    if ptr.animationProgress >= 1.0:
      ptr.pullDistance = 0.0f32
      ptr.setState(rsIdle)
    else:
      # Ease-out animation
      let eased = 1.0 - pow(1.0 - ptr.animationProgress, 3.0)
      ptr.pullDistance = ptr.pullDistance * (1.0 - eased)

    ptr.isDirty = true

  of rsRefreshing:
    # Keep pull distance at trigger point during refresh
    ptr.pullDistance = ptr.triggerDistance
    ptr.isDirty = true

  else:
    discard

# ============================================================================
# Gesture Integration
# ============================================================================

proc handleGesture*(ptr: PullToRefresh, gesture: GestureData): bool =
  ## Handle gesture from gesture manager
  case gesture.kind
  of gkPan:
    case gesture.state
    of gsBegan:
      # Check if pan started at top of content
      if gesture.position.y <= ptr.bounds.y + 50.0f32:  # Near top
        ptr.onPullStart(gesture.position.y)
        return true

    of gsChanged:
      if ptr.isPulling:
        ptr.onPullMove(gesture.position.y)
        return true

    of gsEnded:
      if ptr.isPulling:
        ptr.onPullEnd()
        return true

    of gsCancelled:
      ptr.isPulling = false
      ptr.setState(rsIdle)
      return true

  else:
    return false

  return false

# ============================================================================
# Layout
# ============================================================================

method layout*(ptr: PullToRefresh) =
  ## Layout content with offset for pull
  if ptr.contentWidget != nil:
    # Offset content by pull distance
    let contentBounds = Rect(
      x: ptr.bounds.x,
      y: ptr.bounds.y + ptr.pullDistance,
      width: ptr.bounds.width,
      height: ptr.bounds.height
    )
    ptr.contentWidget.bounds = contentBounds

# ============================================================================
# Rendering
# ============================================================================

method render*(ptr: PullToRefresh) =
  ## Render pull-to-refresh indicator
  # In real implementation, would draw:
  # - Spinner/arrow indicator at top
  # - Progress indicator based on pull distance
  # - Different visuals for each state

  # Pseudo-code:
  # let indicatorY = ptr.bounds.y + ptr.pullDistance - 40
  # if ptr.state == rsRefreshing:
  #   drawSpinner(center: Point(x: ptr.bounds.width/2, y: indicatorY))
  # elif ptr.pullDistance > 0:
  #   drawArrow(rotation based on pullDistance/triggerDistance)

  discard

# ============================================================================
# Event Handling
# ============================================================================

method handleInput*(ptr: PullToRefresh, event: GuiEvent): bool =
  ## Handle input events
  # Delegate to content widget if not handled
  if ptr.contentWidget != nil:
    return ptr.contentWidget.handleInput(event)
  return false

# ============================================================================
# Utility Functions
# ============================================================================

proc reset*(ptr: PullToRefresh) =
  ## Reset to idle state
  ptr.setState(rsIdle)
  ptr.pullDistance = 0.0f32
  ptr.isPulling = false
  ptr.isRefreshing = false
  ptr.isDirty = true

proc isActive*(ptr: PullToRefresh): bool =
  ## Check if pull-to-refresh is active
  ptr.state != rsIdle

proc getProgress*(ptr: PullToRefresh): float32 =
  ## Get pull progress (0.0 to 1.0)
  if ptr.triggerDistance > 0:
    min(ptr.pullDistance / ptr.triggerDistance, 1.0)
  else:
    0.0f32
