## Every widget on screen, in tabs -- for looking at, and for scripted visual tests.
##
## `buildGallery` returns the whole UI. `examples/gallery/gallery.nim` runs it;
## `tests/test_gallery.nim` checks that it shows every registered widget; and
## `tools/gallery_probe.sh` drives it through the scripting protocol (screenshots,
## pixel hashes, update latency).
##
## Everything a script may want to read or poke has a `stringId`: the tab control
## is `tabs`, and widgets are `<tab>.<name>` (`basics.save`, `live.echo`).
## `live.*` is the pane built for measuring: text that updates on a timer and
## on input, so a test can ask "did it repaint, and how long did that take?".

import rui
import raylib as rl
import std/[options, json, tables, sets, strutils, times, monotimes, math, os]

proc newEmbed*(w: Widget): Widget = w
  ## `Embed(existing)` puts a widget built elsewhere into a `ui:` tree.

type
  Gallery* = ref object
    root*: Widget
    tabs*: TabControl
    store*: Store
    live*: LivePane
    dialogs*: seq[Widget]        ## modal widgets that are not in the tree until shown
    themePicker*: ComboBox       ## the header's theme dropdown; the app fills it and reacts to it

  LivePane* = ref object
    ## The pane whose job is to change: what a latency test watches.
    running*: Link[bool]
    tick*: Link[int]
    intervalMs*: int
    nextTick: MonoTime
    spark: Sparkline
    values: seq[float]
    log: TextArea
    bar: ProgressBar
    tickLabel: Label

const tabTitles* = ["Basics", "Input", "Pickers", "Layout", "Lists & data",
                    "Graphics", "Menus", "Live"]

# ---------------------------------------------------------------------------
# tabs

