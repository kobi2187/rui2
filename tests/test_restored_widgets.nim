## Regression tests for the widgets restored from commit a4bcc18
##
## `a4bcc18` ("Stage A: remove dead code") deleted 35 widgets because nothing in
## the tree imported them -- the aggregator modules only listed the handful that
## had been ported to the v2 DSL. In a library the public API is the
## reachability root, not `main`, so "unreferenced" meant "not yet re-exported".
##
## These tests exist so that never silently happens again: every restored widget
## is constructed, sized, and asked to identify itself through the scripting
## bridge, which means it also has to be reachable from `import rui`.

import std/unittest
import rui
import std/[options, json, sets, tables, times]

template checkSizes(w: Widget) =
  ## Every widget must be able to give itself a size.
  w.layout()
  check w.bounds.width >= 0
  check w.bounds.height >= 0

template checkScriptable(w: Widget, expectedType: string) =
  ## Every DSL widget gets a generated scripting bridge.
  let state = w.getScriptableState()
  check state["type"].getStr() == expectedType
  check state.hasKey("visible")
  check state.hasKey("bounds")
  let res = w.handleScriptAction("read", newJObject())
  check res["success"].getBool()

suite "restored basic widgets":

  test "ComboBox seeds selection and grows when open":
    let w = newComboBox(items = @["one", "two", "three"], initialSelectedIndex = 1)
    check w.selectedIndex == 1
    w.checkSizes()
    let closedHeight = w.bounds.height
    # Opening the list is a layout change, not just a repaint: the dropdown is
    # drawn inside this widget's render texture, which is sized to its bounds.
    w.isOpen = true
    w.layout()
    check w.bounds.height > closedHeight
    w.checkScriptable("ComboBox")

  test "ComboBox sizes to its widest item":
    let narrow = newComboBox(items = @["a"])
    let wide = newComboBox(items = @["a", "a much longer entry than the first"])
    narrow.layout()
    wide.layout()
    check wide.bounds.width > narrow.bounds.width

  test "IconButton is square":
    let w = newIconButton(iconText = "+", size = 32.0)
    w.checkSizes()
    check w.bounds.width == 32.0
    check w.bounds.height == 32.0
    w.checkScriptable("IconButton")

  test "ListBox sizes to visibleRows":
    let w = newListBox(items = @["a", "b", "c"], itemHeight = 20.0, visibleRows = 3)
    w.checkSizes()
    check w.bounds.height == 60.0
    w.checkScriptable("ListBox")

  test "ListView sizes to visibleRows":
    let w = newListView(items = @["a", "b"], itemHeight = 24.0, visibleRows = 4)
    w.checkSizes()
    check w.bounds.height == 96.0
    w.checkScriptable("ListView")

  test "NumberInput seeds state from initialValue":
    let w = newNumberInput(initialValue = 42.0, minValue = 0.0, maxValue = 100.0)
    check w.value == 42.0
    w.checkSizes()
    w.checkScriptable("NumberInput")

  test "ScrollBar seeds state and picks a thickness per orientation":
    let vert = newScrollBar(initialValue = 25.0, vertical = true)
    check vert.value == 25.0
    vert.layout()
    check vert.bounds.width == 12.0

    let horz = newScrollBar(vertical = false)
    horz.layout()
    check horz.bounds.height == 12.0
    vert.checkScriptable("ScrollBar")

  test "Separator only claims its cross axis":
    let horz = newSeparator(vertical = false, thickness = 2.0)
    horz.layout()
    check horz.bounds.height == 2.0

    let vert = newSeparator(vertical = true, thickness = 3.0)
    vert.layout()
    check vert.bounds.width == 3.0
    horz.checkScriptable("Separator")

  test "Spinner seeds state from initialValue":
    let w = newSpinner(initialValue = 7.5, minValue = 0.0, maxValue = 10.0,
                       step = 0.5, decimals = 1)
    check w.value == 7.5
    w.checkSizes()
    check w.bounds.width > 0
    w.checkScriptable("Spinner")

  test "ToolButton reserves room for its label only when shown":
    let bare = newToolButton(iconText = "B", size = 24.0)
    let labelled = newToolButton(iconText = "B", text = "Bold",
                                 size = 24.0, showText = true)
    bare.layout()
    labelled.layout()
    check labelled.bounds.height > bare.bounds.height
    bare.checkScriptable("ToolButton")

  test "Tooltip follows the pointer":
    let w = newTooltip(text = "hint", offsetX = 10.0, offsetY = 10.0)
    w.mouseX = 100.0
    w.mouseY = 50.0
    w.layout()
    check w.bounds.x == 110.0
    check w.bounds.y == 60.0
    check w.bounds.width > 0
    w.checkScriptable("Tooltip")

