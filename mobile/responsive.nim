## Responsive Sizing Utilities
##
## Provides utilities for adaptive sizing across different screen sizes,
## densities, and orientations. Ensures widgets remain readable and usable
## on all devices.

import types
import managers/display_manager
import ../core/types
import std/[math, tables]

# ============================================================================
# Text Scale Factors
# ============================================================================

type
  TextScale* = object
    ## Text scaling configuration for different screen sizes
    compact*: float32      # Phone portrait (< 600dp)
    medium*: float32       # Phone landscape / small tablet (600-840dp)
    expanded*: float32     # Tablet / desktop (>= 840dp)

const
  DefaultTextScale* = TextScale(
    compact: 1.0,         # Base size on mobile
    medium: 1.1,          # 10% larger on medium screens
    expanded: 1.0         # Desktop uses base sizes
  )

  # Aggressive scaling for better mobile readability
  MobileFirstTextScale* = TextScale(
    compact: 1.0,         # Base
    medium: 0.95,         # Slightly smaller on landscape
    expanded: 0.9         # Smaller on desktop (more content fits)
  )

proc getTextScaleFactor*(display: DisplayManager, scale: TextScale = DefaultTextScale): float32 =
  ## Get text scale factor for current screen size
  case display.getScreenSize()
  of ssCompact: scale.compact
  of ssMedium: scale.medium
  of ssExpanded: scale.expanded

# ============================================================================
# Responsive Sizing
# ============================================================================

type
  ResponsiveSize* = object
    ## Size that adapts to screen size category
    compact*: float32      # Phone portrait
    medium*: float32       # Phone landscape / small tablet
    expanded*: float32     # Tablet / desktop

  ResponsiveSizes* = object
    ## Common responsive size presets
    tiny*, small*, medium*, large*, xlarge*: ResponsiveSize

# Predefined size scales (in dp/logical pixels)
const
  # Spacing scale
  SpacingSizes* = ResponsiveSizes(
    tiny: ResponsiveSize(compact: 4, medium: 4, expanded: 4),
    small: ResponsiveSize(compact: 8, medium: 12, expanded: 16),
    medium: ResponsiveSize(compact: 16, medium: 20, expanded: 24),
    large: ResponsiveSize(compact: 24, medium: 32, expanded: 40),
    xlarge: ResponsiveSize(compact: 32, medium: 48, expanded: 64)
  )

  # Font sizes
  FontSizes* = ResponsiveSizes(
    tiny: ResponsiveSize(compact: 10, medium: 11, expanded: 10),
    small: ResponsiveSize(compact: 12, medium: 13, expanded: 12),
    medium: ResponsiveSize(compact: 14, medium: 15, expanded: 14),
    large: ResponsiveSize(compact: 18, medium: 20, expanded: 18),
    xlarge: ResponsiveSize(compact: 24, medium: 28, expanded: 24)
  )

  # Icon sizes
  IconSizes* = ResponsiveSizes(
    tiny: ResponsiveSize(compact: 16, medium: 18, expanded: 16),
    small: ResponsiveSize(compact: 20, medium: 22, expanded: 20),
    medium: ResponsiveSize(compact: 24, medium: 28, expanded: 24),
    large: ResponsiveSize(compact: 32, medium: 36, expanded: 32),
    xlarge: ResponsiveSize(compact: 48, medium: 56, expanded: 48)
  )

  # Button heights
  ButtonHeights* = ResponsiveSizes(
    tiny: ResponsiveSize(compact: 32, medium: 36, expanded: 28),
    small: ResponsiveSize(compact: 40, medium: 44, expanded: 32),
    medium: ResponsiveSize(compact: 48, medium: 52, expanded: 40),
    large: ResponsiveSize(compact: 56, medium: 60, expanded: 48),
    xlarge: ResponsiveSize(compact: 64, medium: 72, expanded: 56)
  )

proc getValue*(size: ResponsiveSize, display: DisplayManager): float32 =
  ## Get responsive value for current screen size
  case display.getScreenSize()
  of ssCompact: size.compact
  of ssMedium: size.medium
  of ssExpanded: size.expanded

proc getValue*(size: ResponsiveSize, screenSize: ScreenSize): float32 =
  ## Get responsive value for specific screen size
  case screenSize
  of ssCompact: size.compact
  of ssMedium: size.medium
  of ssExpanded: size.expanded