proc basicsTab(store: Store): Widget =
  let clicks = store.declare("clicks", 0)
  let counter = newButton(text = "Clicked 0",
                          onClick = proc() = clicks.value = clicks.value + 1).named("basics.counter")
  clicks.bindTo(counter, proc(n: int) = counter.text = "Clicked " & $n)
  ui:
    Column(spacing = 12.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("basics"):
      Label(text = "Labels", fontSize = 20.0, bold = true)
      Wrap(spacing = 16.0, runSpacing = 8.0):
        Label(text = "plain")
        Label(text = "bold", bold = true)
        Label(text = "italic", italic = true)
        Label(text = "underline", underline = true)
        Label(text = "<b>markup</b> and <i>style</i>", markup = true)
        Hyperlink(text = "a hyperlink", url = "https://example.com").named("basics.link")
        Badge(text = "new").named("basics.badge")
        Icon(glyph = "★", size = 22).named("basics.icon")
      Wrap(spacing = 10.0, runSpacing = 8.0):
        Button(text = "Default").named("basics.save")
        Button(text = "Info", intent = ThemeIntent.Info)
        Button(text = "Success", intent = ThemeIntent.Success)
        Button(text = "Warning", intent = ThemeIntent.Warning)
        Button(text = "Danger", intent = ThemeIntent.Danger)
        Button(text = "Disabled", disabled = true)
        Embed(counter)
      Wrap(spacing = 10.0, runSpacing = 8.0):
        IconButton(iconText = "⚙", size = 32.0)
        IconButton(iconText = "✉", size = 32.0)
        ToolBar(barHeight = 40.0, spacing = 4.0, padding = 4.0):
          ToolButton(iconText = "B", text = "Bold", size = 28.0)
          ToolButton(iconText = "I", text = "Italic", size = 28.0)
        Tooltip(text = "A tooltip appears after a pause", delay = 0.4):
          Button(text = "Hover me").named("basics.hover")
      Wrap(spacing = 18.0, runSpacing = 8.0):
        Checkbox(text = "Check me", initialChecked = true).named("basics.check")
        Checkbox(text = "Off")
        Switch(text = "Switch", initialOn = true).named("basics.switch")
        RadioGroup(options = @["One", "Two", "Three"], initialSelectedIndex = 1,
                   spacing = 16.0).named("basics.radios")
        RadioButton(text = "A lone radio")
      Wrap(spacing = 18.0, runSpacing = 8.0):
        SegmentedControl(options = @["Day", "Week", "Month"], initialSelectedIndex = 1)
        Rating(initialValue = 3).named("basics.rating")
        Separator(vertical = true, thickness = 1.0).frame(height = 24)
        ProgressBar(initialValue = 60.0).named("basics.progress").frame(width = 160)
        Spinner(initialValue = 4.0, minValue = 0.0, maxValue = 10.0)

proc inputTab(store: Store): Widget =
  let name = store.declare("name", "Ada")
  let level = store.declare("level", 40.0'f32)
  ui:
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("input"):
      Label(text = "Hello, " & $name.value, fontSize = 20.0, bold = true)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Text")
        TextInput(text = name.value, onChange = name.setter).named("input.text").size(220, 32)
        Label(text = "Password")
        PasswordInput(initialText = "secret").named("input.password").size(160, 32)
        Label(text = "Search")
        SearchInput(initialText = "clear me").named("input.search").size(180, 32)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Number")
        NumberInput(initialValue = 3.0, minValue = -50.0, maxValue = 50.0).named("input.number")
        Label(text = "Slider")
        Slider(value = level.value, onChange = level.setter).named("input.slider").size(220, 28)
        Label(text = "Range")
        RangeSlider(initialLow = 20, initialHigh = 70).named("input.range").size(220, 28)
        Label(text = "ScrollBar")
        ScrollBar(initialValue = 20.0, minValue = 0.0, maxValue = 100.0,
                  vertical = false).named("input.scrollbar").size(160, 14)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Combo")
        ComboBox(items = @["Small", "Medium", "Large"], initialSelectedIndex = 1).named("input.combo")
        Label(text = "Autocomplete")
        Autocomplete(suggestions = @["Berlin", "Bern", "Bergen", "Bremen", "Hamburg"],
                     placeholder = "Type ber...").named("input.auto").size(200, 32)
      Label(text = "Notes (a TextArea; Enter makes a new line)")
      TextArea(initialText = "First line\nSecond line", visibleLines = 5,
               fontSize = 14.0).named("input.area").size(520, 130)

proc pickersTab(store: Store): Widget =
  let due = store.declare("due", "2026-10-11")
  let alarm = store.declare("alarm", "07:30")
  let accent = store.declare("accent", "#3366cc")
  ui:
    Column(spacing = 12.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("pickers"):
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Date")
        DatePicker(value = due.value, onChange = due.setter).named("pickers.date")
        Label(text = $due.value)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Time")
        TimePicker(value = alarm.value, onChange = alarm.setter).named("pickers.time")
        Label(text = $alarm.value)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Colour")
        ColorPicker(value = accent.value, onChange = accent.setter).named("pickers.color")
        Label(text = $accent.value)
      Label(text = "FilePicker (embedded)")
      FilePicker(mode = fpOpen, filters = @["*.nim"], initialPath = ".",
                 multiSelect = true).named("pickers.files").size(600, 240)

proc layoutTab(): Widget =
  var inner: Widget
  let tabsInside = newTabControl(tabs = @["First", "Second"], initialActiveTab = 0,
                                 tabBarHeight = 28.0).named("layout.nested").size(320, 90)
  tabsInside.addChild(newLabel(text = "content of the first nested tab"))
  tabsInside.addChild(newLabel(text = "content of the second"))
  let stackPages = newIndexedStack(index = 1).named("layout.indexed").size(200, 40)
  stackPages.addChild(newLabel(text = "page 0"))
  stackPages.addChild(newLabel(text = "page 1 (shown)"))
  let scroll = newScrollView().named("layout.scroll").size(220, 100)
  let rows = newVStack(spacing = 4.0, padding = 4.0)
  for i in 0 ..< 20: rows.addChild(newLabel(text = "scroll row " & $i))
  scroll.addChild(rows)
  inner = ui:
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("layout"):
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Panel(padding = 6.0, cornerRadius = 0.0):
          Panel(padding = 10.0, cornerRadius = 6.0).named("layout.panel").size(160, 70):
            Label(text = "Panel")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Card().named("layout.card").size(160, 70):
            Label(text = "Card")
        Panel(padding = 6.0, cornerRadius = 0.0):
          GroupBox(title = "GroupBox", padding = 10.0, titleHeight = 20.0).size(180, 80):
            Label(text = "inside")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Expander(title = "Expander", initialExpanded = true).named("layout.expander").size(200, 90):
            Label(text = "expanded content")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Drawer(side = dsLeft, initialOpen = true, width = 90.0).size(220, 80):
            Label(text = "drawer")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Panel(padding = 6.0, cornerRadius = 0.0):
          SplitView(initialRatio = 0.4).named("layout.split").size(320, 90):
            Label(text = "left")
            Label(text = "right")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Wrap(spacing = 6.0, runSpacing = 6.0).size(220, 80):
            Badge(text = "a")
            Badge(text = "b")
            Badge(text = "c")
            Badge(text = "wrap")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Panel(padding = 6.0, cornerRadius = 0.0):
          GridView(crossAxisCount = 3, mainAxisSpacing = 4.0, crossAxisSpacing = 4.0).size(180, 70):
            Rectangle(color = Color(r: 90, g: 140, b: 220, a: 255))
            Rectangle(color = Color(r: 110, g: 180, b: 120, a: 255))
            Rectangle(color = Color(r: 220, g: 120, b: 90, a: 255))
        Panel(padding = 6.0, cornerRadius = 0.0):
          Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
                columnSpacing = 8.0, rowSpacing = 4.0).size(240, 84):
            TableRow():
              Label(text = "Name")
              TextInput(placeholder = "Ada")
            TableRow():
              Label(text = "Plan")
              ComboBox(items = @["Starter", "Team"], initialSelectedIndex = 1)
        Panel(padding = 6.0, cornerRadius = 0.0):
          Stack().size(120, 60):
            Rectangle(color = Color(r: 90, g: 140, b: 220, a: 255))
            Center():
              Label(text = "stack")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Panel(padding = 6.0, cornerRadius = 0.0):
          Align(alignment = Alignment(x: 1.0, y: 1.0)).size(120, 60):
            Label(text = "align")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Padding(padding = EdgeInsets.all(8.0)).size(120, 60):
            Label(text = "padding")
        Panel(padding = 6.0, cornerRadius = 0.0):
          SizedBox(width = 100.0, height = 40.0):
            Label(text = "sized")
        Panel(padding = 6.0, cornerRadius = 0.0):
          ConstrainedBox(constraints = BoxConstraints(minWidth: 80.0, maxWidth: 140.0, minHeight: 0.0, maxHeight: 60.0)).size(100, 40):
            Label(text = "constrained")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Container().size(100, 40):
            Label(text = "container")
        Panel(padding = 6.0, cornerRadius = 0.0):
          Flex(direction = Axis.horizontal, spacing = 6.0).size(220, 30):
            Expanded(flex = 1): Label(text = "expanded")
            Flexible(flex = 1): Label(text = "flexible")
            Spacer(minHeight = 4.0)
        Panel(padding = 6.0, cornerRadius = 0.0):
          Positioned(left = 4.0, top = 4.0).size(120, 40):
            Label(text = "positioned")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Panel(padding = 6.0, cornerRadius = 0.0):
          Embed(scroll)
        Panel(padding = 6.0, cornerRadius = 0.0):
          Embed(tabsInside)
        Panel(padding = 6.0, cornerRadius = 0.0):
          Embed(stackPages)
        Panel(padding = 6.0, cornerRadius = 0.0):
          Dock().named("layout.dock").size(260, 110):
            Docked(side = DockSide.top):
              Label(text = "top dock")
            Docked(side = DockSide.left):
              Label(text = "left")
            Label(text = "fills the rest")
      StatusBar(text = "Ready", rightText = "Ln 1, Col 1", barHeight = 24.0).named("layout.status")
  inner

proc dataTab(): Widget =
  let tree = TreeNode(id: "root", text: "project", expanded: true, children: @[
    TreeNode(id: "src", text: "src", expanded: true, children: @[
      TreeNode(id: "main", text: "main.nim"), TreeNode(id: "util", text: "util.nim")]),
    TreeNode(id: "tests", text: "tests", expanded: false, children: @[
      TreeNode(id: "t1", text: "test_one.nim")]),
    TreeNode(id: "readme", text: "README.md")])
  var tableRows: seq[DataRow]
  for (name, role) in [("ada", "engineer"), ("grace", "admiral"), ("alan", "engineer"),
                       ("edsger", "professor"), ("barbara", "engineer")]:
    var values = initTable[string, JsonNode]()
    values["name"] = %name
    values["role"] = %role
    tableRows.add DataRow(id: name, values: values)
  var gridRows: seq[GridRow]
  for i in 0 ..< 200:
    gridRows.add GridRow(id: "g" & $i, values: @[%i, %("item " & $i), %(i * i)])
  var many: seq[string]
  for i in 0 ..< 10_000: many.add "row " & $i
  let table = newDataTable(
    columns = @[DataColumn(id: "name", title: "Name", width: 140.0, sortable: true, filterable: true),
                DataColumn(id: "role", title: "Role", width: 160.0, sortable: true, filterable: true)],
    data = tableRows, rowHeight = 22.0, visibleRows = 5).named("data.table").size(0, 190)
  let grid = newDataGrid(
    columns = @[GridColumn(id: "n", title: "#", width: 60.0, sortable: true),
                GridColumn(id: "label", title: "Label", width: 140.0, sortable: true),
                GridColumn(id: "sq", title: "Square", width: 100.0, sortable: true)],
    data = gridRows, rowHeight = 22.0, visibleRows = 6).named("data.grid").size(0, 160)
  ui:
    Row(spacing = 16.0, crossAxisAlignment = CrossAxisAlignment.start).named("data"):
      Expanded(flex = 2):
       Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch):
        Label(text = "TreeView")
        TreeView(rootNode = tree, nodeHeight = 22.0, visibleRows = 6).named("data.tree").size(0, 140)
        Label(text = "ListBox")
        ListBox(items = @["alpha", "beta", "gamma", "delta", "epsilon"], itemHeight = 20.0,
                visibleRows = 4).named("data.box").size(0, 90)
        Label(text = "ListView (10k rows)")
        ListView(items = many, itemHeight = 24.0, visibleRows = 5,
                 multiSelect = true).named("data.view").size(0, 130)
      Expanded(flex = 3):
       Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch):
        Label(text = "DataTable")
        Embed(table)
        Label(text = "DataGrid")
        Embed(grid)

