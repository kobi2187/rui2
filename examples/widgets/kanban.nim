## KanbanBoard: columns of cards; drag a card to another column or position.
##
##   nim c -r -d:useGraphics examples/widgets/kanban.nim [theme]
##
## Drag with the mouse. The label under the board reports each move.

import rui
import std/[os, strformat]

let app = newApp("RUI2 - Kanban", 780, 520)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

var board: KanbanBoard
var status: Label

let root = ui:
  VStack(spacing = 12.0, padding = 16.0):
    board = KanbanBoard(columns = @[
      column("Todo",
             card("t1", "Write the docs", "docs/preferences.md", "docs"),
             card("t2", "Cull off-screen widgets", "10k widgets in 4 ms"),
             card("t3", "Colour scheme at startup"),
             card("t4", "Keyboard help overlay", "list the bindings", "ux")),
      column("Doing",
             card("t5", "KanbanBoard", "this one", "widget")),
      column("Done",
             card("t6", "Plot", "lines, areas, bars", "widget"),
             card("t7", "Preferences file", "", "ux"))]).frame(height = 400)
    status = Label(text = "Drag a card.", fontSize = 13.0)

board.onMove = proc(id: string, fromColumn, toColumn, toIndex: int) =
  status.text = &"moved {id}: column {fromColumn} -> {toColumn}, slot {toIndex}"
board.onCardClick = proc(id: string) =
  status.text = &"clicked {id}"

app.setRootWidget(root)
app.run()
