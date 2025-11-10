defineWidget Button:
  props:
    text: string
    onClick: proc()
    icon: Option[Icon]

  render:
    # Use raygui
    if GuiButton(widget.toRaylibRect(), widget.text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

    # Draw icon if present
    if widget.icon.isSome:
      drawIcon(widget.icon.get, widget.getIconRect())

  input:
    if event.kind == ieMousePress and widget.enabled:
      widget.isPressed = true
      true
    elif event.kind == ieMouseRelease and widget.isPressed:
      widget.isPressed = false
      if widget.containsPoint(event.mousePos):
        widget.onClick()
      true
    else:
      false

  state:
    fields:
      text: string
      enabled: bool
      pressed: bool
      icon: Option[Icon]

# Helper for button creation
proc button*(text: string, onClick: proc()): Button =
  Button(
    text: text,
    onClick: onClick,
    enabled: true,
    visible: true
  )

# Number input with validation
defineWidget NumberInput:
  props:
    value: float
    minValue: float
    maxValue: float
    step: float
    format: string = "%.2f"
    onChange: proc(newValue: float)

  render:
    var value = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr value,
      widget.minValue,
      widget.maxValue,
      widget.enabled
    ):
      if value != widget.value:
        widget.value = value
        if widget.onChange != nil:
          widget.onChange(value)

  state:
    fields:
      value: float
      enabled: bool
      focused: bool

# Dropdown/Combo box
defineWidget ComboBox:
  props:
    items: seq[string]
    selectedIndex: int
    onSelect: proc(index: int)
    dropDownHeight: float32

  render:
    let itemsStr = widget.items.join(";")
    var selected = widget.selectedIndex

    if GuiComboBox(
      widget.toRaylibRect(),
      itemsStr,
      addr selected
    ):
      if selected != widget.selectedIndex:
        widget.selectedIndex = selected
        if widget.onSelect != nil:
          widget.onSelect(selected)

  state:
    fields:
      items: seq[string]
      selectedIndex: int
      enabled: bool

# List view with selection
defineWidget ListView:
  props:
    items: seq[string]
    selection: HashSet[int]
    multiSelect: bool
    onSelect: proc(selected: HashSet[int])
    scrollOffset: float32

  render:
    var selected = widget.selection
    let itemsStr = widget.items.join(";")

    if GuiListView(
      widget.toRaylibRect(),
      itemsStr,
      addr widget.scrollOffset,
      selected
    ):
      if widget.onSelect != nil:
        widget.onSelect(selected)

  state:
    fields:
      items: seq[string]
      selection: HashSet[int]
      scrollOffset: float32

# Group box / Panel
defineWidget GroupBox:
  props:
    title: string
    padding: EdgeInsets

  render:
    GuiGroupBox(
      widget.toRaylibRect(),
      widget.title
    )

    # Draw children with padding
    let childRect = widget.getContentRect()
    for child in widget.children:
      child.draw()

  state:
    fields:
      title: string
      padding: EdgeInsets

# Tab control
defineWidget TabControl:
  props:
    tabs: seq[string]
    activeTab: int
    onTabChanged: proc(newTab: int)

  render:
    var active = widget.activeTab
    if GuiTabBar(
      widget.toRaylibRect(),
      widget.tabs.join(";"),
      addr active
    ):
      if active != widget.activeTab:
        widget.activeTab = active
        if widget.onTabChanged != nil:
          widget.onTabChanged(active)

    # Draw active tab content
    if widget.activeTab >= 0 and
       widget.activeTab < widget.children.len:
      widget.children[widget.activeTab].draw()

  state:
    fields:
      tabs: seq[string]
      activeTab: int

# Color picker
defineWidget ColorPicker:
  props:
    color: Color
    onChange: proc(newColor: Color)
    showAlpha: bool

  render:
    var col = widget.color
    if GuiColorPicker(
      widget.toRaylibRect(),
      "",
      addr col
    ):
      if col != widget.color:
        widget.color = col
        if widget.onChange != nil:
          widget.onChange(col)

  state:
    fields:
      color: Color
      enabled: bool

# Value inspector (property grid)
defineWidget PropertyGrid:
  props:
    properties: Table[string, Property]
    onChange: proc(name: string, value: any)

  render:
    for name, prop in widget.properties:
      case prop.kind
      of pkString:
        var value = prop.strVal
        if GuiTextBox(
          widget.getPropertyRect(name),
          value,
          100,
          true
        ):
          widget.properties[name].strVal = value
          widget.onChange(name, value)

      of pkNumber:
        var value = prop.numVal
        if GuiSpinner(
          widget.getPropertyRect(name),
          name,
          addr value,
          low(float),
          high(float),
          true
        ):
          widget.properties[name].numVal = value
          widget.onChange(name, value)

      of pkBool:
        var value = prop.boolVal
        if GuiCheckBox(
          widget.getPropertyRect(name),
          name,
          addr value
        ):
          widget.properties[name].boolVal = value
          widget.onChange(name, value)

      of pkColor:
        var value = prop.colorVal
        if GuiColorPicker(
          widget.getPropertyRect(name),
          name,
          addr value
        ):
          widget.properties[name].colorVal = value
          widget.onChange(name, value)

  state:
    fields:
      properties: Table[string, Property]

