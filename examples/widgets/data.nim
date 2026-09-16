## Data widgets
##
## TreeView with expand/collapse, DataTable with a filter and click-to-sort
## headers, and DataGrid over a larger set.
##
## All three only draw the rows that are on screen, and all three decide what to
## show in `layout` rather than in `render`.
##
##   nim c -r -d:useGraphics examples/widgets/data.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, json, tables, sets, strutils]

let app = newApp("RUI2 - Data widgets", 760, 620)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 16.0).named("root")
let summary = newLabel(text = "nothing selected", fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

# TreeView -----------------------------------------------------------------
root.addChild(newLabel(text = "TreeView (click the arrow to expand):",
                       fontSize = 14.0).named("t1"))
let tree = TreeNode(id: "root", text: "project", expanded: true, children: @[
  TreeNode(id: "src", text: "src", expanded: true, children: @[
    TreeNode(id: "main", text: "main.nim"),
    TreeNode(id: "util", text: "util.nim"),
  ]),
  TreeNode(id: "tests", text: "tests", expanded: false, children: @[
    TreeNode(id: "t1", text: "test_one.nim"),
    TreeNode(id: "t2", text: "test_two.nim"),
  ]),
  TreeNode(id: "readme", text: "README.md"),
])
let treeView = newTreeView(rootNode = tree, nodeHeight = 22.0,
                           visibleRows = 6).named("tree")
treeView.bounds = Rect(x: 0, y: 0, width: 300, height: 132)
treeView.onSelect = some(proc(nodeId: string) {.closure.} =
  report("tree -> " & nodeId))
root.addChild(treeView)

# DataTable ----------------------------------------------------------------
root.addChild(newLabel(text = "DataTable (click a header to sort):",
                       fontSize = 14.0).named("t2"))
var tableRows: seq[TableRow] = @[]
for (name, role) in [("ada", "engineer"), ("grace", "admiral"),
                     ("alan", "engineer"), ("edsger", "professor"),
                     ("barbara", "engineer")]:
  var values = initTable[string, JsonNode]()
  values["name"] = %name
  values["role"] = %role
  tableRows.add(TableRow(id: name, values: values))

let table = newDataTable(
  columns = @[
    ColumnDef(id: "name", title: "Name", width: 160.0,
              sortable: true, filterable: true),
    ColumnDef(id: "role", title: "Role", width: 200.0,
              sortable: true, filterable: true),
  ],
  data = tableRows, rowHeight = 22.0, visibleRows = 5).named("table")
table.bounds = Rect(x: 0, y: 0, width: 360, height: 0)

# Filters are set from code; the strip shows what is active.
table.filters["role"] = Filter(column: "role", kind: fkContains, text: "engineer")

table.onSort = some(proc(column: string, order: SortOrder) {.closure.} =
  report("sort " & column & " " & $order))
table.onSelect = some(proc(selected: HashSet[int]) {.closure.} =
  var picked: seq[string] = @[]
  for idx in selected:
    picked.add(tableRows[idx].id)
  report("table -> " & picked.join(", ")))
root.addChild(table)

# DataGrid -----------------------------------------------------------------
root.addChild(newLabel(text = "DataGrid (1000 rows, click a header to sort):",
                       fontSize = 14.0).named("t3"))
var gridRows: seq[GridRow] = @[]
for i in 0 ..< 1000:
  gridRows.add(GridRow(id: "g" & $i, values: @[%i, %("item " & $i), %(i * i)]))

let grid = newDataGrid(
  columns = @[
    GridColumn(id: "n", title: "#", width: 70.0, sortable: true),
    GridColumn(id: "label", title: "Label", width: 200.0, sortable: true),
    GridColumn(id: "sq", title: "Square", width: 120.0, sortable: true),
  ],
  data = gridRows, rowHeight = 22.0, visibleRows = 6).named("grid")
grid.onSort = some(proc(column: int, order: SortOrder) {.closure.} =
  report("grid sort col " & $column & " " & $order))
root.addChild(grid)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
