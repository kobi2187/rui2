import std/[options, tables]

import ../../core/types
import ../../drawing_primitives/primitives/text  # For TextStyle
import ./theme_types  # Shared type definitions (breaks circular dependency)

export theme_types

type
  GradientDirection* = enum
    Vertical
    Horizontal
    Radial

  ShadowLayer* = object
    offsetX*: float32
    offsetY*: float32
    blur*: float32
    opacity*: float32

  # Branding: Color Palette
  BrandPalette* = object
    primaryColor*: Option[Color]      # Main brand color (logo, primary actions)
    secondaryColor*: Option[Color]    # Supporting color
    accentColor*: Option[Color]       # Highlights, CTAs, important elements
    neutralLight*: Option[Color]      # Light backgrounds, dividers
    neutralDark*: Option[Color]       # Dark text, icons
    surfaceColor*: Option[Color]      # Card/panel backgrounds
    errorColor*: Option[Color]        # Error states (can differ from Danger intent)
    successColor*: Option[Color]      # Success states (can differ from Success intent)

  # Branding: Typography System
  FontWeight* = enum
    Light = 300
    Regular = 400
    Medium = 500
    SemiBold = 600
    Bold = 700
    ExtraBold = 800

  TypographySystem* = object
    primaryFont*: Option[string]      # Headings, buttons (e.g., "Montserrat")
    secondaryFont*: Option[string]    # Body text (e.g., "Open Sans")
    monoFont*: Option[string]         # Code, monospace (e.g., "JetBrains Mono")
    defaultWeight*: Option[FontWeight]
    headingWeight*: Option[FontWeight]
    lineHeight*: Option[float32]      # e.g., 1.5
    letterSpacing*: Option[float32]   # e.g., 0.02 for slight spacing

  # Branding: Spacing/Scale System (Design Tokens)
  SpacingScale* = object
    baseUnit*: Option[float32]        # Base grid unit (4.0 or 8.0 typical)
    xs*: Option[float32]              # Extra small (baseUnit * 0.5)
    sm*: Option[float32]              # Small (baseUnit * 1)
    md*: Option[float32]              # Medium (baseUnit * 2)
    lg*: Option[float32]              # Large (baseUnit * 3)
    xl*: Option[float32]              # Extra large (baseUnit * 4)
    xxl*: Option[float32]             # Extra extra large (baseUnit * 6)

  # Branding: Animation/Motion Settings
  AnimationEasing* = enum
    Linear          # No easing
    EaseIn          # Slow start
    EaseOut         # Slow end
    EaseInOut       # Slow start and end
    Bounce          # Bouncy, playful
    Elastic         # Springy effect

  AnimationSettings* = object
    durationFast*: Option[float32]    # Fast transitions (e.g., 150ms)
    durationNormal*: Option[float32]  # Normal transitions (e.g., 250ms)
    durationSlow*: Option[float32]    # Slow transitions (e.g., 400ms)
    defaultEasing*: Option[AnimationEasing]

  # Branding: Custom Assets
  BrandAssets* = object
    logoPath*: Option[string]               # Path to company logo
    iconPackPath*: Option[string]           # Directory with custom icons
    cursorPath*: Option[string]             # Custom cursor image
    backgroundPattern*: Option[string]      # Background texture/pattern path
    backgroundPatternOpacity*: Option[float32]  # Opacity of pattern (0.0-1.0)

  # Branding: Theme Metadata
  ThemeMetadata* = object
    brandName*: Option[string]              # Company/product name
    version*: Option[string]                # Theme version
    author*: Option[string]                 # Theme author
    website*: Option[string]                # Brand website
    description*: Option[string]            # Theme description

  # Core visual properties
  ThemeProps* = object
    # Basic colors and dimensions
    backgroundColor*: Option[Color]
    foregroundColor*: Option[Color]
    borderColor*: Option[Color]
    borderWidth*: Option[float32]
    cornerRadius*: Option[float32]
    padding*: Option[EdgeInsets]
    spacing*: Option[float32]

    # State-specific colors (for interactive widgets)
    pressedColor*: Option[Color]
    hoverColor*: Option[Color]
    activeColor*: Option[Color]
    focusColor*: Option[Color]

    # Text properties
    textStyle*: Option[TextStyle]
    fontSize*: Option[float32]
    fontFamily*: Option[string]  # Font family for text rendering

    # Focus effects
    focusRingColor*: Option[Color]      # Color of focus ring/outline
    focusRingWidth*: Option[float32]    # Width of focus ring
    focusGlowRadius*: Option[float32]   # Glow/shadow radius when focused
    focusGlowColor*: Option[Color]      # Glow/shadow color
    # 3D Bevel effects (BeOS, Windows 98, classic UIs)
    bevelStyle*: Option[BevelStyle]
    highlightColor*: Option[Color]      # Top-left edge for raised bevel (typically white)
    shadowColor*: Option[Color]         # Bottom-right inner edge (typically gray)
    darkShadowColor*: Option[Color]     # Bottom-right outer edge (typically black)

    # Gradient effects (Mac OS X Aqua, modern UIs)
    gradientStart*: Option[Color]
    gradientEnd*: Option[Color]
    gradientDirection*: Option[GradientDirection]

    # Shadow effects (modern flat design, depth)
    dropShadowOffset*: Option[tuple[x, y: float32]]
    dropShadowBlur*: Option[float32]
    dropShadowColor*: Option[Color]

    # Glow effects (focus states, highlights)
    glowColor*: Option[Color]
    glowRadius*: Option[float32]

    # Inner shadow (inset depth)
    insetShadowDepth*: Option[float32]
    insetShadowOpacity*: Option[float32]
    

    
  # Complete theme definition
  Theme* = object
    name*: string
    version*: string  # Semantic version (e.g., "1.0.0")
    # Base colors and properties for each intent
    base*: Table[ThemeIntent, ThemeProps]
    # State overrides for each intent
    states*: Table[ThemeIntent, Table[ThemeState, ThemeProps]]

    # Branding features (optional)
    brandPalette*: BrandPalette           # Brand color system
    typography*: TypographySystem         # Font system
    spacing*: SpacingScale                # Spacing tokens
    animation*: AnimationSettings         # Motion settings
    assets*: BrandAssets                  # Logo, icons, patterns
    metadata*: ThemeMetadata              # Brand info