suite "restored containers":

  test "Column distributes children along the main axis":
    let w = newColumn(spacing = 0.0, mainAxisAlignment = MainEnd)
    w.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    let a = newLabel(text = "a", fontSize = 14.0)
    let b = newLabel(text = "b", fontSize = 14.0)
    w.addChild(a)
    w.addChild(b)
    w.layout()
    # MainEnd pins the last child against the bottom of the content box.
    check b.bounds.y + b.bounds.height <= 200.0
    check a.bounds.y < b.bounds.y
    w.checkScriptable("Column")

  test "Column centres on the cross axis":
    let w = newColumn(crossAxisAlignment = CrossCenter)
    w.bounds = Rect(x: 0, y: 0, width: 200, height: 100)
    let child = newLabel(text = "x", fontSize = 14.0)
    w.addChild(child)
    w.layout()
    check child.bounds.x > 0

  test "GroupBox leaves room for its title":
    let w = newGroupBox(title = "Options", padding = 8.0, titleHeight = 20.0)
    let child = newLabel(text = "inside", fontSize = 14.0)
    w.addChild(child)
    w.checkSizes()
    check child.bounds.y >= w.bounds.y + 20.0
    w.checkScriptable("GroupBox")

  test "Panel insets its children by the padding":
    let w = newPanel(padding = 10.0)
    w.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    let child = newLabel(text = "x", fontSize = 14.0)
    w.addChild(child)
    w.layout()
    check child.bounds.x == 10.0
    check child.bounds.y == 10.0
    check child.bounds.width == 80.0
    w.checkScriptable("Panel")

  test "RadioGroup seeds selection and sizes to its options":
    let w = newRadioGroup(options = @["Red", "Green", "Blue"],
                          initialSelectedIndex = 2, spacing = 24.0)
    check w.selectedIndex == 2
    w.checkSizes()
    check w.bounds.height == 72.0
    w.checkScriptable("RadioGroup")

  test "Spacer falls back to its minimums":
    let w = newSpacer(minWidth = 8.0, minHeight = 16.0)
    w.checkSizes()
    check w.bounds.width == 8.0
    check w.bounds.height == 16.0
    w.checkScriptable("Spacer")

  test "StatusBar takes its height from barHeight":
    let w = newStatusBar(text = "Ready", rightText = "Ln 1", barHeight = 24.0)
    w.checkSizes()
    check w.bounds.height == 24.0
    w.checkScriptable("StatusBar")

  test "TabControl shows only the active tab":
    let w = newTabControl(tabs = @["One", "Two"], initialActiveTab = 0)
    let first = newLabel(text = "first", fontSize = 14.0)
    let second = newLabel(text = "second", fontSize = 14.0)
    w.addChild(first)
    w.addChild(second)
    w.bounds = Rect(x: 0, y: 0, width: 200, height: 150)
    w.layout()
    # Inactive children are hidden, not skipped: renderPass walks the child list
    # itself, so `visible` is the only lever a container has.
    check first.visible
    check not second.visible

    w.activeTab = 1
    w.layout()
    check not first.visible
    check second.visible
    w.checkScriptable("TabControl")

  test "ToolBar lays children out left to right":
    let w = newToolBar(barHeight = 32.0, spacing = 4.0, padding = 4.0)
    let a = newToolButton(iconText = "A", size = 24.0)
    let b = newToolButton(iconText = "B", size = 24.0)
    w.addChild(a)
    w.addChild(b)
    w.checkSizes()
    check b.bounds.x > a.bounds.x
    check a.bounds.y == b.bounds.y
    w.checkScriptable("ToolBar")

