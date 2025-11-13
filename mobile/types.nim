## Mobile Support Types
##
## Type definitions for mobile-specific functionality including gestures,
## display info, orientation, and touch interactions.

import ../core/types
export types  # Re-export core types

# ============================================================================
# Gesture System Types
# ============================================================================

type
  GestureKind* = enum
    gkTap           # Single tap
    gkDoubleTap     # Double tap
    gkLongPress     # Press and hold
    gkSwipe         # Quick directional movement
    gkPan           # Drag gesture
    gkPinch         # Two-finger zoom
    gkRotate        # Two-finger rotation
    gkTwoFingerTap  # Two-finger tap
    gkEdgeSwipe     # Swipe from screen edge

  SwipeDirection* = enum
    sdUp
    sdDown
    sdLeft
    sdRight

  GestureState* = enum
    gsBegan       # Gesture started
    gsChanged     # Gesture in progress
    gsEnded       # Gesture completed
    gsCancelled   # Gesture cancelled

  TouchPoint* = object
    id*: int              # Unique touch identifier
    position*: Point
    previousPosition*: Point
    startPosition*: Point # Where touch began
    timestamp*: MonoTime

  GestureData* = object
    kind*: GestureKind
    state*: GestureState
    position*: Point          # Primary touch point
    delta*: Point             # Movement since last update
    velocity*: Point          # Velocity of movement (pixels/second)
    scale*: float32           # For pinch gestures (1.0 = no change)
    rotation*: float32        # For rotate gestures (radians)
    numberOfTouches*: int
    direction*: SwipeDirection # For swipe gestures
    touchPoints*: seq[TouchPoint]
    timestamp*: MonoTime

  GestureRecognizerConfig* = object
    # Tap configuration
    tapMaxDuration*: Duration         # Max time for tap (default: 300ms)
    tapMaxMovement*: float32          # Max movement for tap (default: 10px)
    doubleTapMaxInterval*: Duration   # Max time between taps (default: 400ms)

    # Long press configuration
    longPressMinDuration*: Duration   # Min hold time (default: 500ms)
    longPressMaxMovement*: float32    # Max movement allowed (default: 10px)

    # Swipe configuration
    swipeMinDistance*: float32        # Min distance to recognize (default: 50px)
    swipeMinVelocity*: float32        # Min velocity pixels/sec (default: 100)
    swipeMaxDeviation*: float32       # Max perpendicular deviation (default: 45°)

    # Pan configuration
    panMinDistance*: float32          # Min distance to start (default: 10px)

    # Pinch configuration
    pinchMinScaleChange*: float32     # Min scale change (default: 0.01)

    # Rotate configuration
    rotateMinAngleChange*: float32    # Min rotation in radians (default: 0.01)

    # Edge swipe configuration
    edgeSwipeMaxStartDistance*: float32  # Max distance from edge (default: 20px)

# ============================================================================
# Display & Orientation Types
# ============================================================================

type
  Orientation* = enum
    orPortrait
    orLandscape
    orPortraitUpsideDown
    orLandscapeRight
    orAuto  # System decides

  SafeAreaInsets* = object
    ## Insets for device-specific UI elements (notches, rounded corners, etc.)
    top*, bottom*, left*, right*: float32

  DisplayInfo* = object
    orientation*: Orientation
    safeArea*: SafeAreaInsets
    pixelDensity*: float32        # DPI scaling factor (1.0 = baseline, 2.0 = retina)
    screenWidth*: float32
    screenHeight*: float32
    isTablet*: bool
    hasSoftwareKeyboard*: bool
    supportsHaptics*: bool

  LayoutMode* = enum
    lmFixed      # Desktop: fixed window size
    lmResponsive # Mobile: adapt to screen size
    lmAdaptive   # Hybrid: different layouts per size

  ScreenSize* = enum
    ## Responsive breakpoints (based on Material Design)
    ssCompact      # < 600dp (phone portrait)
    ssMedium       # 600-839dp (phone landscape, small tablet)
    ssExpanded     # >= 840dp (tablet, desktop)

# ============================================================================
# Virtual Keyboard Types
# ============================================================================

type
  KeyboardState* = enum
    ksHidden
    ksShowing
    ksVisible
    ksHiding

  KeyboardType* = enum
    ktDefault       # Standard keyboard
    ktNumberPad     # Numeric keypad
    ktPhonePad      # Phone number entry
    ktEmailAddress  # Email optimized
    ktURL           # URL optimized
    ktDecimalPad    # Decimal numbers

  KeyboardInfo* = object
    state*: KeyboardState
    height*: float32
    animationDuration*: float32  # Transition duration in seconds
    keyboardType*: KeyboardType