proc initThemeTables(theme: var Theme) =
  if theme.base.len == 0:
    theme.base = initTable[ThemeIntent, ThemeProps]()
  if theme.states.len == 0:
    theme.states = initTable[ThemeIntent, Table[ThemeState, ThemeProps]]()
  for intent in ThemeIntent:
    if intent notin theme.base:
      theme.base[intent] = ThemeProps()
    if intent notin theme.states:
      theme.states[intent] = initTable[ThemeState, ThemeProps]()

proc newTheme*(name = ""): Theme =
  result.name = name
  result.base = initTable[ThemeIntent, ThemeProps]()
  result.states = initTable[ThemeIntent, Table[ThemeState, ThemeProps]]()
  for intent in ThemeIntent:
    result.base[intent] = ThemeProps()
    result.states[intent] = initTable[ThemeState, ThemeProps]()

import typetraits, system, system/iterators

  
proc merge*(a:var ThemeProps, b:ThemeProps) = 
  for name, aVal, bVal in fieldPairs(a, b):
    when bVal is Option:
      if bVal.isSome:
        aVal = bVal

proc merge*(tp1,tp2:ThemeProps) : ThemeProps = 
  result = tp1
  result.merge(tp2)
  

# Example usage:
proc getThemeProps*(theme: Theme, intent: ThemeIntent = Default, state: ThemeState = Normal): ThemeProps =
  # Start with base properties for this intent
  result = if intent in theme.base: theme.base[intent] else: ThemeProps()
  # Override with state-specific properties if any
  if intent in theme.states and state in theme.states[intent]:
    result.merge(theme.states[intent][state])



proc getDefaultThemeProps*(): ThemeProps =
  Theme().getThemeProps(Default, Normal)

# Example theme definition (would come from JSON/YAML)
let exampleTheme = """
name: "Modern Light"
base:
  default:
    backgroundColor: "#ffffff"
    foregroundColor: "#000000"
    borderColor: "#e0e0e0"
    borderWidth: 1
    cornerRadius: 4
    fontSize: 14
  info:
    backgroundColor: "#e3f2fd"
    foregroundColor: "#1976d2"
    borderColor: "#bbdefb"
  danger:
    backgroundColor: "#ffebee"
    foregroundColor: "#c62828"
    borderColor: "#ffcdd2"
states:
  default:
    disabled:
      backgroundColor: "#f5f5f5"
      foregroundColor: "#9e9e9e"
    hovered:
      backgroundColor: "#fafafa"
    pressed:
      backgroundColor: "#f0f0f0"
  danger:
    hovered:
      backgroundColor: "#ffcdd2"
    pressed:
      backgroundColor: "#ef9a9a"
"""

# # Usage in widgets
# proc draw(button: Button, renderer: Renderer) =
#   # Get current state
#   let state = if button.isDisabled: Disabled
#               elif button.isPressed: Pressed
#               elif button.isHovered: Hovered
#               else: Normal
              
#   # Get theme properties for this button's intent and state
#   let props = currentTheme.getThemeProps(button.intent, state)
  
#   # Use properties for rendering
#   renderer.drawRect(button.bounds, props.backgroundColor, props.cornerRadius)
#   renderer.drawText(button.text, props.foregroundColor, props.fontSize)

# Theme caching for performance
type ThemeCache* = object
  # Cache key combines intent and state
  cache: Table[tuple[intent: ThemeIntent, state: ThemeState], ThemeProps]
  
proc getOrCreateProps*(cache: var ThemeCache, theme: Theme, 
                     intent: ThemeIntent, state: ThemeState): ThemeProps =
  let key = (intent, state)
  if key notin cache.cache:
    cache.cache[key] = theme.getThemeProps(intent, state)
  result = cache.cache[key]

# ============================================================================
# Global Current Theme
# ============================================================================

var currentTheme*: Theme = newTheme("Default")
  ## The active theme used by widgets during rendering.
  ## Set via app.setTheme() or directly for headless testing.

proc setCurrentTheme*(theme: Theme) =
  ## Set the global current theme
  currentTheme = theme

proc makeColor*(r, g, b: int, a: int = 255): Color =
  when defined(useGraphics):
    Color(
      r: uint8(r),
      g: uint8(g),
      b: uint8(b),
      a: uint8(a)
    )
  else:
    Color()