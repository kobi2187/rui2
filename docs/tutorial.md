# Tutorial

Three small programs, each a complete app you can run. Every line of code below
is the real file in `examples/tutorial/` (a test keeps them identical), and
every one is built with the rest of the examples, so none of it goes stale.

```bash
nim c -r -d:useGraphics examples/tutorial/counter.nim
```

The ideas are few and they repeat: **state is a `Link`**, **the tree is written
with `ui:`**, **a widget never says where it goes** (its container does), and
**the look is the theme's**, not the widget's.

## 1. A counter

State, a tree, a binding.

<!-- file: examples/tutorial/counter.nim -->
```nim
## Tutorial 1 -- a counter: state, a tree, a binding.
##
##   nim c -r -d:useGraphics examples/tutorial/counter.nim

import rui

# State is a Link: a value that tells whoever shows it when it changes.
let count = newLink(0)

var shown: Label

# `ui:` writes the widget tree the way it reads: a capitalised call is a widget,
# an indented block is its children, and `name =` keeps a handle on one.
let root = ui:
  Center():
    Column(spacing = 12.0, mainAxisSize = MainAxisSize.min):
      shown = Label(text = "", fontSize = 28.0, bold = true)
      Row(spacing = 8.0, mainAxisSize = MainAxisSize.min):
        Button(text = "-", onClick = proc() = count.set(count.get() - 1)).shortcut("Down")
        Button(text = "+", intent = ThemeIntent.Info,
               onClick = proc() = count.set(count.get() + 1)).shortcut("Up")

# Show the link in the label: whenever it changes, this runs and the label
# repaints. Nothing else is needed.
count.bindTo(shown, proc(v: int) = shown.text = "Count: " & $v)

let app = newApp("Counter", 360, 220)
app.setRootWidget(root)
app.run()
```

- `newLink(0)` is a value that knows who is showing it. `count.set(...)` changes
  it; anything bound to it updates.
- In `ui:`, a capitalised call is a widget and an indented block is its
  children. It is only sugar over constructors (`newColumn(...)`, `addChild`),
  so you can drop it for a part of the tree and nothing else changes.
- `Center`, `Column` and `Row` are Flutter's: `mainAxisSize`, `spacing` and
  `crossAxisAlignment` mean what they mean there. You never write a position.
- `.shortcut("Up")` makes a key press the button, and is what the help overlay
  (F1 or `?`) shows beside it.

## 2. A form

Inputs, a derived value, a layout that sizes itself.

<!-- file: examples/tutorial/form.nim -->
```nim
## Tutorial 2 -- a form: inputs, a derived value, layout.
##
##   nim c -r -d:useGraphics examples/tutorial/form.nim

import rui

# One Link per field, and a value derived from them: it recomputes whenever
# either changes, and tells its own dependents only when its answer does.
let name = newLink("")
let email = newLink("")
let valid = derive(name, email, proc(n, e: string): bool =
  n.len > 0 and '@' in e)

var nameInput, emailInput: TextInput
var submit: Button
var message: Label

let root = ui:
  Padding(padding = EdgeInsets.all(24.0)):
    Column(spacing = 12.0, crossAxisAlignment = CrossAxisAlignment.stretch):
      Label(text = "Sign up", fontSize = 24.0, bold = true)

      # A Table sizes its first column to its labels and gives the rest to the
      # inputs -- the usual form layout, with no widths written down.
      Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
            columnSpacing = 12.0, rowSpacing = 10.0):
        TableRow():
          Label(text = "Name")
          nameInput = TextInput(placeholder = "Ada Lovelace")
        TableRow():
          Label(text = "Email")
          emailInput = TextInput(placeholder = "ada@example.com")
        TableRow():
          Label(text = "Plan")
          ComboBox(items = @["Starter", "Team", "Enterprise"], initialSelectedIndex = 0)

      Checkbox(text = "Email me updates", initialChecked = true)

      Row(mainAxisAlignment = MainAxisAlignment.end):
        submit = Button(text = "Create account", intent = ThemeIntent.Info,
                        onClick = proc() = message.text = "Welcome, " & name.get() & "!")
      message = Label(text = "", fontSize = 14.0)

# Inputs write to their links; the button follows `valid`.
nameInput.onChange = proc(t: string) = name.set(t)
emailInput.onChange = proc(t: string) = email.set(t)
valid.bindTo(submit, proc(ok: bool) = submit.disabled = not ok)

let app = newApp("Sign up", 520, 420)
app.setRootWidget(root)
app.run()
```

- `derive(name, email, proc ...)` is a `Link` computed from other links. It only
  tells its dependents when its *answer* changes, so typing a second letter in
  an already-valid name repaints nothing.
- `Table` with `IntrinsicColumnWidth()` and `FlexColumnWidth()` is the form
  layout: labels take what they need, inputs take the rest. `Expanded`,
  `Flexible`, `Spacer`, `Padding`, `SizedBox`, `Align`, `Stack`... follow Flutter.
- A widget asks for a size with a modifier (`.frame(width = 300)`, `.flex()`);
  it never sets `bounds`.

## 3. A data app

A searchable table beside a chart, with a draggable divider.

<!-- file: examples/tutorial/data_app.nim -->
```nim
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
```

- `DataTable` draws only the rows on screen, sorts when you click a header, and
  filters by `filters[column]`; `fkContains` is a case-insensitive substring.
- `Plot` takes series (`lineSeries`, `areaSeries`, `barSeries`,
  `scatterSeries`) and picks round axes itself.
- `SplitView` puts two children side by side (or stacked) with a divider the
  user drags; `Expanded` gives it the room left over.

## Where next

- **Make it yours:** [themes.md](themes.md) -- colours, fonts *and* stroke
  widths, radii, shadows and sizes; fat or lean from one `brand:` section.
- **How people use it:** [preferences.md](preferences.md) -- the keys, motion
  and scroll speed belong to the user, one file for every RUI app.
- **What is there:** `examples/widgets/` has one runnable file per widget
  family; `docs/PERFORMANCE.md` says what it costs.
