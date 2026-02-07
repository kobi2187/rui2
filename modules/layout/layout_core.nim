type
  Alignment* = enum
    Leading, Center, Trailing  # Main axis
    Top, Bottom               # Cross axis for horizontal
    Left, Right              # Cross axis for vertical
    Stretch                  # Fill cross axis
    Baseline                 # Text alignment

  Justify* = enum
    Start, Center, End
    SpaceBetween  # Full space between items
    SpaceAround   # Equal space around items
    SpaceEvenly   # Equal space between and edges

  EdgeInsets* = object
    left*, top*, right*, bottom*: float32

# Basic stacks - simple, common cases
type
  HStack* = ref object of Widget
    spacing*: float32
    align*: Alignment      # Vertical alignment
    padding*: EdgeInsets

  VStack* = ref object of Widget
    spacing*: float32
    align*: Alignment      # Horizontal alignment
    padding*: EdgeInsets

# More complex container
type
  Direction* = enum
    Horizontal, Vertical

  Layout* = object
    direction*: Direction
    align*: Alignment     
    justify*: Justify
    spacing*: float32
    padding*: EdgeInsets
    wrap*: bool           # Allow wrapping to next line/column

  Container* = ref object of Widget
    layout*: Layout