proc samplePng(): string =
  ## A generated picture, so the gallery needs no asset. Twice as wide as tall,
  ## so the fit modes differ.
  result = getTempDir() / "rui_gallery_sample.png"
  if not fileExists(result):
    let img = rl.genImageGradientLinear(128, 64, 90,
                rl.Color(r: 60, g: 110, b: 200, a: 255),
                rl.Color(r: 240, g: 170, b: 60, a: 255))
    discard rl.exportImage(img, result)

proc graphicsTab(): Widget =
  var growth, curves: seq[tuple[x, y: float]]
  for i in 0 ..< 20:
    growth.add (float(i), 20.0 + float(i) * 4.0 + 6.0 * sin(float(i)))
    curves.add (float(i), 50.0 + 30.0 * sin(float(i) / 2.0))
  let dayStart = block:
    let n = now().utc
    dateTime(n.year, n.month, n.monthday, 0, 0, 0, zone = utc())
  let events = @[
    TimelineEvent(id: "build", title: "Build", startTime: dayStart + initDuration(minutes = 30),
                  endTime: dayStart + initDuration(hours = 2),
                  color: Color(r: 90, g: 140, b: 220, a: 255), data: newJObject()),
    TimelineEvent(id: "test", title: "Test", startTime: dayStart + initDuration(hours = 2),
                  endTime: dayStart + initDuration(hours = 3),
                  color: Color(r: 110, g: 180, b: 120, a: 255), data: newJObject())]
  let map = newMapWidget(initialCenter = MapCoord(lat: 20.0, lon: 0.0), initialZoom = 2.0,
                         minZoom = 1.0, maxZoom = 12.0, projection = mpMercator,
                         markerShape = msPin, showCoordinates = true,
                         showZoomControls = true, gridLines = true).named("graphics.map").size(300, 160)
  map.addMarker(MapMarker(id: "lon", coord: MapCoord(lat: 51.5, lon: -0.12), title: "London",
                          color: Color(r: 220, g: 70, b: 70, a: 255), size: 8.0, data: newJObject()))
  let canvas = newCanvas(enableDrawing = true, drawingMode = dmFreehand).named("graphics.canvas").size(220, 110)
  canvas.addCommand(DrawCommand(kind: dcRectFilled, rect: Rect(x: 10, y: 10, width: 60, height: 40),
                                rectColor: Color(r: 90, g: 140, b: 220, a: 255),
                                rectRounded: true, rectRoundness: 6.0))
  ui:
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("graphics"):
      Row(spacing = 12.0):
        Expanded(flex = 5):
          Plot(title = "Lines + area", series = @[lineSeries("a", growth),
                                                  areaSeries("b", curves)]).named("graphics.plot").size(0, 190)
        Expanded(flex = 4):
          Plot(title = "Bars", xLabels = @["Q1", "Q2", "Q3", "Q4"],
               series = @[barSeries("2025", @[(0.0, 15.0), (1.0, 20.0), (2.0, 14.0), (3.0, 25.0)])]).size(0, 190)
        Expanded(flex = 4):
          Plot(title = "Scatter", series = @[scatterSeries("s", @[(1.0, 2.0), (2.0, 3.5), (3.0, 2.8),
                                                                   (4.0, 5.0)])]).size(0, 190)
      Row(spacing = 12.0):
        Expanded(flex = 3):
          KanbanBoard(columns = @[
            KanbanColumn(title: "Todo", cards: @[KanbanCard(id: "t1", title: "Write docs")]),
            KanbanColumn(title: "Doing", cards: @[KanbanCard(id: "t2", title: "Gallery")]),
            KanbanColumn(title: "Done", cards: @[])]).named("graphics.kanban").size(0, 160)
        Expanded(flex = 2):
          Timeline(events = events, startTime = dayStart, endTime = dayStart + initDuration(hours = 6),
                   scale = tsHour, pixelsPerUnit = 70.0, eventHeight = 28.0, eventSpacing = 6.0,
                   showGrid = true, showTimeLabels = true).named("graphics.timeline").size(0, 160)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Embed(map)
        Embed(canvas)
        Column(spacing = 6.0):
          Sparkline(values = @[3.0, 5.0, 4.0, 6.0, 5.5, 8.0, 7.0, 9.0]).named("graphics.spark").size(140, 32)
          Rectangle(color = Color(r: 90, g: 140, b: 220, a: 255), cornerRadius = 6.0).size(100, 30)
          Circle(color = Color(r: 230, g: 170, b: 60, a: 255)).size(40, 40)
          ProgressBar(initialValue = 40.0).size(140, 14)
        ImageWidget(imagePath = samplePng(), width = 96.0, height = 48.0,
                    fitMode = ImageFit.Contain).named("graphics.image").size(96, 48)
        DragDropArea(mode = dmFiles, acceptedExtensions = @[".nim"]).named("graphics.drop").size(160, 100)

