## Mobile Support Module for RUI
##
## Complete mobile support including:
## - Gesture recognition (tap, swipe, pinch, rotate, long press)
## - Display management (orientation, safe areas, responsive layout)
## - Virtual keyboard handling
## - Mobile-optimized widgets (touch ripple, pull-to-refresh, momentum scroll)
##
## Usage:
##   import mobile
##
##   # Create managers
##   let gestureManager = newGestureManager()
##   let displayManager = initDisplayManager()
##   let keyboardManager = newKeyboardManager()
##
##   # Use mobile widgets
##   let scrollView = newMomentumScroll(contentWidget)
##   let refreshView = newPullToRefresh(listWidget)
##
## For detailed examples, see: mobile/MOBILE_GUIDE.md

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
# Convenience Procedures
# ============================================================================

proc initMobileSupport*(autoDetect: bool = true): tuple[
  gesture: GestureManager,
  display: DisplayManager,
  keyboard: KeyboardManager
] =
  ## Initialize all mobile managers at once
  ##
  ## Example:
  ##   let mobile = initMobileSupport()
  ##   mobile.gesture.onGesture = proc(g: GestureData) = echo "Gesture: ", g.kind
  ##
  result.gesture = newGestureManager()
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

  # Initialize mobile support
  let mobile = initMobileSupport()

  # Configure gesture manager
  mobile.gesture.onGesture = proc(gesture: GestureData) =
    case gesture.kind
    of gkTap:
      echo "Tap at: ", gesture.position
    of gkSwipe:
      echo "Swipe ", gesture.direction
    of gkPinch:
      echo "Pinch scale: ", gesture.scale
    else:
      echo "Gesture: ", gesture.kind

  # Configure display manager
  mobile.display.onOrientationChange = proc(oldOr, newOr: Orientation) =
    echo "Orientation changed: ", oldOr, " -> ", newOr

  # Configure keyboard manager
  mobile.keyboard.onKeyboardShow = proc(info: KeyboardInfo) =
    echo "Keyboard shown, height: ", info.height

  # Create a mobile-optimized scroll view
  # let content = ... your content widget ...
  # let scrollView = newMomentumScroll(content)
  # scrollView.bounceEnabled = true

  # Create pull-to-refresh
  # let refreshView = newPullToRefresh(scrollView)
  # refreshView.onRefresh = proc() =
  #   echo "Refreshing..."
  #   # Load new data
  #   refreshView.completeRefresh()

  echo "Mobile support initialized!"
  echo "Platform: ", detectPlatform()
  echo "Is mobile: ", detectMobilePlatform()
  echo "Screen size: ", mobile.display.getScreenSize()
