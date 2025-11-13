## Display and Orientation Manager
##
## Manages display information, orientation changes, safe areas,
## and responsive layout calculations for mobile devices.

import ../types
import ../../core/types
import std/[options, math]

# ============================================================================
# Display Manager
# ============================================================================

type
  DisplayManager* = ref object
    displayInfo*: DisplayInfo
    previousOrientation: Orientation
    layoutMode*: LayoutMode
    supportedOrientations*: set[Orientation]

    # Callbacks
    onOrientationChange*: proc(oldOrientation, newOrientation: Orientation)
    onSafeAreaChange*: proc(safeArea: SafeAreaInsets)
    onDisplayInfoChange*: proc(displayInfo: DisplayInfo)

# ============================================================================
# Initialization
# ============================================================================

proc newDisplayManager*(
  layoutMode: LayoutMode = lmResponsive,
  supportedOrientations: set[Orientation] = {orPortrait, orLandscape}
): DisplayManager =
  ## Create a new display manager
  let displayInfo = defaultDisplayInfo()
  result = DisplayManager(
    displayInfo: displayInfo,
    previousOrientation: displayInfo.orientation,
    layoutMode: layoutMode,
    supportedOrientations: supportedOrientations
  )

# ============================================================================
# Display Info Updates
# ============================================================================

proc updateDisplayInfo*(dm: DisplayManager, newInfo: DisplayInfo) =
  ## Update display information and trigger callbacks
  let oldInfo = dm.displayInfo
  dm.displayInfo = newInfo

  # Check for orientation change
  if newInfo.orientation != dm.previousOrientation:
    if dm.onOrientationChange != nil:
      dm.onOrientationChange(dm.previousOrientation, newInfo.orientation)
    dm.previousOrientation = newInfo.orientation

  # Check for safe area change
  if newInfo.safeArea != oldInfo.safeArea:
    if dm.onSafeAreaChange != nil:
      dm.onSafeAreaChange(newInfo.safeArea)

  # Notify of general display change
  if dm.onDisplayInfoChange != nil:
    dm.onDisplayInfoChange(newInfo)

proc updateOrientation*(dm: DisplayManager, orientation: Orientation) =
  ## Update just the orientation
  if orientation in dm.supportedOrientations or orientation == orAuto:
    var newInfo = dm.displayInfo
    newInfo.orientation = orientation

    # Swap width/height for landscape/portrait
    if (orientation in {orLandscape, orLandscapeRight} and
        dm.displayInfo.orientation in {orPortrait, orPortraitUpsideDown}) or
       (orientation in {orPortrait, orPortraitUpsideDown} and
        dm.displayInfo.orientation in {orLandscape, orLandscapeRight}):
      swap(newInfo.screenWidth, newInfo.screenHeight)

    dm.updateDisplayInfo(newInfo)

proc updateSafeArea*(dm: DisplayManager, safeArea: SafeAreaInsets) =
  ## Update safe area insets
  var newInfo = dm.displayInfo
  newInfo.safeArea = safeArea
  dm.updateDisplayInfo(newInfo)

# ============================================================================
# Screen Size Calculations
# ============================================================================

proc getScreenSize*(dm: DisplayManager): ScreenSize =
  ## Get current screen size category
  let width = dm.displayInfo.screenWidth
  getScreenSize(width)

proc isCompact*(dm: DisplayManager): bool =
  ## Check if screen is compact size
  dm.getScreenSize() == ssCompact

proc isMedium*(dm: DisplayManager): bool =
  ## Check if screen is medium size
  dm.getScreenSize() == ssMedium

proc isExpanded*(dm: DisplayManager): bool =
  ## Check if screen is expanded size
  dm.getScreenSize() == ssExpanded

proc isPortrait*(dm: DisplayManager): bool =
  ## Check if orientation is portrait
  dm.displayInfo.orientation in {orPortrait, orPortraitUpsideDown}

proc isLandscape*(dm: DisplayManager): bool =
  ## Check if orientation is landscape
  dm.displayInfo.orientation in {orLandscape, orLandscapeRight}

# ============================================================================
# Safe Area Helpers
# ============================================================================

proc getUsableWidth*(dm: DisplayManager, useSafeArea: bool = true): float32 =
  ## Get usable screen width (accounting for safe area)
  result = dm.displayInfo.screenWidth
  if useSafeArea:
    result -= (dm.displayInfo.safeArea.left + dm.displayInfo.safeArea.right)

proc getUsableHeight*(dm: DisplayManager, useSafeArea: bool = true): float32 =
  ## Get usable screen height (accounting for safe area)
  result = dm.displayInfo.screenHeight
  if useSafeArea:
    result -= (dm.displayInfo.safeArea.top + dm.displayInfo.safeArea.bottom)