proc menusTab(g: Gallery): Widget =
  let bar = newMenuBar(barHeight = 28.0).named("menus.bar")
  let fileMenu = newMenu(title = "File", minWidth = 160.0).named("menus.file")
  fileMenu.addChild(newMenuItem(text = "New", shortcut = "Ctrl+N"))
  fileMenu.addChild(newMenuItem(separator = true))
  fileMenu.addChild(newMenuItem(text = "Quit", shortcut = "Ctrl+Q"))
  bar.addChild(fileMenu)
  let viewMenu = newMenu(title = "View", minWidth = 160.0)
  viewMenu.addChild(newMenuItem(text = "Word wrap", checkable = true))
  bar.addChild(viewMenu)
  let ctx = newContextMenu(minWidth = 160.0).named("menus.context")
  ctx.addChild(newMenuItem(text = "Cut"))
  ctx.addChild(newMenuItem(text = "Copy"))
  let confirm = newMessageBox(title = "Confirm", message = "Discard changes?",
                              messageType = mbQuestion, buttons = mbYesNoCancel).named("menus.messagebox")
  let fileDialog = newFileDialog(title = "Open Nim files", mode = fdOpen, filters = @["*.nim"],
                                 initialPath = ".").named("menus.filedialog")
  let dialog = newDialog(title = "Settings", dialogWidth = 320.0).named("menus.dialog")
  dialog.addChild(newCheckbox(text = "Remember me"))
  g.dialogs.add [Widget(confirm), Widget(fileDialog), Widget(dialog)]
  let page = newVStack(spacing = 10.0, padding = 0.0).named("menus")
  page.addChild(bar)
  let body = newVStack(spacing = 10.0, padding = 16.0)
  let buttons = newWrap(spacing = 10.0, runSpacing = 10.0)       # natural width, not full row
  body.addChild(buttons)
  buttons.addChild(newButton(text = "Show context menu", onClick = proc() = ctx.openAt(260.0, 180.0)).named("menus.openContext"))
  buttons.addChild(newButton(text = "MessageBox", onClick = proc() = confirm.show()).named("menus.openMessage"))
  buttons.addChild(newButton(text = "FileDialog", onClick = proc() = fileDialog.show()).named("menus.openFile"))
  buttons.addChild(newButton(text = "Dialog", onClick = proc() = dialog.show()).named("menus.openDialog"))
  body.addChild(ctx)
  page.addChild(body)
  page