suite "restored input and menus":

  test "TextInput seeds state from initialText":
    let w = newTextInput(initialText = "hello", placeholder = "type")
    check w.text == "hello"
    w.checkSizes()
    check w.bounds.width > 0
    w.checkScriptable("TextInput")

  test "TextInput accepts a scripted write":
    let w = newTextInput()
    let res = w.handleScriptAction("write", %*{"field": "text", "value": "typed"})
    check res["success"].getBool()
    check w.text == "typed"

  test "MenuItem sizes to text plus shortcut":
    let plain = newMenuItem(text = "Save")
    let withShortcut = newMenuItem(text = "Save", shortcut = "Ctrl+S")
    plain.layout()
    withShortcut.layout()
    check withShortcut.bounds.width > plain.bounds.width
    plain.checkScriptable("MenuItem")

  test "MenuItem separator is a thin rule":
    let w = newMenuItem(separator = true)
    w.layout()
    check w.bounds.height < 24.0
    check w.bounds.height > 0

  test "Menu takes no space until it is opened":
    let w = newMenu(title = "File", minWidth = 150.0)
    let item = newMenuItem(text = "Open")
    w.addChild(item)
    w.layout()
    check w.bounds.height == 0
    check not item.visible

    w.open()
    w.layout()
    check w.bounds.height > 0
    check item.visible
    check w.bounds.width >= 150.0

    w.close()
    w.layout()
    check w.bounds.height == 0
    w.checkScriptable("Menu")

  test "MenuBar grows to cover the open dropdown":
    let bar = newMenuBar(barHeight = 28.0)
    let fileMenu = newMenu(title = "File")
    fileMenu.addChild(newMenuItem(text = "Open"))
    fileMenu.addChild(newMenuItem(text = "Quit"))
    bar.addChild(fileMenu)
    bar.layout()
    check bar.bounds.height == 28.0

    # A dropdown is a child, and renderPass composites children into the
    # parent's bounds-sized texture, so the bar has to make room for it.
    fileMenu.open()
    bar.activeMenuIndex = 0
    bar.layout()
    check bar.bounds.height > 28.0
    bar.checkScriptable("MenuBar")

  test "ContextMenu positions itself where it is opened":
    let w = newContextMenu(minWidth = 120.0)
    w.addChild(newMenuItem(text = "Cut"))
    w.layout()
    check w.bounds.height == 0

    w.openAt(40.0, 60.0)
    w.layout()
    check w.bounds.x == 40.0
    check w.bounds.y == 60.0
    check w.bounds.height > 0
    w.checkScriptable("ContextMenu")

suite "restored dialogs":

  test "file filter matches extensions, not substrings":
    check matchesAnyFilter("notes.txt", @["*.txt"])
    check not matchesAnyFilter("notes.txtx", @["*.txt"])
    check matchesAnyFilter("Notes.TXT", @["*.txt"])       # case-insensitive
    check matchesAnyFilter("anything", @[])               # no filter = accept all
    check matchesAnyFilter("anything", @["*"])
    check not matchesAnyFilter("main.nim", @["*.txt", "*.md"])
    check matchesAnyFilter("main.nim", @["*.txt", "*.nim"])

  test "listing a real directory finds this test file":
    let entries = listEntries("tests", @["*.nim"])
    check entries.len > 0
    check entries[0] == ParentEntry        # ".." always comes first
    check "test_restored_widgets.nim" in entries

  test "listing an unreadable path still offers a way out":
    let entries = listEntries("/definitely/not/a/real/path")
    check entries == @[ParentEntry]

  test "MessageBox button set decides the buttons":
    let panel = panelRect(Rect(x: 0, y: 0, width: 800, height: 600), 400, 200)
    check dialogButtons(panel, mbOK).len == 1
    check dialogButtons(panel, mbOKCancel).len == 2
    check dialogButtons(panel, mbYesNo).len == 2
    # mbYesNoCancel was an unimplemented TODO before the port.
    check dialogButtons(panel, mbYesNoCancel).len == 3

  test "MessageBox buttons are laid out right to left without overlapping":
    let panel = panelRect(Rect(x: 0, y: 0, width: 800, height: 600), 400, 200)
    let buttons = dialogButtons(panel, mbYesNoCancel)
    check buttons[0].res == mrYes
    for i in 1 ..< buttons.len:
      check buttons[i].rect.x + buttons[i].rect.width <= buttons[i - 1].rect.x
      check buttons[i].rect.y == buttons[0].rect.y

  test "MessageBox constructs and scripts":
    let w = newMessageBox(title = "Careful", message = "Sure?",
                          messageType = mbQuestion, buttons = mbYesNo)
    check w.dialogResult == mrNone
    w.checkScriptable("MessageBox")

  test "FileDialog constructs and scripts":
    let w = newFileDialog(title = "Open", mode = fdOpen, filters = @["*.nim"])
    w.checkScriptable("FileDialog")

  test "FilePicker reads its directory on first layout":
    let w = newFilePicker(mode = fpOpen, filters = @["*.nim"], initialPath = "tests")
    check w.fileList.len == 0        # nothing read yet
    w.checkSizes()
    check w.loaded
    check w.fileList.len > 0
    check w.bounds.height > 0
    w.checkScriptable("FilePicker")