proc adjustRectForSafeArea*(dm: DisplayManager, rect: Rect): Rect =
  ## Adjust a rect to account for safe area insets
  result = rect
  result.x += dm.displayInfo.safeArea.left
  result.y += dm.displayInfo.safeArea.top
  result.width -= (dm.displayInfo.safeArea.left + dm.displayInfo.safeArea.right)
  result.height -= (dm.displayInfo.safeArea.top + dm.displayInfo.safeArea.bottom)

proc adjustConstraintsForSafeArea*(dm: DisplayManager, constraints: Constraints): Constraints =
  ## Adjust constraints to account for safe area
  result = constraints
  let safeWidth = dm.displayInfo.safeArea.left + dm.displayInfo.safeArea.right
  let safeHeight = dm.displayInfo.safeArea.top + dm.displayInfo.safeArea.bottom

  result.maxWidth = max(0, constraints.maxWidth - safeWidth)
  result.maxHeight = max(0, constraints.maxHeight - safeHeight)

# ============================================================================
# Responsive Helpers
# ============================================================================

proc scaleForDensity*(dm: DisplayManager, value: float32): float32 =
  ## Scale a value based on pixel density
  value * dm.displayInfo.pixelDensity

proc unscaleForDensity*(dm: DisplayManager, value: float32): float32 =
  ## Unscale a value based on pixel density
  if dm.displayInfo.pixelDensity > 0:
    value / dm.displayInfo.pixelDensity
  else:
    value

proc getGridColumns*(dm: DisplayManager): int =
  ## Get recommended number of grid columns for current screen size
  case dm.getScreenSize()
  of ssCompact: 1
  of ssMedium: 2
  of ssExpanded: 4

proc getFontScale*(dm: DisplayManager): float32 =
  ## Get font scaling factor for current display
  dm.displayInfo.pixelDensity

proc adjustTouchTargetSize*(dm: DisplayManager, size: float32): float32 =
  ## Ensure touch target meets minimum size requirements
  let scaledMin = dm.scaleForDensity(MinTouchTargetSize)
  max(size, scaledMin)

# ============================================================================
# Platform Detection
# ============================================================================

proc detectPlatform*(): Platform =
  ## Detect current platform
  # This is a placeholder - in real implementation would use:
  # - Compile-time flags (when defined(ios), when defined(android))
  # - Runtime detection APIs
  when defined(ios):
    pfMobileIOS
  elif defined(android):
    pfMobileAndroid
  elif defined(emscripten):
    pfWeb
  else:
    pfDesktop

proc getPlatformCapabilities*(platform: Platform): PlatformCapabilities =
  ## Get capabilities for a platform
  case platform
  of pfDesktop:
    PlatformCapabilities(
      hasPhysicalKeyboard: true,
      hasTouch: false,
      hasMouse: true,
      supportsHaptics: false,
      supportsFileSystem: true,
      supportsClipboard: true,
      supportsNotifications: true
    )
  of pfMobileIOS, pfMobileAndroid:
    PlatformCapabilities(
      hasPhysicalKeyboard: false,
      hasTouch: true,
      hasMouse: false,
      supportsHaptics: true,
      supportsFileSystem: true,
      supportsClipboard: true,
      supportsNotifications: true
    )
  of pfWeb:
    PlatformCapabilities(
      hasPhysicalKeyboard: true,
      hasTouch: false,  # Can vary
      hasMouse: true,
      supportsHaptics: false,
      supportsFileSystem: false,
      supportsClipboard: true,
      supportsNotifications: false
    )

# ============================================================================
# Display Info Detection (Placeholder)
# ============================================================================

proc detectDisplayInfo*(): DisplayInfo =
  ## Detect display information from system
  ## This is a placeholder - in real implementation would query:
  ## - Screen dimensions
  ## - DPI/density
  ## - Safe area insets (iOS notch, Android navigation bars)
  ## - Device type (phone/tablet)

  # For now, return defaults based on platform
  let platform = detectPlatform()

  if platform.isMobilePlatform:
    # Mobile defaults
    DisplayInfo(
      orientation: orPortrait,
      safeArea: SafeAreaInsets(top: 44, bottom: 34, left: 0, right: 0),  # iPhone X-style
      pixelDensity: 2.0f32,  # Retina
      screenWidth: 390.0f32,  # iPhone 12/13/14 logical width
      screenHeight: 844.0f32,
      isTablet: false,
      hasSoftwareKeyboard: true,
      supportsHaptics: true
    )
  else:
    # Desktop defaults
    defaultDisplayInfo()

proc initDisplayManager*(
  autoDetect: bool = true,
  layoutMode: LayoutMode = lmResponsive
): DisplayManager =
  ## Initialize display manager with detection
  result = newDisplayManager(layoutMode)

  if autoDetect:
    result.displayInfo = detectDisplayInfo()
