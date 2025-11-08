type
  ThemeWidget* = ref object of Widget
    themeData*: ptr ThemeData  # Shared theme data
    intent*: ThemeIntent       # Widget's purpose
    state*: ThemeState        # Current state
    
  ThemeData* = object
    name*: string
    base*: Table[ThemeIntent, ThemeProps]
    states*: Table[ThemeIntent, Table[ThemeState, ThemeProps]]
    cache*: ThemeCache        # Shared cache for all widgets

proc getProps*(w: ThemeWidget): ThemeProps =
  # Get cached properties for current state
  w.themeData.cache.getOrCreateProps(
    w.intent, 
    w.state
  )

# Usage in widgets
proc draw*(b: Button) =
  # State determined automatically
  b.state = if b.disabled: Disabled
           elif b.pressed: Pressed
           elif b.hovered: Hovered
           else: Normal
           
  # Get themed properties
  let props = b.getProps()
  
  # Draw using properties
  drawRect(b.rect, props.backgroundColor, props.cornerRadius)
  drawText(b.text, props.foregroundColor, props.fontSize)