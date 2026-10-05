import std/[options, tables]

import rui_core
import primitives/text  # For TextStyle
import theme_types  # Shared type definitions (breaks circular dependency)

export theme_types

type
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
    fontWeight*: Option[FontWeight]  # Captions: SemiBold and up draw bold
    uppercase*: Option[bool]         # Captions in capitals (button labels, tabs)

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
    

    
  HintStyle* = object
    ## How the help overlay's hint badges look. Every field is optional; what a
    ## theme leaves out is the default sign-post look (see `hintLook`).
    background*, foreground*, border*: Option[Color]
    borderWidth*, fontSize*: Option[float32]
    fontFamily*: Option[string]
    uppercase*: Option[bool]

  ControlMetrics* = object
    ## The geometry of controls that is not a per-intent colour or stroke: how
    ## tall a control is, how big a check box's square, how thick a slider's
    ## track. Unset fields take the library defaults (see the accessors below),
    ## so a theme file or a hand-built Theme only names what it changes.
    ##
    ## Together with the per-intent `borderWidth`, `cornerRadius`, `padding`,
    ## `fontSize`, `fontWeight` and drop shadow, this is what lets one brand
    ## be fat and bold and another thin and lean with the same widgets.
    controlHeight*: Option[float32]   ## Min height of buttons, inputs, combos
    indicatorSize*: Option[float32]   ## Check box square / radio circle
    trackThickness*: Option[float32]  ## Slider track
    thumbSize*: Option[float32]       ## Slider thumb diameter
    progressHeight*: Option[float32]  ## Progress bar height
    rowHeight*: Option[float32]       ## List, tree, table and menu rows
    scrollbarThickness*: Option[float32]

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

    metrics*: ControlMetrics              # Control geometry
    hint*: HintStyle                      # Help-overlay hint badges

    statePreference*: array[ControlRole, StatePreference]
      ## Hover-or-focus-first, per control role. Read on every lookup from the
      ## in-memory theme (`ladderFor`), never from the theme file: the file is
      ## parsed once, into this.

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

proc controlHeight*(theme: Theme): float32 =
  ## Minimum height of a button, input or combo box; 0 sizes to content.
  theme.metrics.controlHeight.get(0.0)
proc indicatorSize*(theme: Theme): float32 = theme.metrics.indicatorSize.get(20.0)
proc trackThickness*(theme: Theme): float32 = theme.metrics.trackThickness.get(8.0)
proc thumbSize*(theme: Theme): float32 = theme.metrics.thumbSize.get(20.0)
proc progressHeight*(theme: Theme): float32 = theme.metrics.progressHeight.get(20.0)

proc rowHeight*(theme: Theme, legacy: float32): float32 =
  ## Height of a list, tree, table or menu row: the theme's, or the widget's
  ## own default (`legacy`) when the theme names none.
  theme.metrics.rowHeight.get(legacy)

proc barHeight*(theme: Theme, legacy: float32): float32 =
  ## Height of a tab strip, menu, tool or status bar: the widget's default,
  ## grown to the theme's control height so a bold brand's bars keep pace
  ## with its buttons.
  max(legacy, theme.controlHeight)

type HintLook* = object
  ## A hint badge's look with every default filled in.
  background*, foreground*, border*: Color
  borderWidth*, fontSize*: float32
  fontFamily*: string
  uppercase*: bool

