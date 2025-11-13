# Mobile Event Flow Documentation

Complete documentation of how touch events flow through the RUI mobile system.

## Event Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Physical Touch/Mouse                      │
│                  (Hardware/OS/Window Manager)                │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      Raylib Core                             │
│  • GetTouchPointCount()                                      │
│  • GetTouchPosition(i)                                       │
│  • GetTouchPointId(i)                                        │
│  • IsMouseButtonPressed/Down/Released()                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              RaylibInputProvider                             │
│  (mobile/platform/raylib_input.nim)                          │
│                                                               │
│  Every Frame:                                                │
│  1. Poll raylib touch functions                              │
│  2. Track touch starts/moves/ends                            │
│  3. Map raylib IDs to internal IDs                           │
│  4. OR: Simulate touch from mouse (desktop testing)          │
│                                                               │
│  Methods:                                                    │
│  • update() - Main update loop                               │
│  • pollTouchInput() - Get real touch events                  │
│  • pollMouseAsTouch() - Simulate from mouse                  │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│               GestureManager                                 │
│  (mobile/managers/gesture_manager.nim)                       │
│                                                               │
│  Receives:                                                   │
│  • addTouch(id, position) - New touch                        │
│  • updateTouch(id, position) - Touch moved                   │
│  • removeTouch(id) - Touch ended                             │
│  • checkEndGestures(id) - Check for completed gestures       │
│                                                               │
│  Processes:                                                  │
│  • Tracks touch points (position, velocity, time)            │
│  • Calculates distances, angles, scales                      │
│  • Applies thresholds and timing windows                     │
│  • Recognizes gesture patterns                               │
│                                                               │
│  Recognizes:                                                 │
│  • Tap, DoubleTap, LongPress                                 │
│  • Swipe (4 directions with velocity)                        │
│  • Pan/Drag (continuous with delta)                          │
│  • Pinch (2-finger zoom with scale)                          │
│  • Rotate (2-finger rotation with angle)                     │
│  • EdgeSwipe (from screen edges)                             │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│            Gesture Callbacks                                 │
│                                                               │
│  gestureManager.onGesture = proc(gesture: GestureData) =     │
│    case gesture.kind:                                        │
│    of gkTap: handleTap(gesture.position)                     │
│    of gkSwipe: handleSwipe(gesture.direction)                │
│    of gkPinch: handleZoom(gesture.scale)                     │
│    ...                                                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│          Your Application Logic                              │
│  • Handle gestures                                           │
│  • Update widget state                                       │
│  • Trigger animations                                        │
│  • Navigate screens                                          │
│  • etc.                                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailed Event Flow

### 1. Touch Input (Hardware → Raylib)

**On Mobile:**
- User touches screen
- OS generates touch event
- Raylib's Android/iOS backend receives event
- Touch point becomes available via raylib API

**On Desktop (Testing):**
- User clicks/drags mouse
- Window manager generates mouse event
- Raylib receives mouse event
- We simulate touch from mouse

### 2. Input Provider (Raylib → GestureManager)

The `RaylibInputProvider` bridges raylib to our gesture system:

```nim
proc update*(provider: RaylibInputProvider) =
  # Check if real touch input available
  let touchCount = GetTouchPointCount()

  if touchCount > 0:
    # Use real touch
    provider.pollTouchInput()
  else:
    # Simulate from mouse (desktop testing)
    provider.pollMouseAsTouch()

  # Run gesture recognition
  provider.gestureManager.recognizeGestures()
```

**Touch Tracking:**
```nim
proc pollTouchInput*(provider: RaylibInputProvider) =
  let touchCount = GetTouchPointCount()

  # Process all active touches
  for i in 0..<touchCount:
    let raylibId = GetTouchPointId(i)
    let position = GetTouchPosition(i)
    let internalId = provider.getOrCreateInternalId(raylibId)

    if isNewTouch:
      gestureManager.addTouch(internalId, position)
    else:
      gestureManager.updateTouch(internalId, position)

  # Find and remove ended touches
  for endedId in getEndedTouches():
    gestureManager.checkEndGestures(endedId)
    gestureManager.removeTouch(endedId)
```

### 3. Gesture Recognition (Raw Touch → High-Level Gestures)

The `GestureManager` analyzes touch patterns:

**Tap Detection:**
```nim
proc recognizeTap(touch: TouchPoint): Option[GestureData] =
  let duration = now() - touch.timestamp
  let movement = distance(touch.startPosition, touch.position)

  if duration <= config.tapMaxDuration and
     movement <= config.tapMaxMovement:
    return some(GestureData(kind: gkTap, ...))
```