# Usage example:
let form = container:
  vstack:
    GroupBox(title: "Input Controls"):
      vstack:
        NumberInput(
          value: 0.0,
          minValue: 0.0,
          maxValue: 100.0,
          step: 1.0,
          onChange: proc(v: float) = echo v
        )

        ComboBox(
          items: @["Option 1", "Option 2", "Option 3"],
          onSelect: proc(idx: int) = echo idx
        )

        ListView(
          items: @["Item 1", "Item 2", "Item 3"],
          multiSelect: true,
          onSelect: proc(sel: HashSet[int]) = echo sel
        )

    TabControl(
      tabs: @["General", "Colors", "Advanced"],
      onTabChanged: proc(tab: int) = echo tab
    ):
      vstack:  # Tab 1
        # General settings...

      vstack:  # Tab 2
        ColorPicker(
          color: RED,
          onChange: proc(c: Color) = echo c
        )

      PropertyGrid(  # Tab 3
        properties: {
          "name": Property(kind: pkString, strVal: "Test"),
          "size": Property(kind: pkNumber, numVal: 100),
          "enabled": Property(kind: pkBool, boolVal: true),
          "color": Property(kind: pkColor, colorVal: BLUE)
        }.toTable
      )

# Basic text display
defineWidget Label:
  props:
    text: string
    wrap: bool
    alignment: TextAlignment
    fontSize: Option[int]

  render:
    let style = GuiGetStyle(DEFAULT, TEXT_SIZE)
    if widget.fontSize.isSome:
      GuiSetStyle(DEFAULT, TEXT_SIZE, widget.fontSize.get)

    GuiLabel(widget.toRaylibRect(), widget.text)

    if widget.fontSize.isSome:
      GuiSetStyle(DEFAULT, TEXT_SIZE, style)  # Restore style

# Text input field
defineWidget TextInput:
  props:
    text: string
    placeholder: string
    maxLength: int
    multiline: bool
    password: bool
    onTextChanged: proc(text: string)
    onSubmit: proc(text: string)
    selectionStart: int
    selectionEnd: int

  render:
    var text = widget.text
    if widget.password:
      if GuiPasswordBox(
        widget.toRaylibRect(),
        text.cstring,
        widget.maxLength,
        widget.focused
      ):
        if widget.onTextChanged != nil:
          widget.onTextChanged(text)
    else:
      if GuiTextBox(
        widget.toRaylibRect(),
        text.cstring,
        widget.maxLength,
        widget.focused
      ):
        if widget.onTextChanged != nil:
          widget.onTextChanged(text)

  input:
    if event.kind == ieKey and widget.focused:
      if event.key == KeyEnter and not widget.multiline:
        if widget.onSubmit != nil:
          widget.onSubmit(widget.text)
        true
      else:
        false
    else:
      false

# Checkbox with label
defineWidget Checkbox:
  props:
    text: string
    checked: bool
    onToggle: proc(checked: bool)

  render:
    var checked = widget.checked
    if GuiCheckBox(
      widget.toRaylibRect(),
      widget.text,
      addr checked
    ):
      widget.checked = checked
      if widget.onToggle != nil:
        widget.onToggle(checked)

# Radio button group
defineWidget RadioGroup:
  props:
    options: seq[string]
    selected: int
    onSelect: proc(index: int)

  render:
    var selected = widget.selected
    for i, opt in widget.options:
      if GuiRadioButton(
        Rectangle(
          x: widget.rect.x,
          y: widget.rect.y + float32(i * 24),
          width: 20,
          height: 20
        ),
        opt,
        selected == i
      ):
        widget.selected = i
        if widget.onSelect != nil:
          widget.onSelect(i)

# Slider with optional text
defineWidget Slider:
  props:
    value: float32
    minValue: float32
    maxValue: float32
    showValue: bool
    format: string
    onChange: proc(value: float32)

  render:
    var value = widget.value
    let text = if widget.showValue:
                 widget.format % value
               else: ""
    if GuiSlider(
      widget.toRaylibRect(),
      text,
      $value,
      addr value,
      widget.minValue,
      widget.maxValue
    ):
      widget.value = value
      if widget.onChange != nil:
        widget.onChange(value)

# Progress bar
defineWidget ProgressBar:
  props:
    value: float32
    maxValue: float32
    showPercentage: bool

  render:
    let text = if widget.showPercentage:
                 $int((widget.value / widget.maxValue) * 100) & "%"
               else: ""
    GuiProgressBar(
      widget.toRaylibRect(),
      text,
      $widget.value,
      0,
      widget.maxValue
    )

# Dropdown/Combo box
defineWidget ComboBox:
  props:
    items: seq[string]
    selected: int
    onSelect: proc(index: int)
    dropDownHeight: float32

  render:
    var selected = widget.selected
    if GuiComboBox(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr selected
    ):
      widget.selected = selected
      if widget.onSelect != nil:
        widget.onSelect(selected)

# Spinner (number input with up/down buttons)
defineWidget Spinner:
  props:
    value: int
    minValue: int
    maxValue: int
    onChange: proc(value: int)

  render:
    var value = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr value,
      widget.minValue,
      widget.maxValue,
      widget.focused
    ):
      widget.value = value
      if widget.onChange != nil:
        widget.onChange(value)

# List view
defineWidget ListView:
  props:
    items: seq[string]
    selected: int
    onSelect: proc(index: int)
    scrollIndex: int

  render:
    var selected = widget.selected
    if GuiListView(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr widget.scrollIndex,
      addr selected
    ):
      widget.selected = selected
      if widget.onSelect != nil:
        widget.onSelect(selected)

# Example usage:
let form = container:
  vstack:
    Label(text: "Personal Information", fontSize: some(24))

    TextInput(
      placeholder: "Name",
      maxLength: 50,
      onTextChanged: proc(text: string) = echo "Name: ", text
    )

    TextInput(
      placeholder: "Password",
      password: true,
      maxLength: 30,
      onSubmit: proc(text: string) = echo "Password entered"
    )

    RadioGroup(
      options: @["Male", "Female", "Other"],
      onSelect: proc(idx: int) = echo "Selected gender: ", idx
    )

    Checkbox(
      text: "Subscribe to newsletter",
      onToggle: proc(checked: bool) = echo "Subscribe: ", checked
    )

    Label(text: "Volume")
    Slider(
      minValue: 0,
      maxValue: 100,
      value: 50,
      showValue: true,
      format: "%.0f%%",
      onChange: proc(v: float32) = echo "Volume: ", v
    )

    ProgressBar(
      value: 75,
      maxValue: 100,
      showPercentage: true
    )

    ComboBox(
      items: @["Small", "Medium", "Large"],
      onSelect: proc(idx: int) = echo "Selected size: ", idx
    )

    ListView(
      items: @["Item 1", "Item 2", "Item 3"],
      onSelect: proc(idx: int) = echo "Selected item: ", idx
    )