suite "restored data widgets":

  test "TreeView flattens only the expanded part of the tree":
    let leaf1 = TreeNode(id: "a1", text: "Child A1")
    let leaf2 = TreeNode(id: "a2", text: "Child A2")
    let branch = TreeNode(id: "a", text: "Branch A", expanded: false,
                          children: @[leaf1, leaf2])
    let root = TreeNode(id: "root", text: "Root", expanded: true,
                        children: @[branch])

    let w = newTreeView(rootNode = root, nodeHeight = 24.0, visibleRows = 5)
    w.layout()
    check w.flatNodes.len == 2          # root + collapsed branch

    branch.expanded = true
    w.layout()
    check w.flatNodes.len == 4          # root + branch + two leaves
    check w.flatNodes[2].level == 2     # leaves sit one level under the branch
    w.checkScriptable("TreeView")

  test "TreeView tolerates a nil root":
    let w = newTreeView()
    w.checkSizes()
    check w.flatNodes.len == 0

  test "DataTable filters in layout, not in render":
    var rows: seq[TableRow] = @[]
    for name in ["apple", "banana", "avocado"]:
      var values = initTable[string, JsonNode]()
      values["name"] = %name
      rows.add(TableRow(id: name, values: values))

    let cols = @[ColumnDef(id: "name", title: "Name", width: 120.0,
                           sortable: true, filterable: true)]
    let w = newDataTable(columns = cols, data = rows)
    w.layout()
    check w.filteredIndices.len == 3

    w.filters["name"] = Filter(column: "name", kind: fkStartsWith, text: "a")
    w.layout()
    check w.filteredIndices.len == 2
    w.checkScriptable("DataTable")

  test "DataTable sorts the filtered view":
    var rows: seq[TableRow] = @[]
    for name in ["cherry", "apple", "banana"]:
      var values = initTable[string, JsonNode]()
      values["name"] = %name
      rows.add(TableRow(id: name, values: values))

    let cols = @[ColumnDef(id: "name", title: "Name", width: 120.0, sortable: true)]
    let w = newDataTable(columns = cols, data = rows)
    w.sortColumn = "name"
    w.sortOrder = soAscending
    w.layout()
    check w.data[w.filteredIndices[0]].id == "apple"
    check w.data[w.filteredIndices[2]].id == "cherry"

    w.sortOrder = soDescending
    w.layout()
    check w.data[w.filteredIndices[0]].id == "cherry"

  test "DataGrid sorts by column index":
    let cols = @[GridColumn(id: "n", title: "N", width: 80.0, sortable: true)]
    let rows = @[
      GridRow(id: "r1", values: @[%3]),
      GridRow(id: "r2", values: @[%1]),
      GridRow(id: "r3", values: @[%2]),
    ]
    let w = newDataGrid(columns = cols, data = rows)
    w.layout()
    check w.order == @[0, 1, 2]        # untouched while unsorted

    w.sortColumn = 0
    w.sortOrder = soAscending
    w.layout()
    check w.data[w.order[0]].id == "r2"
    check w.data[w.order[2]].id == "r1"
    w.checkScriptable("DataGrid")

  test "DataGrid leaves a lazily-loaded set unsorted":
    let cols = @[GridColumn(id: "n", title: "N", width: 80.0, sortable: true)]
    let rows = @[GridRow(id: "r1", values: @[%3]), GridRow(id: "r2", values: @[%1])]
    # Only two of a claimed hundred rows are in memory: sorting them would order
    # the visible slice and silently mis-order everything still to be fetched.
    let w = newDataGrid(columns = cols, data = rows, totalRowCount = 100)
    w.sortColumn = 0
    w.sortOrder = soAscending
    w.layout()
    check w.order == @[0, 1]

