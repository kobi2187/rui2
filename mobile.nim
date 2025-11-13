## Mobile Support Module for RUI
##
## Complete mobile support including:
## - Touch input provider (bridges raylib touch events)
## - Gesture recognition (tap, swipe, pinch, rotate, long press)
## - Display management (orientation, safe areas, responsive layout)
## - Virtual keyboard handling
## - Mobile-optimized widgets (touch ripple, pull-to-refresh, momentum scroll)
## - Responsive sizing utilities (DPI-aware, adaptive sizes, touch targets)
##
## Usage:
##   import mobile
##
##   # Complete setup with input provider
##   let mobile = initMobileSupport()
##
##   # Use responsive sizing
##   let fontSize = mobile.display.fontSize(fsBody)
##   let spacing = mobile.display.sp(SpacingSizes.medium)
##   let buttonHeight = mobile.display.ensureTouchTarget(40.0)
##
##   # In your main loop:
##   mobile.input.update()  # Poll touch events and recognize gestures
##
## For detailed examples, see:
##   - mobile/MOBILE_GUIDE.md - Complete mobile guide
##   - mobile/RESPONSIVE_DESIGN.md - Responsive sizing guide

# ============================================================================
# Core Types
# ============================================================================

import mobile/types
export types

# Re-export commonly used types for convenience
export GestureKind, GestureState, GestureData, SwipeDirection
export Orientation, DisplayInfo, SafeAreaInsets, ScreenSize, LayoutMode
export KeyboardState, KeyboardType, KeyboardInfo
export Platform, PlatformCapabilities
export TouchFeedbackType, ScrollBehavior, MobileWidgetProps

# Export constants
export MinTouchTargetSize, RecommendedTouchTargetSize, MinTouchTargetSpacing
export CompactMaxWidth, MediumMaxWidth

# ============================================================================
# Input Provider
# ============================================================================

import mobile/input_provider
export input_provider

# Re-export input provider types
export RaylibInputProvider, newRaylibInputProvider, createInputProvider

# ============================================================================
# Managers
# ============================================================================

import mobile/managers/gesture_manager
import mobile/managers/display_manager
import mobile/managers/keyboard_manager

export gesture_manager
export display_manager
export keyboard_manager

# Re-export main manager types
export GestureManager, newGestureManager
export DisplayManager, newDisplayManager, initDisplayManager
export KeyboardManager, newKeyboardManager

# ============================================================================
# Widgets
# ============================================================================

import mobile/widgets/touch_ripple
import mobile/widgets/pull_to_refresh
import mobile/widgets/momentum_scroll

export touch_ripple
export pull_to_refresh
export momentum_scroll

# Re-export widget types
export TouchRipple, newTouchRipple
export PullToRefresh, newPullToRefresh, RefreshState
export MomentumScroll, newMomentumScroll, ScrollPhase

# ============================================================================
# Responsive Sizing
# ============================================================================

import mobile/responsive
export responsive

# Re-export responsive sizing types and constants
export TextScale, ResponsiveSize, ResponsiveSizes
export DefaultTextScale, MobileFirstTextScale
export SpacingSizes, FontSizes, IconSizes, ButtonHeights
export FontSizePreset, ContentWidth, LayoutDensity

# Re-export responsive functions
export getValue, scaledSize, unscaledSize
export ensureTouchTarget, touchTargetPadding
export getTextScaleFactor, getResponsiveFontSize
export getAspectRatio, isWideScreen, isTallScreen
export getMaxContentWidth, getConstrainedWidth
export getSpacingMultiplier, getRecommendedDensity, adaptSpacing
export sp, dp, fontSize
export printResponsiveInfo

# ============================================================================
# Convenience Procedures
# ============================================================================

proc initMobileSupport*(autoDetect: bool = true, mouseSimulation: bool = true): tuple[
  input: RaylibInputProvider,
  gesture: GestureManager,
  display: DisplayManager,
  keyboard: KeyboardManager
] =
  ## Initialize all mobile managers and input provider at once
  ##
  ## autoDetect: Auto-detect display info from platform
  ## mouseSimulation: Use mouse as touch input on desktop (for testing)
  ##
  ## Example:
  ##   let mobile = initMobileSupport()
  ##
  ##   # Configure callbacks
  ##   mobile.gesture.onGesture = proc(g: GestureData) =
  ##     echo "Gesture: ", g.kind
  ##
  ##   # In your main loop:
  ##   mobile.input.update()  # Polls touch/mouse and recognizes gestures
  ##
  result.gesture = newGestureManager()
  result.input = createInputProvider(result.gesture, mouseSimulation)
  result.display = initDisplayManager(autoDetect = autoDetect)
  result.keyboard = newKeyboardManager()

proc detectMobilePlatform*(): bool =
  ## Quick check if running on mobile platform
  let platform = detectPlatform()
  result = platform.isMobilePlatform()

# ============================================================================
# Integration Helpers
# ============================================================================

proc setupMobileGestures*(gestureManager: GestureManager) =
  ## Configure gesture manager with mobile-optimized settings
  gestureManager.config = defaultGestureConfig()