# Tree view widget with collapsible nodes
defineWidget TreeView:
  props:
    rootNode: TreeNode
    selected: string  # Selected node id
    onSelect: proc(nodeId: string)
    onExpand: proc(nodeId: string)
    onCollapse: proc(nodeId: string)
    indent: float32 = 20.0

  type TreeNode* = ref object
    id*: string
    text*: string
    icon*: Option[Icon]
    expanded*: bool
    children*: seq[TreeNode]
    data*: JsonNode  # Custom data

  render:
    proc drawNode(node: TreeNode, x, y: float32, level: int): float32 =
      let nodeRect = Rectangle(
        x: x + level.float32 * widget.indent,
        y: y,
        width: widget.rect.width - (level.float32 * widget.indent),
        height: 24  # Node height
      )

      # Draw expand/collapse if has children
      if node.children.len > 0:
        if GuiButton(
          Rectangle(x: nodeRect.x - 16, y: nodeRect.y + 4, width: 16, height: 16),
          if node.expanded: "-" else: "+"
        ):
          node.expanded = not node.expanded
          if node.expanded and widget.onExpand != nil:
            widget.onExpand(node.id)
          elif not node.expanded and widget.onCollapse != nil:
            widget.onCollapse(node.id)

      # Draw node text/icon
      let isSelected = node.id == widget.selected
      if GuiButton(nodeRect, node.text, isSelected):
        widget.selected = node.id
        if widget.onSelect != nil:
          widget.onSelect(node.id)

      var nextY = y + 24

      # Draw children if expanded
      if node.expanded:
        for child in node.children:
          nextY = drawNode(child, x, nextY, level + 1)

      result = nextY

    # Start drawing from root
    discard drawNode(widget.rootNode, widget.rect.x, widget.rect.y, 0)

# Data grid with sorting, filtering
defineWidget DataGrid:
  props:
    columns: seq[Column]
    data: seq[Row]
    selected: HashSet[int]  # Selected row indices
    sortColumn: int
    sortAscending: bool
    onSort: proc(column: int, ascending: bool)
    onSelect: proc(selected: HashSet[int])

  type
    Column* = object
      title*: string
      width*: float32
      sortable*: bool
      filterable*: bool
      formatFunc*: proc(value: JsonNode): string

    Row* = object
      id*: string
      values*: seq[JsonNode]

  render:
    # Draw header
    var headerY = widget.rect.y
    var x = widget.rect.x

    for i, col in widget.columns:
      let headerRect = Rectangle(
        x: x,
        y: headerY,
        width: col.width,
        height: 24
      )

      let headerText = col.title &
        (if i == widget.sortColumn:
          if widget.sortAscending: " ▲" else: " ▼"
        else: "")

      if col.sortable and GuiButton(headerRect, headerText):
        if i == widget.sortColumn:
          widget.sortAscending = not widget.sortAscending
        else:
          widget.sortColumn = i
          widget.sortAscending = true

        if widget.onSort != nil:
          widget.onSort(i, widget.sortAscending)

      x += col.width

    # Draw rows
    var y = headerY + 24
    for rowIdx, row in widget.data:
      x = widget.rect.x
      let isSelected = rowIdx in widget.selected

      for colIdx, value in row.values:
        let col = widget.columns[colIdx]
        let cellRect = Rectangle(
          x: x,
          y: y,
          width: col.width,
          height: 24
        )

        let cellText = if col.formatFunc != nil:
                        col.formatFunc(value)
                      else:
                        $value

        if GuiButton(cellRect, cellText, isSelected):
          if isSelected:
            widget.selected.excl(rowIdx)
          else:
            widget.selected.incl(rowIdx)

          if widget.onSelect != nil:
            widget.onSelect(widget.selected)

        x += col.width
      y += 24

# Now for containers:

# Scrollable container
defineWidget ScrollView:
  props:
    contentSize: Size  # Size of content
    scrollX: bool     # Allow horizontal scroll
    scrollY: bool     # Allow vertical scroll
    scrollOffset: Point

  render:
    let viewRect = widget.rect
    let contentRect = Rectangle(
      x: 0,
      y: 0,
      width: widget.contentSize.width,
      height: widget.contentSize.height
    )

    # Handle scrollbars
    if widget.scrollY:
      let scrollY = GuiScrollBar(
        Rectangle(
          x: viewRect.x + viewRect.width - 12,
          y: viewRect.y,
          width: 12,
          height: viewRect.height
        ),
        widget.scrollOffset.y,
        0,
        max(0, contentRect.height - viewRect.height)
      )
      widget.scrollOffset.y = scrollY

    if widget.scrollX:
      let scrollX = GuiScrollBar(
        Rectangle(
          x: viewRect.x,
          y: viewRect.y + viewRect.height - 12,
          width: viewRect.width - 12,
          height: 12
        ),
        widget.scrollOffset.x,
        0,
        max(0, contentRect.width - viewRect.width)
      )
      widget.scrollOffset.x = scrollX

    # Draw content with scissor
    BeginScissorMode(
      viewRect.x.int32,
      viewRect.y.int32,
      viewRect.width.int32,
      viewRect.height.int32
    )

    for child in widget.children:
      child.rect.x -= widget.scrollOffset.x
      child.rect.y -= widget.scrollOffset.y
      child.draw()
      child.rect.x += widget.scrollOffset.x
      child.rect.y += widget.scrollOffset.y

    EndScissorMode()

  input:
    if event.kind == ieMouseWheel and widget.scrollY:
      widget.scrollOffset.y = clamp(
        widget.scrollOffset.y - event.wheelDelta * 20,
        0,
        max(0, widget.contentSize.height - widget.rect.height)
      )
      true
    else:
      false