# ============================================================================
# Platform Detection Types
# ============================================================================

type
  Platform* = enum
    pfDesktop
    pfMobileIOS
    pfMobileAndroid
    pfWeb

  PlatformCapabilities* = object
    hasPhysicalKeyboard*: bool
    hasTouch*: bool
    hasMouse*: bool
    supportsHaptics*: bool
    supportsFileSystem*: bool
    supportsClipboard*: bool
    supportsNotifications*: bool

# ============================================================================
# Mobile Widget Configuration
# ============================================================================

type
  ScrollBehavior* = enum
    sbNormal      # Standard scrolling
    sbMomentum    # iOS-style momentum scrolling
    sbBounce      # Bounce at edges
    sbPaging      # Snap to pages

  TouchFeedbackType* = enum
    tfNone
    tfRipple      # Material Design ripple
    tfHighlight   # iOS-style highlight
    tfScale       # Slight scale animation
    tfHaptic      # Vibration feedback

  MobileWidgetProps* = object
    ## Additional properties for mobile-optimized widgets
    minTouchTargetSize*: float32       # Minimum touch target (default: 44px)
    touchFeedback*: TouchFeedbackType
    scrollBehavior*: ScrollBehavior
    enableHaptics*: bool

# ============================================================================
# Constants
# ============================================================================

const
  # Touch target sizes (iOS HIG / Material Design)
  MinTouchTargetSize* = 44.0f32      # Minimum comfortable touch target
  RecommendedTouchTargetSize* = 48.0f32
  MinTouchTargetSpacing* = 8.0f32

  # Screen size breakpoints (dp)
  CompactMaxWidth* = 600.0f32
  MediumMaxWidth* = 840.0f32

  # Default gesture configurations
  DefaultTapDuration* = 300          # milliseconds
  DefaultLongPressDuration* = 500    # milliseconds
  DefaultDoubleTapInterval* = 400    # milliseconds
  DefaultSwipeMinDistance* = 50.0f32 # pixels
  DefaultSwipeMinVelocity* = 100.0f32 # pixels/second

# ============================================================================
# Helper Functions
# ============================================================================

proc getScreenSize*(width: float32): ScreenSize =
  ## Determine screen size category from width
  if width < CompactMaxWidth:
    ssCompact
  elif width < MediumMaxWidth:
    ssMedium
  else:
    ssExpanded

proc isMobilePlatform*(platform: Platform): bool =
  ## Check if platform is mobile
  platform in {pfMobileIOS, pfMobileAndroid}

proc defaultGestureConfig*(): GestureRecognizerConfig =
  ## Create default gesture recognizer configuration
  GestureRecognizerConfig(
    tapMaxDuration: initDuration(milliseconds = DefaultTapDuration),
    tapMaxMovement: 10.0f32,
    doubleTapMaxInterval: initDuration(milliseconds = DefaultDoubleTapInterval),
    longPressMinDuration: initDuration(milliseconds = DefaultLongPressDuration),
    longPressMaxMovement: 10.0f32,
    swipeMinDistance: DefaultSwipeMinDistance,
    swipeMinVelocity: DefaultSwipeMinVelocity,
    swipeMaxDeviation: 45.0f32,
    panMinDistance: 10.0f32,
    pinchMinScaleChange: 0.01f32,
    rotateMinAngleChange: 0.01f32,
    edgeSwipeMaxStartDistance: 20.0f32
  )

proc defaultSafeArea*(): SafeAreaInsets =
  ## Create default safe area (no insets)
  SafeAreaInsets(top: 0, bottom: 0, left: 0, right: 0)

proc defaultDisplayInfo*(): DisplayInfo =
  ## Create default display info for desktop
  DisplayInfo(
    orientation: orLandscape,
    safeArea: defaultSafeArea(),
    pixelDensity: 1.0f32,
    screenWidth: 1920.0f32,
    screenHeight: 1080.0f32,
    isTablet: false,
    hasSoftwareKeyboard: false,
    supportsHaptics: false
  )

proc isSafeArea*(insets: SafeAreaInsets): bool =
  ## Check if there are any safe area insets
  insets.top > 0 or insets.bottom > 0 or insets.left > 0 or insets.right > 0
