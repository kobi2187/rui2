## Tutorial 3 -- a data app: a table you can search, and a chart of what is in it.
##
##   nim c -r -d:useGraphics examples/tutorial/data_app.nim

import rui
import std/[json, tables, strutils, options]

# The data: people and their team. A DataRow is an id and its values by column.
var rows: seq[DataRow]
for (name, team, score) in [("Ada", "Engines", 9), ("Grace", "Compilers", 10),
                            ("Alan", "Engines", 8), ("Edsger", "Compilers", 7),
                            ("Barbara", "Compilers", 9), ("Margaret", "Engines", 10)]:
  var values = initTable[string, JsonNode]()
  values["name"] = %name
  values["team"] = %team
  values["score"] = %score
  rows.add DataRow(id: name, values: values)

# How many people per team, as the points of a bar series.
proc teamCounts(): seq[tuple[x, y: float]] =
  var engines, compilers = 0
  for r in rows:
    if r.values["team"].getStr == "Engines": inc engines else: inc compilers
  @[(0.0, float(engines)), (1.0, float(compilers))]

var table: DataTable
var search: TextInput
let query = newLink("")

let root = ui:
  Padding(padding = EdgeInsets.all(16.0)):
    Column(spacing = 10.0, crossAxisAlignment = CrossAxisAlignment.stretch):
      search = TextInput(placeholder = "Search names...")
      Expanded():
        # Two panes with a draggable divider between them.
        SplitView(axis = Axis.horizontal, initialRatio = 0.6):
          table = DataTable(
            columns = @[
              DataColumn(id: "name", title: "Name", width: 140.0, sortable: true),
              DataColumn(id: "team", title: "Team", width: 130.0, sortable: true),
              DataColumn(id: "score", title: "Score", width: 80.0, sortable: true)],
            data = rows, visibleRows = 8, showFilter = false)
          Plot(title = "People per team", xLabels = @["Engines", "Compilers"],
               series = @[barSeries("people", teamCounts())])

# Typing in the search box filters the table: a "contains" filter on the name.
search.onChange = proc(text: string) =
  if text.len == 0:
    table.filters.del("name")
  else:
    table.filters["name"] = Filter(column: "name", kind: fkContains, text: text)
  table.layoutDirty = true

let app = newApp("People", 760, 440)
app.setRootWidget(root)
app.run()