# Tab container
defineWidget TabContainer:
  props:
    tabs: seq[Tab]
    activeTab: int
    onTabChange: proc(index: int)

  type Tab* = object
    title*: string
    closeable*: bool
    content*: Widget

  render:
    var active = widget.activeTab

    # Draw tab bar
    if GuiTabBar(
      Rectangle(
        x: widget.rect.x,
        y: widget.rect.y,
        width: widget.rect.width,
        height: 24
      ),
      widget.tabs.mapIt(it.title).join(";"),
      addr active
    ):
      widget.activeTab = active
      if widget.onTabChange != nil:
        widget.onTabChange(active)

    # Draw active tab content
    if widget.activeTab >= 0 and
       widget.activeTab < widget.tabs.len:
      let content = widget.tabs[widget.activeTab].content
      content.rect = Rectangle(
        x: widget.rect.x,
        y: widget.rect.y + 24,
        width: widget.rect.width,
        height: widget.rect.height - 24
      )
      content.draw()

# Tree and Grid example
let mainWindow = container:
  hsplit:
    # Left side: Tree
    TreeView(
      rootNode: TreeNode(
        id: "root",
        text: "Root",
        expanded: true,
        children: @[
          TreeNode(
            id: "folder1",
            text: "Folder 1",
            children: @[
              TreeNode(id: "item1", text: "Item 1"),
              TreeNode(id: "item2", text: "Item 2")
            ]
          ),
          TreeNode(id: "folder2", text: "Folder 2")
        ]
      ),
      onSelect: proc(id: string) = echo "Selected: ", id
    )

    # Right side: Grid in scroll view
    ScrollView(
      scrollY: true,
      child: DataGrid(
        columns: @[
          Column(title: "ID", width: 60),
          Column(title: "Name", width: 150),
          Column(title: "Value", width: 100, sortable: true)
        ],
        data: @[
          Row(id: "1", values: @[%"1", %"Item 1", %100]),
          Row(id: "2", values: @[%"2", %"Item 2", %200])
        ],
        onSort: proc(col: int, asc: bool) = echo "Sort: ", col
      )
    )

# Tab container example
let tabs = TabContainer(
  tabs: @[
    Tab(
      title: "General",
      content: vstack:
        Label(text: "Settings")
        Checkbox(text: "Enable feature")
    ),
    Tab(
      title: "Advanced",
      content: DataGrid(...)
    ),
    Tab(
      title: "Log",
      content: ScrollView(
        scrollY: true,
        child: Label(text: "Log content...")
      )
    )
  ]
)

# ----------------------

# Timeline/scheduling widget
defineWidget Timeline:
  props:
    startTime: DateTime
    endTime: DateTime
    events: seq[TimelineEvent]
    scale: float32  # Pixels per hour
    onEventClick: proc(event: TimelineEvent)
    onEventDrag: proc(event: TimelineEvent, newStart: DateTime)

  type TimelineEvent* = object
    id*: string
    title*: string
    startTime*: DateTime
    duration*: TimeInterval
    color*: Color
    data*: JsonNode

  render:
    # Draw time ruler
    var x = widget.rect.x
    let hourWidth = widget.scale
    var current = widget.startTime

    while current <= widget.endTime:
      GuiDrawText(
        current.format("HH:mm"),
        x.int32,
        widget.rect.y.int32,
        10,
        BLACK
      )
      x += hourWidth
      current = current + 1.hours

    # Draw events
    for event in widget.events:
      let eventRect = Rectangle(
        x: widget.rect.x + timeToPixels(event.startTime - widget.startTime, widget.scale),
        y: widget.rect.y + 20,
        width: timeToPixels(event.duration, widget.scale),
        height: 30
      )

      if GuiButton(eventRect, event.title):
        if widget.onEventClick != nil:
          widget.onEventClick(event)

# Color gradient editor
defineWidget GradientEditor:
  props:
    stops: seq[GradientStop]
    onStopAdd: proc(stop: GradientStop)
    onStopMove: proc(index: int, position: float32)
    onStopDelete: proc(index: int)
    onColorChange: proc(index: int, color: Color)

  type GradientStop* = object
    position*: float32  # 0.0 to 1.0
    color*: Color

  render:
    # Draw gradient preview
    let gradientRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 20
    )
    drawGradient(gradientRect, widget.stops)

    # Draw stop handles
    for i, stop in widget.stops:
      let handleRect = Rectangle(
        x: widget.rect.x + stop.position * widget.rect.width - 5,
        y: widget.rect.y + 25,
        width: 10,
        height: 20
      )

      if GuiButton(handleRect, ""):
        # Show color picker
        var newColor = stop.color
        if colorPicker(addr newColor):
          widget.onColorChange(i, newColor)

# File browser
defineWidget FileBrowser:
  props:
    currentPath: string
    filter: string
    multiSelect: bool
    selected: HashSet[string]
    onSelect: proc(paths: HashSet[string])
    onDoubleClick: proc(path: string)

  render:
    # Path navigation
    let pathRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 24
    )
    var path = widget.currentPath
    if GuiTextBox(pathRect, path, 1024, false):
      widget.currentPath = path

    # File list
    let files = getDirectoryFiles(widget.currentPath, widget.filter)
    var y = widget.rect.y + 30

    for file in files:
      let fileRect = Rectangle(
        x: widget.rect.x,
        y: y,
        width: widget.rect.width,
        height: 24
      )

      if GuiButton(fileRect, file.name, file.path in widget.selected):
        if widget.multiSelect:
          if file.path in widget.selected:
            widget.selected.excl(file.path)
          else:
            widget.selected.incl(file.path)
        else:
          widget.selected = [file.path].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selected)

      y += 24

