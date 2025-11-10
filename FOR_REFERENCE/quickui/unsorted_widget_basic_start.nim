# Basic Widget Categories
type
  WidgetKind* = enum
    # Input Controls
    wkButton, wkCheckbox, wkRadio, wkToggle
    wkTextInput, wkNumberInput, wkPasswordInput
    wkSlider, wkRangeSlider
    wkDropdown, wkComboBox
    
    # Display Controls
    wkLabel, wkImage, wkIcon
    wkProgressBar, wkSpinner
    wkBadge, wkTooltip
    
    # Containers
    wkBox, wkStack, wkWrap
    wkScroll, wkViewport
    wkExpander, wkSplitter
    wkTabContainer
    
    # Data Display
    wkList, wkTable, wkTree
    wkDataGrid, wkPropertyGrid
    
    # Navigation
    wkMenu, wkToolbar, wkBreadcrumb
    wkTabs, wkPagination
    
    # Complex Widgets
    wkColorPicker, wkDatePicker
    wkFileInput, wkRichText
    wkChart, wkTimeline

# Core Widget Properties
type
  BasicProps* = object
    id*: string
    rect*: Rect
    visible*: bool
    enabled*: bool
    style*: Option[Style]

  LayoutProps* = object
    flex*: float32
    margin*: EdgeInsets
    padding*: EdgeInsets
    alignment*: Alignment
    constraints*: BoxConstraints

  EdgeInsets* = object
    left*, top*, right*, bottom*: float32

  BoxConstraints* = object
    minWidth*, maxWidth*: float32
    minHeight*, maxHeight*: float32

  Alignment* = enum
    aStart, aCenter, aEnd, 
    aSpaceBetween, aSpaceAround, aSpaceEvenly,
    aStretch

# Container System
type
  Container* = ref object of Widget
    direction*: FlowDirection
    wrap*: bool
    spacing*: Point
    alignment*: Alignment
    children*: seq[Widget]
    
  FlowDirection* = enum
    Horizontal, Vertical
    
  # Container-specific constraints
  SizeConstraint* = enum
    Fixed,      # Exact size
    Fill,       # Fill available space
    Shrink,     # Shrink to content
    Percentage  # Percentage of parent

  SizeValue* = object
    case kind*: SizeConstraint
    of Fixed: value*: float32
    of Fill: weight*: float32
    of Shrink: discard
    of Percentage: percent*: float32

# Theme System
type
  ThemeData* = object
    colors*: ColorScheme
    typography*: TypographyScheme
    spacing*: SpacingScheme
    borders*: BorderScheme
    shadows*: ShadowScheme

  ColorScheme* = object
    primary*, secondary*, accent*: Color
    background*, surface*, error*: Color
    onPrimary*, onSecondary*, onBackground*: Color
    disabled*, hover*, pressed*: Color

  TypographyScheme* = object
    h1*, h2*, h3*, h4*, h5*, h6*: TextStyle
    body1*, body2*: TextStyle
    button*, caption*, overline*: TextStyle

  SpacingScheme* = object
    xs*, sm*, md*, lg*, xl*: float32

  BorderScheme* = object
    radius*: EdgeRadius
    width*: float32
    color*: Color

  ShadowScheme* = object
    elevation*: array[5, Shadow]  # Different shadow levels

# Example widget definitions using the new system
defineWidget Button:
  props:
    text: string
    icon: Option[Icon]
    variant: ButtonVariant
    onClick: proc()

  render:
    let theme = currentTheme()
    let style = computeButtonStyle(widget, theme)
    
    if nw.button(widget.text, style):
      widget.onClick()

defineWidget DataGrid:
  props:
    columns: seq[Column]
    data: seq[Row]
    sortable: bool
    filterable: bool
    onSort: Option[proc(col: Column, order: SortOrder)]
    onFilter: Option[proc(filters: TableFilters)]

  state:
    sortColumn: Option[Column]
    sortOrder: SortOrder
    filters: TableFilters
    selection: HashSet[int]

  render:
    # Grid header with sort indicators
    renderHeader(widget)
    
    # Filter bar if enabled
    if widget.filterable:
      renderFilters(widget)
    
    # Virtual scrolling list of rows
    renderRows(widget)

# Container usage example
let layout = Container(
  direction: Vertical,
  spacing: Point(x: 8, y: 8),
  alignment: aStart,
  children: @[
    Header(
      size: Size(kind: Fill)
    ),
    HBox(
      children: @[
        Sidebar(
          size: Size(kind: Fixed, value: 200)
        ),
        Content(
          size: Size(kind: Fill)
        )
      ]
    ),
    Footer(
      size: Size(kind: Shrink)
    )
  ]
)