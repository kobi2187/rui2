## Brand Helpers Module
##
## Utility functions for accessing and using brand features from themes.
## Makes it easy to extract brand colors, typography, spacing, and animations.
##
## Usage:
##   let primary = theme.getBrandPrimary(fallback = BLUE)
##   let titleFont = theme.getBrandHeadingFont(fallback = "Arial")
##   let mediumSpace = theme.getBrandSpacing(md, fallback = 16.0)

import std/options
import ../core/types
import theme_sys_core

## ============================================================================
## Brand Color Extraction
## ============================================================================

proc getBrandPrimary*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand primary color, with fallback if not defined
  if theme.brandPalette.primaryColor.isSome:
    return theme.brandPalette.primaryColor.get()
  return fallback

proc getBrandSecondary*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand secondary color, with fallback if not defined
  if theme.brandPalette.secondaryColor.isSome:
    return theme.brandPalette.secondaryColor.get()
  return fallback

proc getBrandAccent*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand accent color, with fallback if not defined
  if theme.brandPalette.accentColor.isSome:
    return theme.brandPalette.accentColor.get()
  return fallback

proc getBrandNeutralLight*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand neutral light color (backgrounds), with fallback
  if theme.brandPalette.neutralLight.isSome:
    return theme.brandPalette.neutralLight.get()
  return fallback

proc getBrandNeutralDark*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand neutral dark color (text), with fallback
  if theme.brandPalette.neutralDark.isSome:
    return theme.brandPalette.neutralDark.get()
  return fallback

proc getBrandSurface*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand surface color (cards/panels), with fallback
  if theme.brandPalette.surfaceColor.isSome:
    return theme.brandPalette.surfaceColor.get()
  return fallback

proc getBrandError*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand error color, with fallback
  if theme.brandPalette.errorColor.isSome:
    return theme.brandPalette.errorColor.get()
  return fallback

proc getBrandSuccess*(theme: Theme, fallback: Color = Color()): Color =
  ## Get brand success color, with fallback
  if theme.brandPalette.successColor.isSome:
    return theme.brandPalette.successColor.get()
  return fallback


## ============================================================================
## Typography Extraction
## ============================================================================

proc getBrandPrimaryFont*(theme: Theme, fallback: string = ""): string =
  ## Get brand primary font (headings), with fallback
  if theme.typography.primaryFont.isSome:
    return theme.typography.primaryFont.get()
  return fallback

proc getBrandSecondaryFont*(theme: Theme, fallback: string = ""): string =
  ## Get brand secondary font (body text), with fallback
  if theme.typography.secondaryFont.isSome:
    return theme.typography.secondaryFont.get()
  return fallback

proc getBrandMonoFont*(theme: Theme, fallback: string = ""): string =
  ## Get brand monospace font (code), with fallback
  if theme.typography.monoFont.isSome:
    return theme.typography.monoFont.get()
  return fallback

proc getBrandDefaultWeight*(theme: Theme, fallback: FontWeight = Regular): FontWeight =
  ## Get brand default font weight, with fallback
  if theme.typography.defaultWeight.isSome:
    return theme.typography.defaultWeight.get()
  return fallback

proc getBrandHeadingWeight*(theme: Theme, fallback: FontWeight = Bold): FontWeight =
  ## Get brand heading font weight, with fallback
  if theme.typography.headingWeight.isSome:
    return theme.typography.headingWeight.get()
  return fallback

proc getBrandLineHeight*(theme: Theme, fallback: float32 = 1.5): float32 =
  ## Get brand line height, with fallback
  if theme.typography.lineHeight.isSome:
    return theme.typography.lineHeight.get()
  return fallback

proc getBrandLetterSpacing*(theme: Theme, fallback: float32 = 0.0): float32 =
  ## Get brand letter spacing, with fallback
  if theme.typography.letterSpacing.isSome:
    return theme.typography.letterSpacing.get()
  return fallback


## ============================================================================
## Spacing Scale Extraction
## ============================================================================

type SpacingSize* = enum
  XS    # Extra small
  SM    # Small
  MD    # Medium
  LG    # Large
  XL    # Extra large
  XXL   # Extra extra large

proc getBrandSpacing*(theme: Theme, size: SpacingSize, fallback: float32 = 8.0): float32 =
  ## Get spacing value for given size, with fallback
  case size
  of XS:
    if theme.spacing.xs.isSome:
      return theme.spacing.xs.get()
  of SM:
    if theme.spacing.sm.isSome:
      return theme.spacing.sm.get()
  of MD:
    if theme.spacing.md.isSome:
      return theme.spacing.md.get()
  of LG:
    if theme.spacing.lg.isSome:
      return theme.spacing.lg.get()
  of XL:
    if theme.spacing.xl.isSome:
      return theme.spacing.xl.get()
  of XXL:
    if theme.spacing.xxl.isSome:
      return theme.spacing.xxl.get()

  return fallback