# ---------------------------------------------------------------------------
# the live pane

proc bigDoc(): string =
  var lines: seq[string]
  for i in 0 ..< 3000: lines.add "line " & $i & ": the quick brown fox jumps over the lazy dog"
  lines.join("\n")

proc liveTab(g: Gallery, store: Store): Widget =
  let echoText = store.declare("liveText", "type here")
  let tick = store.declare("liveTick", 0)
  let bumps = store.declare("liveBumps", 0)
  let running = newLink(false)
  g.live = LivePane(running: running, tick: tick, intervalMs: 50)
  let live = g.live
  live.log = newTextArea(initialText = "", visibleLines = 6, fontSize = 13.0, editable = false)
  live.log.stringId = "live.log"
  live.bar = newProgressBar(initialValue = 0.0)
  live.bar.stringId = "live.bar"
  live.spark = newSparkline(values = @[0.0])
  live.spark.stringId = "live.spark"
  live.tickLabel = newLabel(text = "tick 0")
  live.tickLabel.stringId = "live.tick"
  ui:
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch).named("live"):
      Label(text = "Live: panes that change, for measuring how fast they do",
            fontSize = 18.0, bold = true)
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Label(text = "Type")
        TextInput(text = echoText.value, onChange = echoText.setter).named("live.input").size(260, 32)
        Label(text = "echo: " & $echoText.value).named("live.echo")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Button(text = "Bump", onClick = proc() = bumps.value = bumps.value + 1).named("live.bump")
        Label(text = "bumped " & $bumps.value & " times").named("live.bumped")
      Wrap(spacing = 12.0, runSpacing = 8.0):
        Switch(text = "Run ticker", on = running.value, onToggle = running.setter).named("live.run")
        Embed(live.tickLabel)
        Embed(live.bar).size(220, 16)
        Embed(live.spark).size(220, 32)
      Embed(live.log).size(560, 130)
      Label(text = "A long document (3000 lines): typing at the end is the slow case")
      Embed(newTextArea(initialText = bigDoc(), visibleLines = 10, fontSize = 14.0)
              .named("live.doc")).size(700, 220)

