## RowSource: where a list or table gets its rows.
##
## A ListView or DataTable does not hold its data; it asks a source, and only
## for the rows it is about to draw. The source may be a seq in memory, a file
## of a hundred million lines, a CSV, a SQLite query: the widget cannot tell, and
## nothing is copied into it.
##
## Three things make that work at scale:
##
## - **Pull, by row and column.** `cell(row, col)` returns text; `count` says how
##   many rows there are. `want(first, last)` tells the source which rows are
##   about to be drawn, so a source that has to go and get them (a disk, a
##   database) can start before the frame needs them.
## - **Never wait.** A row that has not arrived is `rsPending`: the widget draws
##   it as a placeholder in the theme's disabled colours and moves on. When the
##   row lands the source calls `poll` on the main thread, which tells its
##   listeners, which repaint. A frame never blocks on a source.
## - **Edits are positions.** A source reports change as `SeqChange` (insert,
##   remove, move, replace, reset), the same record LinkSeq uses, so selection,
##   focus and scroll follow an edit without the widget knowing what changed.
##
## Sources that fetch in the background register a poller (rui_core/pollers) while
## anything listens to them, and unregister when the last listener goes.

import std/[tables, json]
import rui_core
import column_page

type
  RowState* = enum
    rsReady     ## the row's text is here
    rsPending   ## the row exists but has not arrived yet

  SortDir* = enum sdNone, sdAscending, sdDescending

  FilterOp* = enum foContains, foStartsWith, foEndsWith, foEquals, foGreater, foLess,
                   foGreaterEq, foLessEq

  ColumnFilter* = object
    column*: string
    op*: FilterOp
    text*: string      ## the operand as typed; numeric ops read it as a number

  RowSource* = ref object of RootObj
    listeners: seq[tuple[id: ListenerId, call: proc(change: SeqChange) {.closure.}]]
    nextListener: ListenerId
    pollerId: int
    polling: bool

# ---------------------------------------------------------------------------
# What a source answers (override these)

method count*(s: RowSource): int {.base.} = 0
  ## How many rows there are (so far, for a source still counting).

method columns*(s: RowSource): seq[string] {.base.} = @["value"]
  ## The column names.

method cell*(s: RowSource, row, col: int): string {.base.} = ""
  ## The text of a cell; "" when the row is pending.

method rowState*(s: RowSource, row: int): RowState {.base.} = rsReady

method want*(s: RowSource, first, last: int) {.base.} = discard
  ## The rows about to be drawn (inclusive): fetch them if they are not here.

method poll*(s: RowSource): bool {.base.} = false
  ## Main thread: take in whatever the background has fetched, tell the
  ## listeners, and say whether anything changed.

method busy*(s: RowSource): bool {.base.} = false
  ## Still counting or fetching (a progress hint; not needed for correctness).

method canSort*(s: RowSource): bool {.base.} = false
method sortBy*(s: RowSource, column: string, dir: SortDir) {.base.} = discard
method canFilter*(s: RowSource): bool {.base.} = false
method setFilters*(s: RowSource, filters: seq[ColumnFilter]) {.base.} = discard
  ## Sorting and filtering are the source's to do (a database can; a file cannot
  ## cheaply). Both end in a `scReset`: the rows shown are now different rows.

method close*(s: RowSource) {.base.} = discard
  ## Stop background work and release files and connections.

# ---------------------------------------------------------------------------
# Derived

proc text*(s: RowSource, row: int): string = s.cell(row, 0)
  ## One-column view: a ListView's row.

proc row*(s: RowSource, i: int): seq[string] =
  for c in 0 ..< s.columns.len: result.add s.cell(i, c)

proc columnIndex*(s: RowSource, name: string): int =
  ## Index of the named column, or -1.
  let names = s.columns
  for i, n in names:
    if n == name: return i
  -1

# `%` so the scripting bridge reports a source as a short summary instead of
# trying to serialise the data behind it.
proc `%`*(s: RowSource): JsonNode =
  if s == nil: newJNull() else: %*{"rows": s.count, "columns": s.columns}

# ---------------------------------------------------------------------------
# Listening

proc listen*(s: RowSource, call: proc(change: SeqChange) {.closure.}): ListenerId =
  inc s.nextListener
  s.listeners.add (s.nextListener, call)
  if not s.polling:
    s.polling = true
    s.pollerId = addPoller(proc(): bool = s.poll())
  s.nextListener

proc unlisten*(s: RowSource, id: ListenerId) =
  for i in countdown(s.listeners.high, 0):
    if s.listeners[i].id == id: s.listeners.delete(i)
  if s.listeners.len == 0 and s.polling:
    s.polling = false
    removePoller(s.pollerId)

proc listenerCount*(s: RowSource): int = s.listeners.len

proc notify*(s: RowSource, change: SeqChange) =
  for listener in s.listeners: listener.call(change)

proc attach*(s: RowSource, widget: Widget, call: proc(change: SeqChange) {.closure.}) =
  ## `listen` for a widget: it is marked dirty after each change, and listening
  ## stops when it is disposed.
  let id = s.listen(proc(change: SeqChange) =
    call(change)
    widget.layoutDirty = true
    widget.markDirtyToRoot())
  widget.disposers.add proc() = s.unlisten(id)