# Chart widget
defineWidget Chart:
  props:
    data: seq[ChartPoint]
    xAxis: Axis
    yAxis: Axis
    series: seq[Series]
    legend: bool
    grid: bool

  type
    ChartPoint* = object
      x*, y*: float64
      label*: string

    Axis* = object
      title*: string
      min*, max*: float64
      step*: float64
      format*: proc(value: float64): string

    Series* = object
      name*: string
      color*: Color
      lineWidth*: float32
      pointSize*: float32

  render:
    # Draw axes
    drawAxis(widget.xAxis, widget.yAxis)

    # Draw grid if enabled
    if widget.grid:
      drawGrid(widget.xAxis, widget.yAxis)

    # Draw data series
    for series in widget.series:
      drawSeries(widget.data, series)

    # Draw legend if enabled
    if widget.legend:
      drawLegend(widget.series)

# Calendar widget
defineWidget Calendar:
  props:
    selectedDate: DateTime
    highlightedDates: HashSet[DateTime]
    onDateSelect: proc(date: DateTime)

  render:
    # Draw month/year navigation
    let headerRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 24
    )

    if GuiButton(headerRect.left(20), "<"):
      widget.selectedDate = widget.selectedDate - 1.months

    GuiLabel(headerRect, widget.selectedDate.format("MMMM yyyy"))

    if GuiButton(headerRect.right(20), ">"):
      widget.selectedDate = widget.selectedDate + 1.months

    # Draw weekday headers
    for i, day in ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]:
      GuiLabel(getDayRect(i), day)

    # Draw days
    let monthDays = getDaysInMonth(widget.selectedDate)
    for day in monthDays:
      let dayRect = getDayRect(day)
      let isHighlighted = day in widget.highlightedDates

      if GuiButton(dayRect, $day.dayOfMonth, isHighlighted):
        if widget.onDateSelect != nil:
          widget.onDateSelect(day)

# Rich text editor
defineWidget RichText:
  props:
    text: string
    selection: Option[TextRange]
    formats: Table[TextRange, TextFormat]
    onTextChange: proc(newText: string)
    onFormatChange: proc(range: TextRange, format: TextFormat)

  type
    TextRange* = object
      start*, finish*: int

    TextFormat* = object
      bold*, italic*, underline*: bool
      textColor*, backgroundColor*: Option[Color]
      fontSize*: Option[int]

  render:
    # Draw formatting toolbar
    drawToolbar()

    # Draw text content with formatting
    var y = widget.rect.y + 30
    for line in widget.text.splitLines:
      var x = widget.rect.x
      for ch in line:
        let format = getFormatAt(x, y)
        drawFormattedChar(ch, x, y, format)
        x += getCharWidth(ch, format)
      y += getLineHeight(format)

# Property editor grid
defineWidget PropertyGrid:
  props:
    properties: Table[string, Property]
    categories: Table[string, seq[string]]
    onPropertyChange: proc(name: string, value: JsonNode)

  type
    Property* = object
      name*: string
      value*: JsonNode
      kind*: PropertyKind
      options*: PropertyOptions

    PropertyKind* = enum
      pkString, pkNumber, pkBool, pkEnum,
      pkColor, pkFont, pkVector2, pkRect

    PropertyOptions* = object
      readOnly*: bool
      case kind*: PropertyKind
      of pkString:
        multiline*: bool
        maxLength*: int
      of pkNumber:
        min*, max*: float
        step*: float
      of pkEnum:
        choices*: seq[string]
      else: discard

# Color picker with palette
defineWidget ColorPicker:
  props:
    color*: Color
    showAlpha*: bool
    showPalette*: bool
    palette*: seq[Color]
    onColorChange*: proc(color: Color)

  render:
    var col = widget.color
    if GuiColorPicker(widget.toRaylibRect(), "", addr col):
      widget.color = col
      if widget.onColorChange != nil:
        widget.onColorChange(col)

    if widget.showPalette:
      let paletteRect = widget.getPaletteRect()
      for i, pColor in widget.palette:
        let swatchRect = Rectangle(
          x: paletteRect.x + (i mod 8).float32 * 20,
          y: paletteRect.y + (i div 8).float32 * 20,
          width: 18,
          height: 18
        )
        if GuiButton(swatchRect, ""):
          widget.color = pColor
          if widget.onColorChange != nil:
            widget.onColorChange(pColor)

# Date/Time picker
defineWidget DateTimePicker:
  props:
    value*: DateTime
    showTime*: bool
    minDate*: Option[DateTime]
    maxDate*: Option[DateTime]
    onChange*: proc(dt: DateTime)

  render:
    var year = widget.value.year
    var month = widget.value.month.int
    var day = widget.value.monthDay

    # Calendar header
    GuiLabel(widget.getHeaderRect(), $widget.value.month & " " & $year)

    # Calendar grid
    let firstDay = dateTime(year, month.Month, 1)
    let startOffset = firstDay.weekDay.int

    for i in 0..<42: # 6 weeks * 7 days
      let cellDay = i - startOffset + 1
      if cellDay > 0 and cellDay <= getDaysInMonth(month.Month, year):
        let cellRect = widget.getDayRect(i div 7, i mod 7)
        if GuiButton(cellRect, $cellDay):
          widget.value = dateTime(year, month.Month, cellDay)
          if widget.onChange != nil:
            widget.onChange(widget.value)

    # Time picker if enabled
    if widget.showTime:
      var hour = widget.value.hour
      var minute = widget.value.minute

      if GuiSpinner(widget.getHourRect(), "", addr hour, 0, 23, true):
        widget.value = widget.value.withHour(hour)
        if widget.onChange != nil:
          widget.onChange(widget.value)

      if GuiSpinner(widget.getMinuteRect(), "", addr minute, 0, 59, true):
        widget.value = widget.value.withMinute(minute)
        if widget.onChange != nil:
          widget.onChange(widget.value)

