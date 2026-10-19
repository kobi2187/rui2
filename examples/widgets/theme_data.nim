## Theme data widgets
##
## The data and picker widgets a theme also has to draw -- a sortable table with
## its header, a date picker, a colour picker, badges, a rating and a card -- on
## one screen, for comparing themes:
##
##   nim c -r -d:useGraphics examples/widgets/theme_data.nim [theme]

import rui
import std/[os, json, tables]

let app = newApp("RUI2 - Theme data widgets", 1000, 620)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "beos")

var rows: seq[DataRow]
for (name, team, score) in [("Ada", "Engines", 9), ("Grace", "Compilers", 10),
                            ("Alan", "Engines", 8), ("Edsger", "Compilers", 7),
                            ("Barbara", "Compilers", 9)]:
  var values = initTable[string, JsonNode]()
  values["name"] = %name
  values["team"] = %team
  values["score"] = %score
  rows.add DataRow(id: name, values: values)

let root = ui:
  VStack(padding = 16.0):
    Row(spacing = 28.0, crossAxisAlignment = CrossAxisAlignment.start):
      VStack(spacing = 12.0):
        Label(text = "Table", bold = true)
        DataTable(
          columns = @[
            DataColumn(id: "name", title: "Name", width: 120.0, sortable: true),
            DataColumn(id: "team", title: "Team", width: 120.0, sortable: true),
            DataColumn(id: "score", title: "Score", width: 70.0, sortable: true)],
          data = rows, visibleRows = 5, showFilter = false)
        Label(text = "Badges and rating", bold = true)
        Row(spacing = 10.0):
          Badge(text = "3")
          Badge(text = "New", intent = ThemeIntent.Info)
          Badge(text = "OK", intent = ThemeIntent.Success)
          Badge(text = "Late", intent = ThemeIntent.Warning)
        Rating(initialValue = 3)
      VStack(spacing = 12.0):
        Label(text = "Pickers", bold = true)
        DatePicker(initialValue = "2026-10-19")
        ColorPicker(initialValue = "#3366cc")
        Label(text = "Card", bold = true)
        Card():
          Label(text = "A card holds related content")

app.setRootWidget(root)
app.run()