**Swipe Detection:**
```nim
proc recognizeSwipe(touch: TouchPoint): Option[GestureData] =
  let delta = touch.position - touch.startPosition
  let distance = length(delta)
  let velocity = calculateVelocity(touch)

  if distance >= config.swipeMinDistance and
     velocity >= config.swipeMinVelocity:
    return some(GestureData(
      kind: gkSwipe,
      direction: getDirection(delta),
      velocity: velocity,
      ...
    ))
```

**Pinch Detection:**
```nim
proc recognizePinch(touches: seq[TouchPoint]): Option[GestureData] =
  if touches.len < 2:
    return none

  let currentDist = distance(touches[0].pos, touches[1].pos)
  let initialDist = getInitialDistance()
  let scale = currentDist / initialDist

  if abs(scale - 1.0) >= config.pinchMinScaleChange:
    return some(GestureData(kind: gkPinch, scale: scale, ...))
```

### 4. Gesture Dispatch (GestureManager → Application)

When a gesture is recognized:

```nim
# In GestureManager
proc recognizeGestures*(gm: GestureManager) =
  # ... recognition logic ...

  let gesture = recognizeCurrentGesture()
  if gesture.isSome:
    gm.recognizedGestures.add(gesture.get)

    # Call callback
    if gm.onGesture != nil:
      gm.onGesture(gesture.get)
```

### 5. Application Handling

Your application receives high-level gestures:

```nim
mobile.gesture.onGesture = proc(gesture: GestureData) =
  case gesture.kind
  of gkSwipe:
    if gesture.direction == sdLeft:
      navigateToNextScreen()
    elif gesture.direction == sdRight:
      navigateToPreviousScreen()

  of gkPinch:
    zoomImage(gesture.scale)

  of gkTap:
    selectItemAt(gesture.position)

  # ... handle other gestures ...
```

---

## Integration with Mobile Widgets

Mobile widgets can intercept gestures:

### MomentumScroll Integration

```nim
proc handleGesture*(ms: MomentumScroll, gesture: GestureData): bool =
  case gesture.kind
  of gkPan:
    case gesture.state
    of gsBegan:
      ms.onTouchStart(gesture.position)
      return true  # Consumed
    of gsChanged:
      ms.onTouchMove(gesture.position)
      return true
    of gsEnded:
      ms.onTouchEnd()
      return true
  else:
    return false  # Not consumed
```

### PullToRefresh Integration

```nim
proc handleGesture*(ptr: PullToRefresh, gesture: GestureData): bool =
  case gesture.kind
  of gkPan:
    if gesture.position.y <= ptr.bounds.y + 50:  # Near top
      case gesture.state
      of gsBegan:
        ptr.onPullStart(gesture.position.y)
        return true
      of gsChanged:
        ptr.onPullMove(gesture.position.y)
        return true
      of gsEnded:
        ptr.onPullEnd()
        return true
  return false
```

### Widget Gesture Chain

```nim
# In your app's gesture callback
mobile.gesture.onGesture = proc(gesture: GestureData) =
  # Try widgets first (specific handling)
  if pullRefreshWidget.handleGesture(gesture):
    return  # Widget consumed it

  if scrollView.handleGesture(gesture):
    return

  # Global gesture handling (general app-level)
  case gesture.kind
  of gkSwipe:
    handleGlobalSwipe(gesture)
  of gkTwoFingerTap:
    showDebugMenu()
  # ...
```

---

## Main Loop Integration

Complete example showing where everything fits:

```nim
import mobile
import core/types

# Initialize
let mobile = initMobileSupport()
let app = createYourApp()

# Configure gesture handling
mobile.gesture.onGesture = proc(gesture: GestureData) =
  # Handle gestures
  handleGesture(app, gesture)

# Main loop
while not windowShouldClose():
  # =====================================
  # 1. INPUT PHASE
  # =====================================

  # Poll touch/mouse and recognize gestures
  mobile.input.update()
  # This calls:
  #   - RaylibInputProvider.update()
  #     - pollTouchInput() or pollMouseAsTouch()
  #     - gestureManager.recognizeGestures()
  #       - Your onGesture callback

  # =====================================
  # 2. UPDATE PHASE
  # =====================================

  # Update keyboard animations
  mobile.keyboard.update()

  # Update mobile widgets
  let deltaTime = getFrameTime()
  scrollView.update(deltaTime)
  refreshView.update()

  # Update app
  app.update(deltaTime)

  # =====================================
  # 3. RENDER PHASE
  # =====================================

  beginDrawing()
  clearBackground(WHITE)

  # Render app
  app.render()

  # Render touch feedback (ripples, etc)
  touchRipple.render()

  endDrawing()
```

