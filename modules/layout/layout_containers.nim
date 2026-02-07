
import ../../core/types
type
  Direction* = enum
    Horizontal, Vertical

  Alignment* = enum
    Leading      # Start of axis
    Center       # Middle
    Trailing     # End of axis
    Top, Bottom               # Cross axis for horizontal
    Left, Right              # Cross axis for vertical
    Stretch      # Fill available space
    
  Justify* = enum
    Start
    Center
    End
    SpaceBetween  # Full space between items
    SpaceAround   # Equal space around items
    SpaceEvenly   # Equal space between and edges



  # Base container all layouts derive from
  Container* = ref object of Widget
    padding*: EdgeInsets
    spacing*: float32

  # Simple stacks
  HStack* = ref object of Container
    align*: Alignment      # Cross-axis (vertical) alignment

  VStack* = ref object of Container
    align*: Alignment      # Cross-axis (horizontal) alignment

  # Flexible container
  FlexContainer* = ref object of Container
    direction*: Direction
    align*: Alignment     
    justify*: Justify
    wrap*: bool           # Allow wrapping to next line/column

  # Grid layout
  Grid* = ref object of Container
    columns*: int
    rows*: int
    align*: Alignment     # Cell content alignment
    columnSpacing*: float32
    rowSpacing*: float32

  # Dock layout 
  DockPosition* = enum
    Left, Top, Right, Bottom, Fill

  DockContainer* = ref object of Container
    # Child widgets need their dockPosition set
    
  # Z-order overlay
  OverlayContainer* = ref object of Container
    # Children drawn in order added



proc newHStack*(spacing: float32 = 0.0, align: Alignment = Leading): HStack =
  HStack(
    spacing: spacing,
    align: align,
    padding: edgeInsets(0)
  )

proc newVStack*(spacing: float32 = 0.0, align: Alignment = Leading): VStack =
  VStack(
    spacing: spacing,
    align: align,
    padding: edgeInsets(0)
  )

proc newGrid*(columns: int, spacing: float32 = 0.0): Grid =
  Grid(
    columns: columns,
    spacing: spacing,
    align: Center,
    padding: edgeInsets(0)
  )

type WrapContainer* = ref object of Container
  # spacing*: float32          # Between items
  lineSpacing*: float32      # Between rows/columns
  align*: Alignment         # Item alignment
  justify*: Justify         # Line justification