proc stepLive*(g: Gallery, now = getMonoTime()) =
  ## Advance the ticker if it is running and due. Called once per frame.
  let live = g.live
  if live == nil or not live.running.value or now < live.nextTick: return
  live.nextTick = now + initDuration(milliseconds = live.intervalMs)
  live.tick.value = live.tick.value + 1
  let n = live.tick.value
  live.tickLabel.text = "tick " & $n
  live.tickLabel.layoutDirty = true
  live.tickLabel.markDirtyToRoot()
  live.bar.value = float32(n mod 100)
  live.bar.markDirtyToRoot()
  live.values.add 5.0 + 4.0 * sin(float(n) / 4.0)
  if live.values.len > 40: live.values.delete(0)
  live.spark.values = live.values
  live.spark.markDirtyToRoot()
  var lines = live.log.text.splitLines()
  lines.add "line " & $n
  if lines.len > 6: lines = lines[lines.len - 6 .. ^1]
  live.log.replaceText(lines.join("\n"))
  live.tickLabel.repaintAfter(float(live.intervalMs) / 1000.0)

# ---------------------------------------------------------------------------

proc buildGallery*(only = -1, themes: seq[string] = @[]): Gallery =
  ## `only` >= 0 builds just that tab (the others are empty pages): for finding
  ## which widget is the one misbehaving.
  result = Gallery(store: newStore())
  let g = result
  let tabs = newTabControl(tabs = @tabTitles, initialActiveTab = 0, tabBarHeight = 30.0)
  tabs.stringId = "tabs"
  for i in 0 ..< tabTitles.len:
    let holder = newVStack(spacing = 0.0, padding = 12.0)
    if only < 0 or only == i:
      holder.addChild(case i
        of 0: basicsTab(g.store)
        of 1: inputTab(g.store)
        of 2: pickersTab(g.store)
        of 3: layoutTab()
        of 4: dataTab()
        of 5: graphicsTab()
        of 6: menusTab(g)
        else: liveTab(g, g.store))
    tabs.addChild(holder)
  if only >= 0: tabs.initialActiveTab = only
  g.tabs = tabs
  let root = newVStack(spacing = 0.0, padding = 0.0)
  root.stringId = "gallery"
  # A header above the tabs: switch the whole gallery's theme from a dropdown.
  g.themePicker = newComboBox(items = themes, initialSelectedIndex = 0).named("theme.picker")
  let header = ui:
    Padding(padding = EdgeInsets.all(6.0)).named("header"):
      Row(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.center):
        Label(text = "Theme")
        Embed(g.themePicker)
  root.addChild(header)
  root.addChild(tabs)
  g.root = root
  for d in g.dialogs: root.addChild(d)