# File/Directory picker
defineWidget FilePicker:
  props:
    path*: string
    filter*: string
    dialogType*: FileDialogType
    onSelect*: proc(path: string)

  type FileDialogType = enum
    fdOpen, fdSave, fdDir

  render:
    # Path input
    var currentPath = widget.path
    if GuiTextBox(widget.getPathRect(), currentPath, 1024, true):
      widget.path = currentPath

    # File list
    let entries = getDirectoryEntries(widget.path, widget.filter)
    var selected = -1
    if GuiListView(
      widget.getListRect(),
      entries.join(";"),
      addr selected
    ):
      if selected >= 0:
        let newPath = entries[selected]
        if dirExists(newPath):
          widget.path = newPath
        elif widget.onSelect != nil:
          widget.onSelect(newPath)

# Code/Text editor
defineWidget CodeEditor:
  props:
    text*: string
    language*: string  # For syntax highlighting
    fontSize*: int
    showLineNumbers*: bool
    onTextChanged*: proc(text: string)

  render:
    # Line numbers
    if widget.showLineNumbers:
      let lineCount = widget.text.countLines()
      let gutterWidth = ($lineCount).len * widget.fontSize.float32

      for i in 1..lineCount:
        GuiLabel(
          Rectangle(
            x: widget.rect.x,
            y: widget.rect.y + (i-1).float32 * widget.fontSize,
            width: gutterWidth,
            height: widget.fontSize.float32
          ),
          $i
        )

    # Text area
    var text = widget.text
    if GuiTextBox(
      widget.getTextRect(),
      text,
      int.high,
      true
    ):
      widget.text = text
      if widget.onTextChanged != nil:
        widget.onTextChanged(text)

# Chart/Graph widget
defineWidget Chart:
  props:
    kind*: ChartKind
    data*: seq[ChartPoint]
    xAxis*: Axis
    yAxis*: Axis
    showGrid*: bool
    showLegend*: bool

  type
    ChartKind* = enum
      ckLine, ckBar, ckPie, ckScatter

    ChartPoint* = object
      x*, y*: float
      label*: string
      color*: Color

    Axis* = object
      title*: string
      min*, max*: float
      step*: float
      format*: proc(value: float): string

  render:
    # Draw axes
    if widget.showGrid:
      # Draw grid lines
      let xRange = widget.xAxis.max - widget.xAxis.min
      let yRange = widget.yAxis.max - widget.yAxis.min

      for x in countup(widget.xAxis.min, widget.xAxis.max, widget.xAxis.step):
        let screenX = widget.dataToScreenX(x)
        DrawLine(
          screenX.int32, widget.rect.y.int32,
          screenX.int32, (widget.rect.y + widget.rect.height).int32,
          fade(GRAY, 0.2)
        )

      for y in countup(widget.yAxis.min, widget.yAxis.max, widget.yAxis.step):
        let screenY = widget.dataToScreenY(y)
        DrawLine(
          widget.rect.x.int32, screenY.int32,
          (widget.rect.x + widget.rect.width).int32, screenY.int32,
          fade(GRAY, 0.2)
        )

    # Draw data
    case widget.kind
    of ckLine:
      var lastPoint: Option[ChartPoint]
      for point in widget.data:
        let screenX = widget.dataToScreenX(point.x)
        let screenY = widget.dataToScreenY(point.y)

        if lastPoint.isSome:
          DrawLine(
            widget.dataToScreenX(lastPoint.get.x).int32,
            widget.dataToScreenY(lastPoint.get.y).int32,
            screenX.int32,
            screenY.int32,
            point.color
          )

        DrawCircle(screenX.int32, screenY.int32, 3, point.color)
        lastPoint = some(point)

    of ckBar:
      let barWidth = widget.rect.width / widget.data.len.float32
      for i, point in widget.data:
        let screenX = widget.rect.x + i.float32 * barWidth
        let screenY = widget.dataToScreenY(point.y)
        DrawRectangle(
          screenX.int32,
          screenY.int32,
          barWidth.int32,
          (widget.rect.y + widget.rect.height - screenY).int32,
          point.color
        )

    of ckPie:
      var startAngle = 0.0
      let total = sum(widget.data.mapIt(it.y))
      let center = Point(
        x: widget.rect.x + widget.rect.width/2,
        y: widget.rect.y + widget.rect.height/2
      )
      let radius = min(widget.rect.width, widget.rect.height)/2

      for point in widget.data:
        let slice = point.y / total * 360.0
        DrawCircleSector(
          Vector2(x: center.x, y: center.y),
          radius,
          startAngle,
          startAngle + slice,
          36,
          point.color
        )
        startAngle += slice

    of ckScatter:
      for point in widget.data:
        let screenX = widget.dataToScreenX(point.x)
        let screenY = widget.dataToScreenY(point.y)
        DrawCircle(screenX.int32, screenY.int32, 3, point.color)