---

## Configuration Options

### Gesture Thresholds

```nim
var config = defaultGestureConfig()

# Tap configuration
config.tapMaxDuration = initDuration(milliseconds = 250)
config.tapMaxMovement = 10.0f32

# Swipe configuration
config.swipeMinDistance = 60.0f32
config.swipeMinVelocity = 150.0f32

# Long press configuration
config.longPressMinDuration = initDuration(milliseconds = 600)

let gestureManager = newGestureManager(config)
```

### Input Provider Options

```nim
# Enable/disable mouse simulation
inputProvider.setMouseSimulation(enabled = true)

# Check what input is being used
if inputProvider.isUsingMouseSimulation():
  echo "Using mouse as touch"
else:
  echo "Using real touch input"

# Get active touch count
let touchCount = inputProvider.getActiveTouchCount()
```

---

## Debugging

### Visualize Touch Points

```nim
# In your render loop
when defined(debugTouch):
  for i in 0..<GetTouchPointCount():
    let pos = GetTouchPosition(i)
    drawCircle(pos.x, pos.y, 20, RED)
    drawText($GetTouchPointId(i), pos.x - 5, pos.y - 5, 20, WHITE)
```

### Log Gesture Events

```nim
mobile.gesture.onGesture = proc(gesture: GestureData) =
  echo "[GESTURE] ", gesture.kind, " state: ", gesture.state

  case gesture.kind
  of gkSwipe:
    echo "  direction: ", gesture.direction
    echo "  velocity: ", gesture.velocity
  of gkPinch:
    echo "  scale: ", gesture.scale
  of gkPan:
    echo "  delta: ", gesture.delta
  else:
    discard
```

### Monitor Input Provider

```nim
# Every second
if frameCount mod 60 == 0:
  echo "Active touches: ", inputProvider.getActiveTouchCount()
  echo "Using mouse sim: ", inputProvider.isUsingMouseSimulation()
```

---

## Platform-Specific Notes

### Desktop (Mouse Simulation)

- Left mouse button = touch
- Mouse drag = pan gesture
- Fast mouse drag + release = swipe
- **Limitation**: Can't simulate multi-touch (pinch, rotate)

### Android (via Raymob)

- Full multi-touch support
- Up to 10 simultaneous touch points
- Native gesture performance

### iOS (Future)

- Full multi-touch support
- Native gesture recognizers available
- Can integrate Apple's gesture system

---

## Performance Considerations

### Update Frequency

The input provider should be called **every frame**:

```nim
# ✓ CORRECT
while not windowShouldClose():
  mobile.input.update()  # Every frame
  app.update()
  app.render()

# ✗ WRONG
while not windowShouldClose():
  if frameCount mod 2 == 0:  # Don't skip frames!
    mobile.input.update()
```

### Gesture Recognition Cost

- **Tap/DoubleTap/LongPress**: Very cheap (simple time/distance checks)
- **Swipe/Pan**: Cheap (basic math)
- **Pinch/Rotate**: Moderate (2-point calculations)

Typical performance: < 0.1ms for gesture recognition with 4 active touches

### Optimization Tips

1. **Disable unused gestures** to save CPU:
```nim
gestureManager.disable()  # Turn off entirely
```

2. **Adjust recognition frequency** if needed:
```nim
# Only recognize gestures every N frames (not recommended)
if frameCount mod 2 == 0:
  gestureManager.recognizeGestures()
```

3. **Use bounding box checks** before widget gesture handling:
```nim
if not gesture.position.isInside(widget.bounds):
  return false  # Skip expensive checks
```

---

## Summary

The complete event flow:

1. **Hardware/OS** → Touch event
2. **Raylib** → Polls touch via API
3. **RaylibInputProvider** → Converts to internal format
4. **GestureManager** → Recognizes high-level gestures
5. **Your Callback** → Handles gestures
6. **Application** → Updates state, renders

**Key Points:**
- Call `mobile.input.update()` every frame
- Gesture recognition happens automatically
- Callbacks fire when gestures recognized
- Widgets can consume gestures to prevent global handling
- Mouse simulation enables desktop testing

**One-line integration:**
```nim
mobile.input.update()  # Does everything!
```