# ============================================================================
# DPI-Aware Sizing
# ============================================================================

proc scaledSize*(display: DisplayManager, logicalSize: float32): float32 =
  ## Convert logical size to physical pixels based on DPI
  display.scaleForDensity(logicalSize)

proc scaledSize*(display: DisplayManager, size: ResponsiveSize): float32 =
  ## Get responsive size scaled for DPI
  let logical = size.getValue(display)
  display.scaledSize(logical)

proc unscaledSize*(display: DisplayManager, physicalSize: float32): float32 =
  ## Convert physical pixels to logical size
  display.unscaleForDensity(physicalSize)

# ============================================================================
# Touch Target Sizing
# ============================================================================

proc ensureTouchTarget*(display: DisplayManager, size: float32): float32 =
  ## Ensure size meets minimum touch target (44dp iOS / 48dp Android)
  ## Returns physical pixels
  let minTarget = display.scaledSize(MinTouchTargetSize)
  max(size, minTarget)

proc ensureTouchTarget*(display: DisplayManager, width, height: float32): tuple[width, height: float32] =
  ## Ensure dimensions meet minimum touch target
  (
    width: display.ensureTouchTarget(width),
    height: display.ensureTouchTarget(height)
  )

proc touchTargetPadding*(display: DisplayManager, currentSize: float32): float32 =
  ## Calculate padding needed to meet touch target
  let minTarget = display.scaledSize(MinTouchTargetSize)
  if currentSize < minTarget:
    (minTarget - currentSize) / 2.0
  else:
    0.0

# ============================================================================
# Responsive Font Sizing
# ============================================================================

type
  FontSizePreset* = enum
    fsCaption       # Small secondary text
    fsBody          # Regular body text
    fsSubheading    # Section subheadings
    fsHeading       # Section headings
    fsTitle         # Page/screen titles
    fsDisplay       # Large display text

proc getBaseFontSize*(preset: FontSizePreset): float32 =
  ## Get base logical font size for preset
  case preset
  of fsCaption: 12.0
  of fsBody: 14.0
  of fsSubheading: 16.0
  of fsHeading: 20.0
  of fsTitle: 24.0
  of fsDisplay: 34.0

proc getResponsiveFontSize*(
  display: DisplayManager,
  preset: FontSizePreset,
  textScale: TextScale = DefaultTextScale
): float32 =
  ## Get DPI-scaled, screen-size-adjusted font size
  let baseSize = getBaseFontSize(preset)
  let scaleFactor = display.getTextScaleFactor(textScale)
  let logicalSize = baseSize * scaleFactor
  display.scaledSize(logicalSize)

proc getResponsiveFontSize*(
  display: DisplayManager,
  baseSize: float32,
  textScale: TextScale = DefaultTextScale
): float32 =
  ## Get DPI-scaled, screen-size-adjusted font size from custom base
  let scaleFactor = display.getTextScaleFactor(textScale)
  let logicalSize = baseSize * scaleFactor
  display.scaledSize(logicalSize)

# ============================================================================
# Aspect Ratio Utilities
# ============================================================================

proc getAspectRatio*(display: DisplayManager): float32 =
  ## Get screen aspect ratio (width / height)
  if display.displayInfo.screenHeight > 0:
    display.displayInfo.screenWidth / display.displayInfo.screenHeight
  else:
    1.0

proc isWideScreen*(display: DisplayManager): bool =
  ## Check if screen is wide (aspect > 16:9)
  display.getAspectRatio() > (16.0 / 9.0)

proc isTallScreen*(display: DisplayManager): bool =
  ## Check if screen is tall (aspect < 9:16, common on modern phones)
  display.getAspectRatio() < (9.0 / 16.0)

# ============================================================================
# Content Width Guidelines
# ============================================================================

type
  ContentWidth* = enum
    cwNarrow     # Optimal for reading text (600-700dp)
    cwMedium     # Standard content (700-900dp)
    cwWide       # Full width on large screens

proc getMaxContentWidth*(width: ContentWidth): float32 =
  ## Get maximum content width in dp
  case width
  of cwNarrow: 600.0
  of cwMedium: 900.0
  of cwWide: 1200.0

