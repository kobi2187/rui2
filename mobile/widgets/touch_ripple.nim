## Touch Ripple Effect
##
## Material Design-style ripple effect for touch feedback.
## Shows expanding circular ripple from touch point.

import ../types
import ../../core/types
import std/[monotimes, times, math]

# ============================================================================
# Touch Ripple Types
# ============================================================================

type
  RippleState = enum
    rsExpanding   # Ripple is growing
    rsFading      # Ripple is fading out
    rsFinished    # Ripple completed

  Ripple = object
    center: Point
    radius: float32
    maxRadius: float32
    alpha: float32
    state: RippleState
    startTime: MonoTime

  TouchRipple* = ref object of Widget
    ripples: seq[Ripple]
    rippleColor*: Color
    rippleDuration*: float32  # seconds
    maxRipples*: int
    enabled*: bool

# ============================================================================
# Initialization
# ============================================================================

proc newTouchRipple*(): TouchRipple =
  ## Create a new touch ripple widget
  result = TouchRipple(
    id: newWidgetId(),
    ripples: @[],
    rippleColor: Color(),  # Will need to set based on theme
    rippleDuration: 0.6f32,
    maxRipples: 5,
    enabled: true,
    visible: true,
    enabled: true
  )

# ============================================================================
# Ripple Management
# ============================================================================

proc startRipple*(tr: TouchRipple, position: Point) =
  ## Start a new ripple at the given position
  if not tr.enabled:
    return

  # Calculate max radius (to cover entire widget)
  let dx = max(position.x - tr.bounds.x,
               tr.bounds.x + tr.bounds.width - position.x)
  let dy = max(position.y - tr.bounds.y,
               tr.bounds.y + tr.bounds.height - position.y)
  let maxRadius = sqrt(dx * dx + dy * dy)

  let ripple = Ripple(
    center: position,
    radius: 0.0f32,
    maxRadius: maxRadius,
    alpha: 0.3f32,
    state: rsExpanding,
    startTime: getMonoTime()
  )

  tr.ripples.add(ripple)

  # Limit number of concurrent ripples
  while tr.ripples.len > tr.maxRipples:
    tr.ripples.delete(0)

  tr.isDirty = true

proc updateRipples*(tr: TouchRipple) =
  ## Update all active ripples (call every frame)
  if tr.ripples.len == 0:
    return

  let now = getMonoTime()
  var anyActive = false

  for i in 0..<tr.ripples.len:
    if tr.ripples[i].state == rsFinished:
      continue

    let elapsed = now - tr.ripples[i].startTime
    let elapsedSec = elapsed.inMilliseconds.float32 / 1000.0
    let progress = elapsedSec / tr.rippleDuration

    if progress >= 1.0:
      tr.ripples[i].state = rsFinished
      continue

    anyActive = true

    # Update ripple based on state
    case tr.ripples[i].state
    of rsExpanding:
      # Expand to max radius over 60% of duration
      let expandProgress = min(progress / 0.6, 1.0)
      tr.ripples[i].radius = tr.ripples[i].maxRadius * expandProgress

      # Start fading at 60%
      if progress > 0.6:
        tr.ripples[i].state = rsFading

    of rsFading:
      # Fade out over remaining duration
      let fadeProgress = (progress - 0.6) / 0.4
      tr.ripples[i].alpha = 0.3f32 * (1.0 - fadeProgress)

    of rsFinished:
      discard

  # Remove finished ripples
  tr.ripples.keepIf(proc(r: Ripple): bool = r.state != rsFinished)

  if anyActive:
    tr.isDirty = true

# ============================================================================
# Rendering
# ============================================================================

method render*(tr: TouchRipple) =
  ## Render ripples
  # In real implementation, would draw circles with appropriate alpha
  # For now, this is a placeholder that would integrate with drawing_primitives

  # Pseudo-code:
  # for ripple in tr.ripples:
  #   drawCircle(ripple.center, ripple.radius,
  #              colorWithAlpha(tr.rippleColor, ripple.alpha))

  discard

# ============================================================================
# Event Handling
# ============================================================================

method handleInput*(tr: TouchRipple, event: GuiEvent): bool =
  ## Handle touch/mouse events to trigger ripples
  if not tr.enabled:
    return false

  case event.kind
  of evMouseDown, evTouchStart:
    tr.startRipple(event.mousePos)
    return false  # Don't consume event

  else:
    return false

# ============================================================================
# Utility Functions
# ============================================================================

proc clearRipples*(tr: TouchRipple) =
  ## Clear all active ripples
  tr.ripples.setLen(0)
  tr.isDirty = true

proc setRippleColor*(tr: TouchRipple, color: Color) =
  ## Set ripple color
  tr.rippleColor = color

proc enable*(tr: TouchRipple) =
  ## Enable ripple effect
  tr.enabled = true

proc disable*(tr: TouchRipple) =
  ## Disable ripple effect
  tr.enabled = false
  tr.clearRipples()