# Filterable data table
defineWidget DataTable:
  props:
    columns*: seq[Column]
    data*: seq[Row]
    filters*: Table[string, Filter]
    sortColumn*: string
    sortAscending*: bool
    onSort*: proc(column: string, ascending: bool)
    onFilter*: proc(filters: Table[string, Filter])
    onSelect*: proc(selected: HashSet[string])

  type
    Column* = object
      id*: string
      title*: string
      width*: float32
      sortable*: bool
      filterable*: bool
      filterKinds*: set[FilterKind]  # Allowed filter types
      formatFunc*: proc(value: JsonNode): string

    FilterKind* = enum
      fkEquals, fkContains, fkGreater, fkLess,
      fkBetween, fkIn, fkStartsWith, fkEndsWith

    Filter* = object
      column*: string
      case kind*: FilterKind
      of fkEquals, fkContains, fkStartsWith, fkEndsWith:
        text*: string
      of fkGreater, fkLess:
        value*: float
      of fkBetween:
        min*, max*: float
      of fkIn:
        values*: seq[string]

  render:
    # Filter bar
    var y = widget.rect.y
    if widget.filters.len > 0:
      for col in widget.columns:
        if col.filterable:
          let filter = widget.filters.getOrDefault(col.id)
          let filterRect = Rectangle(
            x: widget.rect.x,
            y: y,
            width: col.width,
            height: 24
          )

          # Filter type dropdown
          var filterKind = filter.kind
          if GuiComboBox(
            Rectangle(x: filterRect.x, y: filterRect.y, width: 100, height: 24),
            "=;~;>;<=;[]",
            addr filterKind.ord
          ):
            var newFilter = Filter(column: col.id, kind: filterKind)
            widget.filters[col.id] = newFilter
            if widget.onFilter != nil:
              widget.onFilter(widget.filters)

          # Filter value input
          let valueRect = Rectangle(
            x: filterRect.x + 110,
            y: filterRect.y,
            width: col.width - 110,
            height: 24
          )

          case filter.kind
          of fkEquals, fkContains, fkStartsWith, fkEndsWith:
            var text = filter.text
            if GuiTextBox(valueRect, text, 100, true):
              var newFilter = filter
              newFilter.text = text
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkGreater, fkLess:
            var value = filter.value
            if GuiSpinner(valueRect, "", addr value, low(float), high(float), true):
              var newFilter = filter
              newFilter.value = value
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkBetween:
            var min = filter.min
            var max = filter.max
            if GuiSpinner(
              Rectangle(x: valueRect.x, y: valueRect.y, width: 60, height: 24),
              "", addr min, low(float), high(float), true
            ):
              var newFilter = filter
              newFilter.min = min
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

            if GuiSpinner(
              Rectangle(x: valueRect.x + 70, y: valueRect.y, width: 60, height: 24),
              "", addr max, low(float), high(float), true
            ):
              var newFilter = filter
              newFilter.max = max
              widget.filters[col.id] = newFilter
              if widget.onFilter != nil:
                widget.onFilter(widget.filters)

          of fkIn:
            # Show popup for multi-select
            if GuiButton(valueRect, filter.values.join(", ")):
              # TODO: Show multi-select popup
              discard

      y += 30

    # Table header
    for col in widget.columns:
      let headerRect = Rectangle(
        x: widget.rect.x + getColumnOffset(col.id),
        y: y,
        width: col.width,
        height: 24
      )

      let sortIndicator = if col.id == widget.sortColumn:
                           if widget.sortAscending: " ▲" else: " ▼"
                         else: ""

      if col.sortable and GuiButton(headerRect, col.title & sortIndicator):
        if col.id == widget.sortColumn:
          widget.sortAscending = not widget.sortAscending
        else:
          widget.sortColumn = col.id
          widget.sortAscending = true

        if widget.onSort != nil:
          widget.onSort(widget.sortColumn, widget.sortAscending)

    y += 24

    # Table body
    for row in widget.data:
      if not matchesFilters(row, widget.filters):
        continue

      for col in widget.columns:
        let cellRect = Rectangle(
          x: widget.rect.x + getColumnOffset(col.id),
          y: y,
          width: col.width,
          height: 24
        )

        let value = row[col.id]
        let text = if col.formatFunc != nil:
                    col.formatFunc(value)
                  else:
                    $value

        GuiLabel(cellRect, text)

      y += 24

# Quick filter list
defineWidget FilterList:
  props:
    items*: seq[Item]
    filter*: string
    multiSelect*: bool
    selected*: HashSet[string]
    onSelect*: proc(selected: HashSet[string])

  type Item* = object
    id*: string
    text*: string
    tags*: seq[string]
    data*: JsonNode

  render:
    # Filter input
    var filter = widget.filter
    if GuiTextBox(
      Rectangle(
        x: widget.rect.x,
        y: widget.rect.y,
        width: widget.rect.width,
        height: 24
      ),
      filter,
      100,
      true
    ):
      widget.filter = filter

    # Filtered list
    var y = widget.rect.y + 30
    for item in widget.items:
      if widget.filter.len > 0:
        let filterLower = widget.filter.toLowerAscii
        let textLower = item.text.toLowerAscii
        let tagsLower = item.tags.mapIt(it.toLowerAscii)

        if not (filterLower in textLower or
                tagsLower.anyIt(filterLower in it)):
          continue

      let itemRect = Rectangle(
        x: widget.rect.x,
        y: y,
        width: widget.rect.width,
        height: 24
      )

      if GuiButton(itemRect, item.text, item.id in widget.selected):
        if widget.multiSelect:
          if item.id in widget.selected:
            widget.selected.excl(item.id)
          else:
            widget.selected.incl(item.id)
        else:
          widget.selected = [item.id].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selected)

      y += 24

# Usage example:
let table = DataTable(
  columns: @[
    Column(
      id: "id",
      title: "ID",
      width: 60,
      sortable: true,
      filterable: true,
      filterKinds: {fkEquals, fkGreater, fkLess}
    ),
    Column(
      id: "name",
      title: "Name",
      width: 200,
      sortable: true,
      filterable: true,
      filterKinds: {fkContains, fkStartsWith}
    ),
    Column(
      id: "status",
      title: "Status",
      width: 100,
      sortable: true,
      filterable: true,
      filterKinds: {fkEquals, fkIn}
    )
  ],
  onSort: proc(col: string, asc: bool) =
    echo "Sort by ", col, " ", if asc: "asc" else: "desc",
  onFilter: proc(filters: Table[string, Filter]) =
    echo "Filters: ", filters
)