suite "restored modern widgets":

  test "Canvas records commands in canvas-relative coordinates":
    let w = newCanvas(enableDrawing = true, drawingMode = dmLine)
    w.bounds = Rect(x: 50, y: 50, width: 200, height: 200)
    w.addCommand(DrawCommand(kind: dcLine,
                             lineStart: Point(x: 0, y: 0),
                             lineEnd: Point(x: 10, y: 10),
                             lineColor: BLACK, lineThickness: 1.0))
    check w.commands.len == 1
    # Relative, so moving the canvas does not drag its contents along.
    check w.commands[0].lineStart.x == 0.0
    w.clearCanvas()
    check w.commands.len == 0
    w.checkSizes()
    w.checkScriptable("Canvas")

  test "DragDropArea constructs and sizes":
    let w = newDragDropArea(mode = dmFiles, acceptedExtensions = @[".nim"])
    w.checkSizes()
    check w.bounds.width > 0
    check w.lastDroppedFiles.len == 0
    w.checkScriptable("DragDropArea")

  test "Timeline maps time to pixels and back":
    let start = dateTime(2026, mJan, 1, 0, 0, 0, zone = utc())
    let stop = start + initDuration(hours = 12)
    let w = newTimeline(events = @[], startTime = start, endTime = stop,
                        scale = tsHour, pixelsPerUnit = 60.0)
    w.bounds = Rect(x: 0, y: 0, width: 600, height: 200)
    w.layout()

    let axis = w.axis()
    # One hour in at 60px per hour.
    check abs(axis.timeToPixel(start + initDuration(hours = 1)) - 60.0) < 0.5
    let roundTrip = axis.pixelToTime(axis.timeToPixel(start + initDuration(hours = 3)))
    check abs((roundTrip - (start + initDuration(hours = 3))).inSeconds) <= 1
    w.checkScriptable("Timeline")

  test "Timeline event rects match what hit-testing will use":
    let start = dateTime(2026, mJan, 1, 0, 0, 0, zone = utc())
    let evt = TimelineEvent(id: "e1", title: "Build",
                            startTime: start + initDuration(hours = 1),
                            endTime: start + initDuration(hours = 3),
                            color: BLUE, isDuration: true)
    let w = newTimeline(events = @[evt], startTime = start,
                        endTime = start + initDuration(hours = 12),
                        scale = tsHour, pixelsPerUnit = 60.0)
    w.bounds = Rect(x: 0, y: 0, width: 600, height: 200)
    w.layout()

    let r = w.axis().eventRectFor(0, evt)
    check abs(r.x - 60.0) < 0.5          # starts one hour in
    check abs(r.width - 120.0) < 0.5     # two hours wide

  test "MapWidget seeds its view from the initial props":
    # The DSL's initialX convention does this in the constructor: initialZoom
    # seeds zoom, initialCenter seeds center. No layout pass required.
    let w = newMapWidget(initialCenter = MapCoord(lat: 51.5, lon: -0.12),
                         initialZoom = 5.0)
    check w.zoom == 5.0
    check w.center.lat == 51.5
    w.checkSizes()
    check w.bounds.width > 0
    w.checkScriptable("MapWidget")

  test "MapWidget projects the centre to the middle of itself":
    let w = newMapWidget(initialCenter = MapCoord(lat: 0.0, lon: 0.0),
                         initialZoom = 3.0)
    w.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    w.layout()
    let p = w.view().worldToScreen(w.center)
    check abs(p.x - 200.0) < 0.5
    check abs(p.y - 150.0) < 0.5

  test "MapWidget screen/world round trip":
    let w = newMapWidget(initialCenter = MapCoord(lat: 40.0, lon: -74.0),
                         initialZoom = 6.0)
    w.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    w.layout()
    let view = w.view()
    let coord = view.screenToWorld(250.0, 180.0)
    let back = view.worldToScreen(coord)
    check abs(back.x - 250.0) < 0.5
    check abs(back.y - 180.0) < 0.5

  test "MapWidget clamps latitude out of Mercator's range":
    let w = newMapWidget(initialZoom = 2.0)
    w.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    w.layout()
    # tan() diverges at the poles; the projection has to stay finite there.
    let p = w.view().worldToScreen(MapCoord(lat: 90.0, lon: 0.0))
    check p.y == p.y                     # not NaN
    check abs(p.y) < 1.0e9