proc getConstrainedWidth*(
  display: DisplayManager,
  maxWidth: ContentWidth = cwMedium
): float32 =
  ## Get content width constrained for readability
  let available = display.getUsableWidth(useSafeArea = true)
  let maxDp = getMaxContentWidth(maxWidth)
  let maxPhysical = display.scaledSize(maxDp)
  min(available, maxPhysical)

# ============================================================================
# Adaptive Layout Helpers
# ============================================================================

type
  LayoutDensity* = enum
    ldCompact    # Minimal spacing, maximize content
    ldComfortable  # Balanced spacing
    ldSpacious   # Extra spacing, easier interaction

proc getSpacingMultiplier*(density: LayoutDensity): float32 =
  ## Get spacing multiplier for layout density
  case density
  of ldCompact: 0.75
  of ldComfortable: 1.0
  of ldSpacious: 1.5

proc getRecommendedDensity*(display: DisplayManager): LayoutDensity =
  ## Get recommended layout density for screen size
  case display.getScreenSize()
  of ssCompact: ldCompact       # Maximize space on small screens
  of ssMedium: ldComfortable    # Balanced on medium screens
  of ssExpanded: ldSpacious     # More breathing room on large screens

proc adaptSpacing*(
  display: DisplayManager,
  baseSpacing: float32,
  density: LayoutDensity
): float32 =
  ## Adapt spacing for screen size and density preference
  let multiplier = getSpacingMultiplier(density)
  let logicalSpacing = baseSpacing * multiplier
  display.scaledSize(logicalSpacing)

# ============================================================================
# Convenience Functions
# ============================================================================

proc sp*(display: DisplayManager, size: ResponsiveSize): float32 =
  ## Shorthand: Get scaled responsive spacing
  display.scaledSize(size)

proc sp*(display: DisplayManager, logicalSize: float32): float32 =
  ## Shorthand: Get scaled spacing from logical size
  display.scaledSize(logicalSize)

proc dp*(display: DisplayManager, logicalSize: float32): float32 =
  ## Shorthand: Density-independent pixels (same as sp)
  display.scaledSize(logicalSize)

proc fontSize*(
  display: DisplayManager,
  preset: FontSizePreset,
  scale: TextScale = DefaultTextScale
): float32 =
  ## Shorthand: Get responsive font size
  display.getResponsiveFontSize(preset, scale)

# ============================================================================
# Widget Size Helpers
# ============================================================================

type
  WidgetSizeHints* = object
    ## Size hints for responsive widgets
    minWidth*, minHeight*: float32
    preferredWidth*, preferredHeight*: float32
    maxWidth*, maxHeight*: float32

proc createSizeHints*(
  display: DisplayManager,
  minSize: ResponsiveSize,
  preferredSize: ResponsiveSize,
  maxSize: Option[ResponsiveSize] = none(ResponsiveSize)
): WidgetSizeHints =
  ## Create size hints from responsive sizes
  result.minWidth = display.scaledSize(minSize)
  result.minHeight = result.minWidth
  result.preferredWidth = display.scaledSize(preferredSize)
  result.preferredHeight = result.preferredWidth

  if maxSize.isSome:
    result.maxWidth = display.scaledSize(maxSize.get)
    result.maxHeight = result.maxWidth
  else:
    result.maxWidth = Inf
    result.maxHeight = Inf

# ============================================================================
# Debug / Info
# ============================================================================

proc printResponsiveInfo*(display: DisplayManager) =
  ## Print responsive sizing information for debugging
  echo "Responsive Sizing Info"
  echo "======================"
  echo "Screen size: ", display.getScreenSize()
  echo "DPI scale: ", display.displayInfo.pixelDensity, "x"
  echo "Orientation: ", display.displayInfo.orientation
  echo "Aspect ratio: ", display.getAspectRatio().formatFloat(ffDecimal, 2)
  echo ""
  echo "Text scale factor: ", display.getTextScaleFactor()
  echo "Recommended density: ", display.getRecommendedDensity()
  echo ""
  echo "Example sizes (logical → physical):"
  echo "  44dp touch target → ", display.scaledSize(44.0), "px"
  echo "  16dp spacing → ", display.scaledSize(16.0), "px"
  echo "  14pt body text → ", display.getResponsiveFontSize(fsBody), "px"
  echo "  24pt heading → ", display.getResponsiveFontSize(fsHeading), "px"