proc getBrandBaseUnit*(theme: Theme, fallback: float32 = 8.0): float32 =
  ## Get spacing base unit (grid system), with fallback
  if theme.spacing.baseUnit.isSome:
    return theme.spacing.baseUnit.get()
  return fallback


## ============================================================================
## Animation Settings Extraction
## ============================================================================

proc getBrandDurationFast*(theme: Theme, fallback: float32 = 150.0): float32 =
  ## Get fast animation duration in ms, with fallback
  if theme.animation.durationFast.isSome:
    return theme.animation.durationFast.get()
  return fallback

proc getBrandDurationNormal*(theme: Theme, fallback: float32 = 250.0): float32 =
  ## Get normal animation duration in ms, with fallback
  if theme.animation.durationNormal.isSome:
    return theme.animation.durationNormal.get()
  return fallback

proc getBrandDurationSlow*(theme: Theme, fallback: float32 = 400.0): float32 =
  ## Get slow animation duration in ms, with fallback
  if theme.animation.durationSlow.isSome:
    return theme.animation.durationSlow.get()
  return fallback

proc getBrandEasing*(theme: Theme, fallback: AnimationEasing = EaseOut): AnimationEasing =
  ## Get default animation easing, with fallback
  if theme.animation.defaultEasing.isSome:
    return theme.animation.defaultEasing.get()
  return fallback


## ============================================================================
## Asset Path Extraction
## ============================================================================

proc getBrandLogoPath*(theme: Theme, fallback: string = ""): string =
  ## Get brand logo path, with fallback
  if theme.assets.logoPath.isSome:
    return theme.assets.logoPath.get()
  return fallback

proc getBrandIconPackPath*(theme: Theme, fallback: string = ""): string =
  ## Get brand icon pack directory path, with fallback
  if theme.assets.iconPackPath.isSome:
    return theme.assets.iconPackPath.get()
  return fallback

proc getBrandCursorPath*(theme: Theme, fallback: string = ""): string =
  ## Get brand cursor path, with fallback
  if theme.assets.cursorPath.isSome:
    return theme.assets.cursorPath.get()
  return fallback

proc getBrandBackgroundPattern*(theme: Theme, fallback: string = ""): string =
  ## Get brand background pattern path, with fallback
  if theme.assets.backgroundPattern.isSome:
    return theme.assets.backgroundPattern.get()
  return fallback

proc getBrandBackgroundPatternOpacity*(theme: Theme, fallback: float32 = 0.05): float32 =
  ## Get brand background pattern opacity, with fallback
  if theme.assets.backgroundPatternOpacity.isSome:
    return theme.assets.backgroundPatternOpacity.get()
  return fallback


## ============================================================================
## Metadata Extraction
## ============================================================================

proc getBrandName*(theme: Theme, fallback: string = ""): string =
  ## Get brand name, with fallback
  if theme.metadata.brandName.isSome:
    return theme.metadata.brandName.get()
  return fallback

proc getBrandVersion*(theme: Theme, fallback: string = ""): string =
  ## Get theme version, with fallback
  if theme.metadata.version.isSome:
    return theme.metadata.version.get()
  return fallback

proc getBrandAuthor*(theme: Theme, fallback: string = ""): string =
  ## Get theme author, with fallback
  if theme.metadata.author.isSome:
    return theme.metadata.author.get()
  return fallback

proc getBrandWebsite*(theme: Theme, fallback: string = ""): string =
  ## Get brand website, with fallback
  if theme.metadata.website.isSome:
    return theme.metadata.website.get()
  return fallback

proc getBrandDescription*(theme: Theme, fallback: string = ""): string =
  ## Get theme description, with fallback
  if theme.metadata.description.isSome:
    return theme.metadata.description.get()
  return fallback


## ============================================================================
## Convenience Functions (Common Patterns)
## ============================================================================

proc createBrandTextStyle*(theme: Theme, isHeading: bool = false): TextStyle =
  ## Create a TextStyle using brand typography settings
  result = TextStyle()

  # Choose font based on heading/body
  if isHeading:
    result.fontFamily = theme.getBrandPrimaryFont(fallback = "Arial")
    # Font weight handled separately if needed
  else:
    result.fontFamily = theme.getBrandSecondaryFont(fallback = "Arial")

  # Default size (can be overridden)
  result.fontSize = 14.0

  # Use brand text color
  result.color = theme.getBrandNeutralDark(fallback = Color(r: 33, g: 33, b: 33, a: 255))

proc applyBrandSpacing*(rect: var Rect, theme: Theme, size: SpacingSize = MD) =
  ## Apply brand spacing as padding to a rectangle (shrinks rect)
  let space = theme.getBrandSpacing(size)
  rect.x += space
  rect.y += space
  rect.width -= space * 2
  rect.height -= space * 2

proc getBrandPaddingEdges*(theme: Theme, size: SpacingSize = MD): EdgeInsets =
  ## Get EdgeInsets using brand spacing scale
  let space = theme.getBrandSpacing(size)
  result = EdgeInsets(top: space, right: space, bottom: space, left: space)