let filterList = FilterList(
  items: @[
    Item(id: "1", text: "Item 1", tags: @["tag1", "tag2"]),
    Item(id: "2", text: "Item 2", tags: @["tag2", "tag3"]),
    Item(id: "3", text: "Item 3", tags: @["tag1", "tag3"])
  ],
  onSelect: proc(selected: HashSet[string]) =
    echo "Selected: ", selected
)

# Radio button
defineWidget RadioButton:
  props:
    text*: string
    value*: string    # This button's value
    selected*: string # Currently selected value
    onChange*: proc(value: string)

  render:
    if GuiRadioButton(
      widget.toRaylibRect(),
      widget.text,
      widget.selected == widget.value
    ):
      if widget.onChange != nil:
        widget.onChange(widget.value)

# Spinner (numeric up/down)
defineWidget Spinner:
  props:
    value*: float
    minValue*: float
    maxValue*: float
    step*: float = 1.0
    format*: string = "%.2f"
    onChange*: proc(value: float)

  render:
    var val = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr val,
      widget.minValue,
      widget.maxValue,
      widget.focused
    ):
      widget.value = val
      if widget.onChange != nil:
        widget.onChange(val)

# Tooltip
defineWidget Tooltip:
  props:
    text*: string
    delay*: float = 0.5  # Seconds before showing
    parent*: Widget      # Widget this tooltip belongs to

  render:
    if widget.parent.isHovered:
      if widget.hoverTime >= widget.delay:
        let mousePos = getMousePosition()
        GuiLabel(
          Rectangle(
            x: mousePos.x + 10,
            y: mousePos.y + 10,
            width: measureText(widget.text, 10).x + 10,
            height: 20
          ),
          widget.text
        )

# Separator (horizontal or vertical line)
defineWidget Separator:
  props:
    vertical*: bool
    color*: Color = GRAY

  render:
    if widget.vertical:
      DrawLineV(
        Vector2(x: widget.rect.x + widget.rect.width/2, y: widget.rect.y),
        Vector2(x: widget.rect.x + widget.rect.width/2, y: widget.rect.y + widget.rect.height),
        widget.color
      )
    else:
      DrawLineH(
        Vector2(x: widget.rect.x, y: widget.rect.y + widget.rect.height/2),
        Vector2(x: widget.rect.x + widget.rect.width, y: widget.rect.y + widget.rect.height/2),
        widget.color
      )

# Link (clickable text)
defineWidget Link:
  props:
    text*: string
    url*: string
    visited*: bool
    onClick*: proc()

  render:
    let color = if widget.visited: PURPLE else: BLUE
    if GuiLabelButton(widget.toRaylibRect(), widget.text):
      if widget.onClick != nil:
        widget.onClick()
      widget.visited = true

# Progress bar
defineWidget ProgressBar:
  props:
    value*: float
    maxValue*: float = 100.0
    showText*: bool = true
    format*: string = "%.0f%%"

  render:
    let percent = (widget.value / widget.maxValue) * 100
    let text = if widget.showText: widget.format % percent else: ""

    GuiProgressBar(
      widget.toRaylibRect(),
      "",
      text,
      0,
      widget.maxValue.float32,
      widget.value.int32
    )

# List box (single or multi-select)
defineWidget ListBox:
  props:
    items*: seq[string]
    selection*: HashSet[int]
    multiSelect*: bool
    onSelect*: proc(selection: HashSet[int])

  render:
    var selected = -1
    if GuiListView(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr selected
    ):
      if selected >= 0:
        if widget.multiSelect:
          if selected in widget.selection:
            widget.selection.excl(selected)
          else:
            widget.selection.incl(selected)
        else:
          widget.selection = [selected].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selection)

# Group box (frame with title)
defineWidget GroupBox:
  props:
    title*: string

  render:
    GuiGroupBox(widget.toRaylibRect(), widget.title)

    # Render children with adjusted rectangle
    let contentRect = Rectangle(
      x: widget.rect.x + 5,
      y: widget.rect.y + 20,
      width: widget.rect.width - 10,
      height: widget.rect.height - 25
    )

    for child in widget.children:
      child.rect = contentRect
      child.draw()

# Scroll bar
defineWidget ScrollBar:
  props:
    value*: float
    minValue*: float = 0.0
    maxValue*: float = 100.0
    pageSize*: float = 10.0
    vertical*: bool = true
    onChange*: proc(value: float)

  render:
    var val = widget.value
    if GuiScrollBar(
      widget.toRaylibRect(),
      val,
      widget.minValue,
      widget.maxValue
    ):
      widget.value = val
      if widget.onChange != nil:
        widget.onChange(val)

# Menu item
defineWidget MenuItem:
  props:
    text*: string
    shortcut*: string
    enabled*: bool = true
    checked*: bool = false
    onClick*: proc()

  render:
    var text = widget.text
    if widget.shortcut.len > 0:
      text &= "\t" & widget.shortcut

    if GuiMenuItem(widget.toRaylibRect(), text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

# Status bar
defineWidget StatusBar:
  props:
    text*: string
    rightText*: string

  render:
    GuiStatusBar(widget.toRaylibRect(), widget.text)

    if widget.rightText.len > 0:
      let rightRect = widget.rect
      rightRect.x = rightRect.x + rightRect.width -
                    measureText(widget.rightText, 10).x - 10
      GuiLabel(rightRect, widget.rightText)

# Icon button
defineWidget IconButton:
  props:
    icon*: IconData    # Could be enum for built-in icons or custom image
    tooltip*: string
    onClick*: proc()

  render:
    if GuiImageButton(
      widget.toRaylibRect(),
      widget.icon.texture,
      widget.icon.source
    ):
      if widget.onClick != nil:
        widget.onClick()

    if widget.tooltip.len > 0 and widget.isHovered:
      # Show tooltip...
      discard
