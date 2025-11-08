import std/[options, tables]

import ../core/types
import drawing_primitives

type
  # Core theme concepts
  ThemeState* = enum
    Normal     # Default state
    Disabled
    Hovered
    Pressed    # Being clicked/touched
    Focused    # Keyboard focus
    Selected   # For lists, tabs etc
    DragOver   # When dragging something over this widget
    
  ThemeIntent* = enum
    Default    # Normal appearance
    Info       # Informational elements
    Success    # Positive actions/states
    Warning    # Caution required
    Danger     # Destructive or error states
    
  # Core visual properties
  ThemeProps* = object
    backgroundColor*: Option[Color]
    foregroundColor*: Option[Color]
    borderColor*: Option[Color]
    borderWidth*: Option[float32]
    cornerRadius*: Option[float32]
    padding*: Option[EdgeInsets]
    spacing*: Option[float32]
    textStyle*: Option[TextStyle]
    fontSize*: Option[float32]
    

    
  # Complete theme definition
  Theme* = object
    name*: string
    # Base colors and properties for each intent
    base*: Table[ThemeIntent, ThemeProps]
    # State overrides for each intent
    states*: Table[ThemeIntent, Table[ThemeState, ThemeProps]]

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

import typetraits, os, system, system/iterators

  
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