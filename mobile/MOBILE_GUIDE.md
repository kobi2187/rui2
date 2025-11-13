# Mobile Support Guide

Complete guide for adding mobile support to your RUI applications.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Gesture Recognition](#gesture-recognition)
3. [Display Management](#display-management)
4. [Keyboard Handling](#keyboard-handling)
5. [Mobile Widgets](#mobile-widgets)
6. [Responsive Design](#responsive-design)
7. [Best Practices](#best-practices)

---

## Quick Start

### Basic Setup

```nim
import rui
import mobile

# Initialize mobile support
let mobile = initMobileSupport()

# Set up gesture handling
mobile.gesture.onGesture = proc(gesture: GestureData) =
  case gesture.kind
  of gkTap:
    echo "Tapped at: ", gesture.position
  of gkSwipe:
    echo "Swiped: ", gesture.direction
  else:
    discard

# Your app code
let app = newApp()
# ... build UI ...
app.start()
```

### Integration with Event Loop

```nim
# In your main loop
proc mainLoop(app: App, mobile: MobileManagers) =
  while not windowShouldClose():
    # Update mobile managers
    mobile.gesture.recognizeGestures()
    mobile.keyboard.update()
    mobile.display.update()  # If handling orientation changes

    # Regular app update
    app.update()
    app.render()
```

---

## Gesture Recognition

The gesture manager recognizes high-level gestures from raw touch events.

### Supported Gestures

- **Tap**: Quick single touch
- **Double Tap**: Two quick taps
- **Long Press**: Touch and hold
- **Swipe**: Quick directional movement
- **Pan**: Drag gesture
- **Pinch**: Two-finger zoom
- **Rotate**: Two-finger rotation
- **Edge Swipe**: Swipe from screen edge

### Basic Usage

```nim
let gestureManager = newGestureManager()

# Configure gesture recognition
gestureManager.config.tapMaxDuration = initDuration(milliseconds = 300)
gestureManager.config.swipeMinDistance = 50.0f32

# Handle gestures
gestureManager.onGesture = proc(gesture: GestureData) =
  case gesture.kind
  of gkTap:
    echo "Tap at: (", gesture.position.x, ", ", gesture.position.y, ")"

  of gkDoubleTap:
    echo "Double tap!"

  of gkLongPress:
    echo "Long press"

  of gkSwipe:
    echo "Swipe direction: ", gesture.direction
    echo "Velocity: ", gesture.velocity

  of gkPan:
    echo "Pan delta: ", gesture.delta
    if gesture.state == gsEnded:
      echo "Pan ended"

  of gkPinch:
    echo "Pinch scale: ", gesture.scale
    # gesture.scale > 1.0 = zoom in
    # gesture.scale < 1.0 = zoom out

  of gkRotate:
    echo "Rotate angle: ", gesture.rotation, " radians"

  else:
    discard
```

### Feeding Touch Events

```nim
# When touch starts
gestureManager.addTouch(touchId = 0, position = Point(x: 100, y: 200))

# When touch moves
gestureManager.updateTouch(touchId = 0, position = Point(x: 105, y: 205))

# When touch ends
gestureManager.checkEndGestures(touchId = 0)
gestureManager.removeTouch(touchId = 0)

# Every frame
gestureManager.recognizeGestures()
```

### Custom Configuration

```nim
var config = defaultGestureConfig()

# Tap settings
config.tapMaxDuration = initDuration(milliseconds = 250)
config.tapMaxMovement = 10.0f32

# Swipe settings
config.swipeMinDistance = 60.0f32
config.swipeMinVelocity = 150.0f32

# Long press settings
config.longPressMinDuration = initDuration(milliseconds = 600)

let gm = newGestureManager(config)
```

---

## Display Management

Handles screen dimensions, orientation, safe areas, and responsive layout.

### Basic Display Info

```nim
let displayManager = initDisplayManager(autoDetect = true)

echo "Screen size: ", displayManager.displayInfo.screenWidth, "x",
     displayManager.displayInfo.screenHeight
echo "Pixel density: ", displayManager.displayInfo.pixelDensity
echo "Orientation: ", displayManager.displayInfo.orientation
echo "Is tablet: ", displayManager.displayInfo.isTablet
```

### Orientation Handling

```nim
displayManager.onOrientationChange = proc(oldOr, newOr: Orientation) =
  echo "Orientation changed from ", oldOr, " to ", newOr

  # Rebuild layout for new orientation
  rebuildUI()

# Check orientation
if displayManager.isPortrait():
  echo "Portrait mode"
elif displayManager.isLandscape():
  echo "Landscape mode"

# Programmatically change orientation
displayManager.updateOrientation(orLandscape)
```

### Safe Area Support

Safe areas handle device-specific UI elements like notches, rounded corners, and navigation bars.

```nim
let safeArea = displayManager.displayInfo.safeArea

# Get usable dimensions
let usableWidth = displayManager.getUsableWidth(useSafeArea = true)
let usableHeight = displayManager.getUsableHeight(useSafeArea = true)

# Adjust rect for safe area
var rect = Rect(x: 0, y: 0, width: 400, height: 600)
rect = displayManager.adjustRectForSafeArea(rect)

# Now rect accounts for notches, etc.
```

### Responsive Breakpoints

```nim
# Get current screen size category
case displayManager.getScreenSize()
of ssCompact:
  # Phone portrait (< 600dp)
  echo "Use single column layout"

of ssMedium:
  # Phone landscape or small tablet (600-840dp)
  echo "Use two column layout"

of ssExpanded:
  # Tablet or desktop (>= 840dp)
  echo "Use multi-column layout"

# Convenience checks
if displayManager.isCompact():
  # Compact layout
  discard
```

### DPI Scaling

```nim
# Scale values for display density
let baseSize = 44.0f32  # Logical size
let physicalSize = displayManager.scaleForDensity(baseSize)

# Ensure minimum touch target size
let buttonSize = displayManager.adjustTouchTargetSize(30.0f32)
# Returns at least 44px (MinTouchTargetSize)
```

---

## Keyboard Handling

Manages virtual keyboard state and layout adjustments.

### Basic Usage

```nim
let keyboardManager = newKeyboardManager()

# Show keyboard
keyboardManager.showKeyboard(
  widget = myTextInput,
  keyboardType = ktEmailAddress,
  keyboardHeight = 300.0f32
)

# Hide keyboard
keyboardManager.hideKeyboard()

# Check state
if keyboardManager.isKeyboardVisible():
  echo "Keyboard is showing"
```

### Keyboard Types

```nim
# Show appropriate keyboard for input type
keyboardManager.showKeyboard(widget, ktNumberPad)     # Numbers only
keyboardManager.showKeyboard(widget, ktEmailAddress)  # Email-optimized
keyboardManager.showKeyboard(widget, ktURL)           # URL-optimized
keyboardManager.showKeyboard(widget, ktPhonePad)      # Phone numbers
keyboardManager.showKeyboard(widget, ktDecimalPad)    # Decimals
```

### Layout Adjustments

```nim
keyboardManager.onKeyboardShow = proc(info: KeyboardInfo) =
  echo "Keyboard height: ", info.height

  # Adjust layout to avoid obscuring input
  adjustLayoutForKeyboard(info.height)

keyboardManager.onKeyboardHide = proc() =
  # Restore original layout
  resetLayout()

keyboardManager.onLayoutAdjustNeeded = proc(keyboardHeight: float32) =
  # Reposition content to keep focused widget visible
  let focusedWidget = getFocusedWidget()
  if keyboardManager.shouldAdjustLayout(focusedWidget.bounds):
    let adjustedBounds = keyboardManager.calculateAdjustedBounds(
      originalBounds = screenBounds,
      focusedWidgetBounds = focusedWidget.bounds
    )
    # Apply adjusted bounds
```

### Animation Support

```nim
# Get current animated height
let currentHeight = keyboardManager.getCurrentHeight()

# Check if animating
if keyboardManager.isAnimating():
  # Keyboard is showing or hiding
  # Update every frame for smooth animation
  keyboardManager.update()
```

### Auto Focus Integration

```nim
# Integrate with focus manager
focusManager.onFocusGained = proc(widget: Widget) =
  if widget.isTextInput:
    keyboardManager.onWidgetFocused(widget, ktDefault)

focusManager.onFocusLost = proc(widget: Widget) =
  if widget.isTextInput:
    keyboardManager.onWidgetBlurred(widget)
```

---

## Mobile Widgets

### Touch Ripple

Material Design-style touch feedback.

```nim
let ripple = newTouchRipple()
ripple.rippleColor = Color(r: 0, g: 0, b: 0, a: 50)
ripple.rippleDuration = 0.6f32

# Add to button
button.addChild(ripple)

# Update every frame
ripple.updateRipples()

# Automatically handles touch events
```

### Pull to Refresh

iOS-style pull-to-refresh pattern.

```nim
let content = buildContentWidget()
let refreshView = newPullToRefresh(content)

refreshView.triggerDistance = 80.0f32
refreshView.onRefresh = proc() =
  # Load new data
  loadData()

  # Complete when done
  refreshView.completeRefresh()

# Integrate with gesture manager
gestureManager.onGesture = proc(gesture: GestureData) =
  if refreshView.handleGesture(gesture):
    return  # Consumed by refresh view

# Update every frame
refreshView.update()
```

### Momentum Scroll

iOS-style scrolling with inertia and bounce.

```nim
let content = buildScrollableContent()
let scrollView = newMomentumScroll(content)

# Configure
scrollView.bounceEnabled = true
scrollView.friction = 0.95f32
scrollView.maxVelocity = 5000.0f32

# Set content size
scrollView.contentSize = Size(width: 400, height: 2000)
scrollView.viewportSize = Size(width: 400, height: 600)
scrollView.updateScrollBounds()

# Handle scroll events
scrollView.onScroll = proc(offset: Point) =
  echo "Scrolled to: ", offset

scrollView.onScrollStart = proc() =
  echo "Scroll started"

scrollView.onScrollEnd = proc() =
  echo "Scroll ended"

# Integrate with gestures
gestureManager.onGesture = proc(gesture: GestureData) =
  if scrollView.handleGesture(gesture):
    return

# Update physics every frame
let deltaTime = 1.0 / 60.0  # 60 FPS
scrollView.update(deltaTime)

# Programmatic scrolling
scrollView.scrollTo(Point(x: 0, y: 500), animated = true)
scrollView.scrollBy(Point(x: 0, y: 100), animated = true)
```

---

## Responsive Design

### Breakpoint-Based Layouts

```nim
proc buildResponsiveLayout(display: DisplayManager): Widget =
  case display.getScreenSize()
  of ssCompact:
    # Phone portrait: single column
    buildUI:
      VStack:
        spacing: 16
        children:
          - ProfileHeader
          - ContentList
          - ActionButtons

  of ssMedium:
    # Phone landscape/small tablet: two columns
    buildUI:
      HStack:
        children:
          - VStack:
              children:
                - ProfileHeader
                - ActionButtons
          - ContentList

  of ssExpanded:
    # Tablet/desktop: multi-column
    buildUI:
      HStack:
        children:
          - Sidebar
          - VStack:
              children:
                - ProfileHeader
                - ContentList
          - ActionPanel
```

### Adaptive Grid

```nim
proc buildAdaptiveGrid(display: DisplayManager): Widget =
  let columns = display.getGridColumns()  # 1, 2, or 4 based on screen size

  buildUI:
    Grid:
      columns: columns
      spacing: 16
      children:
        - Item1
        - Item2
        - Item3
        - Item4
```

### Font Scaling

```nim
proc getScaledFontSize(display: DisplayManager, baseSize: float32): float32 =
  baseSize * display.getFontScale()

let headerSize = getScaledFontSize(display, 24.0)
let bodySize = getScaledFontSize(display, 16.0)
```

---

## Best Practices

### 1. Touch Target Sizing

Always ensure interactive elements meet minimum touch target sizes:

```nim
# Minimum 44x44 points (iOS HIG) or 48x48 dp (Material Design)
button.bounds.width = max(button.bounds.width, MinTouchTargetSize)
button.bounds.height = max(button.bounds.height, MinTouchTargetSize)

# Or use display manager
button.bounds.width = display.adjustTouchTargetSize(button.bounds.width)
```

### 2. Gesture Conflicts

Handle gesture conflicts explicitly:

```nim
# Prioritize specific gestures
gestureManager.onGesture = proc(gesture: GestureData) =
  # Check if widget-specific gesture handlers consume it first
  if widget.handleGesture(gesture):
    return  # Consumed, don't process further

  # Otherwise handle globally
  case gesture.kind
  of gkTap:
    handleGlobalTap(gesture)
  else:
    discard
```

### 3. Safe Area Awareness

Always account for safe areas in layout:

```nim
buildUI:
  VStack:
    padding: display.displayInfo.safeArea.toEdgeInsets()
    children:
      - Header
      - Content
      - Footer
```

### 4. Orientation Support

Test both orientations:

```nim
display.supportedOrientations = {orPortrait, orLandscape}

display.onOrientationChange = proc(old, new: Orientation) =
  # Rebuild UI for new orientation
  app.rebuildUI()
```

### 5. Keyboard Handling

Always adjust layout when keyboard appears:

```nim
keyboard.onLayoutAdjustNeeded = proc(height: float32) =
  if height > 0:
    # Keyboard showing - adjust layout
    contentPadding.bottom = height
  else:
    # Keyboard hidden - restore
    contentPadding.bottom = 0
```

### 6. Performance

Optimize for mobile:

```nim
# Reduce texture memory
app.textureCache.maxSize = 50  # Lower on mobile

# Use aggressive culling
if not widget.bounds.intersects(viewport):
  continue  # Don't render off-screen widgets

# Reduce frame rate when idle
if app.isIdle:
  app.targetFPS = 30
else:
  app.targetFPS = 60
```

### 7. Platform Detection

Adapt to platform capabilities:

```nim
let platform = detectPlatform()
let capabilities = getPlatformCapabilities(platform)

if capabilities.hasTouch:
  enableGestureRecognition()
else:
  enableMouseNavigation()

if capabilities.supportsHaptics:
  enableHapticFeedback()
```

---

## Complete Example

```nim
import rui
import mobile

type
  MyStore = ref object of Store
    items: Link[seq[string]]

proc main() =
  # Initialize mobile support
  let mobile = initMobileSupport()

  # Configure gestures
  mobile.gesture.onGesture = proc(gesture: GestureData) =
    case gesture.kind
    of gkSwipe:
      if gesture.direction == sdLeft:
        navigateForward()
      elif gesture.direction == sdRight:
        navigateBack()
    else:
      discard

  # Configure display
  mobile.display.onOrientationChange = proc(old, new: Orientation) =
    rebuildLayout(new)

  # Create app
  let app = newApp()
  let store = MyStore(items: newLink(@["Item 1", "Item 2", "Item 3"]))

  # Build UI with mobile support
  app.tree = buildUI:
    VStack:
      padding: mobile.display.displayInfo.safeArea.toEdgeInsets()
      children:
        - PullToRefresh:
            onRefresh: proc() =
              store.items.value = loadNewItems()
            child:
              MomentumScroll:
                contentSize: Size(width: 400, height: 2000)
                child:
                  ListView:
                    items: bind <- store.items

  # Main loop
  while not windowShouldClose():
    # Update mobile managers
    mobile.gesture.recognizeGestures()
    mobile.keyboard.update()

    # Update app
    app.update()
    app.render()

main()
```

---

For more examples, see the `examples/mobile/` directory.