proc hintLook*(theme: Theme): HintLook =
  ## Hint badges read like a sign post by default: yellow, a thick dark border,
  ## small uppercase monospace type. A theme may change any part of that.
  let h = theme.hint
  HintLook(
    background: h.background.get(Color(r: 255, g: 212, b: 0, a: 255)),
    foreground: h.foreground.get(Color(r: 17, g: 17, b: 17, a: 255)),
    border: h.border.get(Color(r: 17, g: 17, b: 17, a: 255)),
    borderWidth: h.borderWidth.get(2.5'f32),
    fontSize: h.fontSize.get(11.0'f32),
    fontFamily: h.fontFamily.get("Monospace"),
    uppercase: h.uppercase.get(true))

proc transitionSeconds*(theme: Theme): float32 =
  ## How long a colour takes to change when a control's state does (hover,
  ## press, focus): the theme's `animation.durationFast`, in milliseconds, 120
  ## if it names none. 0 makes every change instant.
  theme.animation.durationFast.get(120.0'f32) / 1000.0'f32

proc scrollbarThickness*(theme: Theme): float32 = theme.metrics.scrollbarThickness.get(12.0)

template themedSize*(explicit: float32, themed: untyped): float32 =
  ## A size prop that defaults to 0, meaning "whatever the theme says".
  (if explicit > 0: explicit else: themed)

proc isBold*(props: ThemeProps): bool =
  ## Whether captions drawn with these props are bold.
  props.fontWeight.get(Regular) >= SemiBold

proc ladderFor*(theme: Theme, role: ControlRole): StateLadder =
  ## The ladder this theme uses for a role. A role left at `spRoleDefault`
  ## keeps the library's convention: a caret matters more than the pointer for
  ## text, and the pointer matters more for everything it acts on directly.
  case theme.statePreference[role]
  of spHoverFirst: slPointerFirst
  of spFocusFirst: slFocusFirst
  of spRoleDefault:
    if role == crText: slFocusFirst else: slPointerFirst

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

# There was a ThemeCache here, memoising (intent, state) -> ThemeProps, reached
# through ThemeManager.getProps. Nothing ever called getProps, so the cache was
# never on any lookup path, and it was removed rather than wired up: measured
# over two million lookups it was worth 2% (71.2ns uncached vs 69.6ns cached).
#
# Both paths are dominated by copying ThemeProps, which is some thirty Option
# fields, and a cache does not avoid that copy -- it only skips one table lookup
# and the state merge. A real win would have to return something cheaper to copy
# (a reference, or a narrowed struct), which is a different change.

# ============================================================================
# Global Current Theme
# ============================================================================

var currentTheme*: Theme = newTheme("Default")
  ## The active theme used by widgets during rendering.
  ## Set via app.setTheme() or directly for headless testing.

# The visual-state ladder lives in theme_state.nim now, as visualState() over
# four bools plus a StateLadder saying which of Focused and Hovered wins.
#
# The two groups still disagree, and the disagreement still looks deliberate --
# for a text field, showing where the caret will go matters more than showing
# the pointer is nearby; for a button it is the other way round. So the choice
# is carried rather than made: each widget passes the ladder it already used,
# nothing looks different, and deciding the two groups should agree is now a
# one-word edit per widget rather than a re-derivation in each. See issue #21.

proc canvasColor*(theme: Theme): Color =
  ## Colour for the window behind the widget tree.
  ##
  ## Prefers the brand palette's surface colour, which built-in themes set a
  ## shade away from the Default intent so a Default-intent control does not
  ## vanish into the background. Falls back to the Default background, then to
  ## a neutral light grey.
  if theme.brandPalette.surfaceColor.isSome:
    return theme.brandPalette.surfaceColor.get()
  let props = theme.getThemeProps(ThemeIntent.Default, ThemeState.Normal)
  if props.backgroundColor.isSome:
    return props.backgroundColor.get()
  Color(r: 245, g: 245, b: 245, a: 255)

proc setCurrentTheme*(theme: Theme) =
  ## Set the global current theme, and its typography as the default family.
  currentTheme = theme
  inc settleEpoch                # a new theme lands at once, without fading
  inc measureEpoch               # and nothing keeps the old theme's sizes
  themeFontFamily = theme.typography.primaryFont.get("")

proc makeColor*(r, g, b: int, a: int = 255): Color =
  Color(
    r: uint8(r),
    g: uint8(g),
    b: uint8(b),
    a: uint8(a)
  )