suite "restored widgets answer the scripting bridge":

  test "every restored widget reports its own type name":
    let start = dateTime(2026, mJan, 1, 0, 0, 0, zone = utc())
    let widgets: seq[(Widget, string)] = @[
      (Widget(newComboBox()), "ComboBox"),
      (Widget(newIconButton(iconText = "x")), "IconButton"),
      (Widget(newListBox()), "ListBox"),
      (Widget(newListView()), "ListView"),
      (Widget(newNumberInput()), "NumberInput"),
      (Widget(newScrollBar()), "ScrollBar"),
      (Widget(newSeparator()), "Separator"),
      (Widget(newSpinner()), "Spinner"),
      (Widget(newToolButton(iconText = "x")), "ToolButton"),
      (Widget(newTooltip(text = "x")), "Tooltip"),
      (Widget(newColumn()), "Column"),
      (Widget(newGroupBox(title = "x")), "GroupBox"),
      (Widget(newPanel()), "Panel"),
      (Widget(newRadioGroup(options = @["x"])), "RadioGroup"),
      (Widget(newSpacer()), "Spacer"),
      (Widget(newStatusBar(text = "x")), "StatusBar"),
      (Widget(newTabControl(tabs = @["x"])), "TabControl"),
      (Widget(newToolBar()), "ToolBar"),
      (Widget(newTextInput()), "TextInput"),
      (Widget(newMenuItem(text = "x")), "MenuItem"),
      (Widget(newMenu(title = "x")), "Menu"),
      (Widget(newMenuBar()), "MenuBar"),
      (Widget(newContextMenu()), "ContextMenu"),
      (Widget(newMessageBox(message = "x")), "MessageBox"),
      (Widget(newFileDialog()), "FileDialog"),
      (Widget(newFilePicker()), "FilePicker"),
      (Widget(newTreeView()), "TreeView"),
      (Widget(newDataTable()), "DataTable"),
      (Widget(newDataGrid()), "DataGrid"),
      (Widget(newCanvas()), "Canvas"),
      (Widget(newDragDropArea()), "DragDropArea"),
      (Widget(newTimeline(startTime = start,
                          endTime = start + initDuration(hours = 1))), "Timeline"),
      (Widget(newMapWidget()), "MapWidget"),
    ]
    # 33 of the 35: datatable_helpers is pure logic, and Image was never deleted.
    check widgets.len == 33
    for (w, name) in widgets:
      check w.getTypeName() == name
      check w.getScriptableState()["type"].getStr() == name

  test "every restored widget is born visible and enabled":
    # Generated constructors used to skip the inherited Widget fields, so every
    # widget was born invisible and renderPass silently skipped it.
    let widgets: seq[Widget] = @[
      Widget(newComboBox()), Widget(newListBox()), Widget(newTreeView()),
      Widget(newTextInput()), Widget(newPanel()), Widget(newCanvas()),
      Widget(newMenuBar()), Widget(newDataGrid()),
    ]
    for w in widgets:
      check w.visible
      check w.enabled
      check w.isDirty