proc setupMobileDisplay*(displayManager: DisplayManager,
                        supportedOrientations: set[Orientation] = {orPortrait, orLandscape}) =
  ## Configure display manager for mobile
  displayManager.supportedOrientations = supportedOrientations
  displayManager.layoutMode = lmResponsive

# ============================================================================
# Example: Complete Mobile App Setup
# ============================================================================

when isMainModule:
  # This example shows how to set up mobile support in your app

  import core/types

  # ========================================
  # 1. Initialize mobile support
  # ========================================

  let mobile = initMobileSupport()

  # ========================================
  # 2. Configure gesture callbacks
  # ========================================

  mobile.gesture.onGesture = proc(gesture: GestureData) =
    case gesture.kind
    of gkTap:
      echo "✓ Tap at: (", gesture.position.x, ", ", gesture.position.y, ")"
    of gkDoubleTap:
      echo "✓ Double tap!"
    of gkLongPress:
      echo "✓ Long press"
    of gkSwipe:
      echo "✓ Swipe ", gesture.direction, " velocity: ", gesture.velocity
    of gkPan:
      echo "✓ Pan delta: ", gesture.delta, " state: ", gesture.state
    of gkPinch:
      echo "✓ Pinch scale: ", gesture.scale
    of gkRotate:
      echo "✓ Rotate angle: ", gesture.rotation, " radians"
    else:
      echo "✓ Gesture: ", gesture.kind

  # ========================================
  # 3. Configure display & keyboard
  # ========================================

  mobile.display.onOrientationChange = proc(oldOr, newOr: Orientation) =
    echo "↻ Orientation: ", oldOr, " → ", newOr

  mobile.keyboard.onKeyboardShow = proc(info: KeyboardInfo) =
    echo "⌨ Keyboard shown, height: ", info.height

  # ========================================
  # 4. Responsive sizing examples
  # ========================================

  echo ""
  echo "Responsive Sizing Examples"
  echo "=========================="

  # Font sizes (DPI-aware, adaptive)
  let bodyFont = mobile.display.fontSize(fsBody)
  let headingFont = mobile.display.fontSize(fsHeading)
  let titleFont = mobile.display.fontSize(fsTitle)
  echo "Body font: ", bodyFont, "px"
  echo "Heading font: ", headingFont, "px"

  # Spacing (responsive to screen size)
  let smallSpacing = mobile.display.sp(SpacingSizes.small)
  let mediumSpacing = mobile.display.sp(SpacingSizes.medium)
  let largeSpacing = mobile.display.sp(SpacingSizes.large)
  echo "Small spacing: ", smallSpacing, "px"
  echo "Medium spacing: ", mediumSpacing, "px"

  # Touch targets (automatically enforced minimum)
  let buttonHeight = mobile.display.ensureTouchTarget(36.0)
  let iconSize = mobile.display.sp(IconSizes.medium)
  let iconPadding = mobile.display.touchTargetPadding(iconSize)
  echo "Button height (enforced): ", buttonHeight, "px (min 44dp)"
  echo "Icon with padding: ", iconSize, "px + ", iconPadding, "px padding"

  # Content width (constrained for readability)
  let contentWidth = mobile.display.getConstrainedWidth(cwNarrow)
  echo "Max content width: ", contentWidth, "px (for readability)"

  # ========================================
  # 5. Create mobile widgets (examples)
  # ========================================

  # let content = buildYourContent()
  # let scrollView = newMomentumScroll(content)
  # scrollView.bounceEnabled = true
  #
  # let refreshView = newPullToRefresh(scrollView)
  # refreshView.onRefresh = proc() =
  #   echo "Refreshing..."
  #   loadNewData()
  #   refreshView.completeRefresh()

  # Example responsive widget:
  # Button:
  #   text: "Click Me"
  #   height: mobile.display.ensureTouchTarget(
  #     mobile.display.sp(ButtonHeights.medium)
  #   )
  #   fontSize: mobile.display.fontSize(fsBody)
  #   padding: mobile.display.sp(SpacingSizes.medium)

  # ========================================
  # 6. Main Loop (pseudo-code)
  # ========================================

  echo ""
  echo "Mobile support initialized!"
  echo "==========================="
  echo "Platform: ", detectPlatform()
  echo "Is mobile: ", detectMobilePlatform()
  echo "Screen size: ", mobile.display.getScreenSize()
  echo "Mouse simulation: ", mobile.input.mouseSimulation
  echo ""
  echo "Main loop structure:"
  echo "-------------------"
  echo "while not windowShouldClose():"
  echo "  # 1. Poll touch/mouse input and recognize gestures"
  echo "  mobile.input.update()"
  echo ""
  echo "  # 2. Update keyboard animations"
  echo "  mobile.keyboard.update()"
  echo ""
  echo "  # 3. Update mobile widgets"
  echo "  # scrollView.update(deltaTime)"
  echo "  # refreshView.update()"
  echo ""
  echo "  # 4. Regular app update & render"
  echo "  # app.update()"
  echo "  # app.render()"
  echo ""
  echo "✓ Ready for mobile input!"
  echo "  - Try clicking/dragging (simulates touch on desktop)"
  echo "  - Gestures will be recognized and printed above"
