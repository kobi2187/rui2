## LinkSeq[T]: a list that says *what* changed.
##
## A `Link[seq[T]]` can only say "something changed", so every widget showing it
## starts again: selection, focus and scroll position are lost, and a thousand
## rows are rebuilt for one insertion. A LinkSeq reports each edit as it
## happens -- inserted here, removed there, this one moved -- so a widget can
## apply the same edit to what it shows and keep its selection on the row the
## user had selected.
##
## ```nim
## let todos = newLinkSeq(@["write", "test"])
## list.bindItems(todos)           # ListView / ListBox (rui_widgets)
## todos.add "ship"                # one row appended; selection and scroll stay
## todos.delete 0                  # selection follows its row
## ```
##
## The change record carries positions only, never the values, so a listener
## needs no knowledge of T. `remap` says where an old index went, which is all a
## widget needs to carry its selection, focus and hover across an edit.

import std/[sets, algorithm]
import types

type
  SeqChangeKind* = enum
    scInsert    ## `count` items now at `index`
    scRemove    ## `count` items that were at `index` are gone
    scMove      ## the item that was at `index` is now at `to`
    scReplace   ## the item at `index` has a new value; positions are unchanged
    scReset     ## everything is new: the old positions mean nothing

  SeqChange* = object
    kind*: SeqChangeKind
    index*: int
    to*: int
    count*: int

  ListenerId* = int

  LinkSeq*[T] = ref object
    items: seq[T]
    listeners: seq[tuple[id: ListenerId, call: proc(change: SeqChange) {.closure.}]]
    nextId: ListenerId
    dependentWidgets: HashSet[Widget]
    announcing: bool

proc newLinkSeq*[T](initial: seq[T] = @[]): LinkSeq[T] =
  LinkSeq[T](items: initial, dependentWidgets: initHashSet[Widget]())

# ---------------------------------------------------------------------------
# Reading

proc len*[T](s: LinkSeq[T]): int = s.items.len
proc `[]`*[T](s: LinkSeq[T], i: int): T = s.items[i]
proc toSeq*[T](s: LinkSeq[T]): seq[T] = s.items
iterator items*[T](s: LinkSeq[T]): T =
  for item in s.items: yield item
proc contains*[T](s: LinkSeq[T], value: T): bool = value in s.items
proc find*[T](s: LinkSeq[T], value: T): int = s.items.find(value)

# ---------------------------------------------------------------------------
# Listening

proc listen*[T](s: LinkSeq[T], call: proc(change: SeqChange) {.closure.}): ListenerId =
  ## Run `call` after every edit. Returns the id to `unlisten` with.
  inc s.nextId
  s.listeners.add (s.nextId, call)
  s.nextId

proc unlisten*[T](s: LinkSeq[T], id: ListenerId) =
  for i in countdown(s.listeners.high, 0):
    if s.listeners[i].id == id: s.listeners.delete(i)

proc listenerCount*[T](s: LinkSeq[T]): int = s.listeners.len

proc attach*[T](s: LinkSeq[T], widget: Widget,
                call: proc(change: SeqChange) {.closure.}) =
  ## `listen`, for a widget: the widget is marked dirty after each edit, and
  ## when it is disposed the listener goes with it.
  s.dependentWidgets.incl widget
  let id = s.listen(call)
  widget.disposers.add proc() =
    s.unlisten(id)
    s.dependentWidgets.excl widget

proc dependentCount*[T](s: LinkSeq[T]): int = s.dependentWidgets.len

proc announce[T](s: LinkSeq[T], change: SeqChange) =
  for widget in s.dependentWidgets:
    widget.layoutDirty = true
    if widget.parent != nil: widget.parent.layoutDirty = true
    widget.markDirtyToRoot()
  # A copy: a listener may unlisten (or attach another) while we iterate.
  for listener in s.listeners:
    listener.call(change)

# ---------------------------------------------------------------------------
# Editing

proc insert*[T](s: LinkSeq[T], index: int, value: T) =
  s.items.insert(value, index)
  s.announce SeqChange(kind: scInsert, index: index, count: 1)

proc insertAll*[T](s: LinkSeq[T], index: int, values: openArray[T]) =
  if values.len == 0: return
  for i, v in values: s.items.insert(v, index + i)
  s.announce SeqChange(kind: scInsert, index: index, count: values.len)

proc add*[T](s: LinkSeq[T], value: T) = s.insert(s.items.len, value)

proc delete*[T](s: LinkSeq[T], index: int) =
  s.items.delete(index)
  s.announce SeqChange(kind: scRemove, index: index, count: 1)

proc deleteRange*[T](s: LinkSeq[T], index, count: int) =
  if count <= 0: return
  for _ in 0 ..< count: s.items.delete(index)
  s.announce SeqChange(kind: scRemove, index: index, count: count)

proc move*[T](s: LinkSeq[T], fromIndex, toIndex: int) =
  ## Take the item at `fromIndex` and put it at `toIndex` (its index afterwards).
  if fromIndex == toIndex: return
  let value = s.items[fromIndex]
  s.items.delete(fromIndex)
  s.items.insert(value, toIndex)
  s.announce SeqChange(kind: scMove, index: fromIndex, to: toIndex, count: 1)

proc `[]=`*[T](s: LinkSeq[T], index: int, value: T) =
  if s.items[index] == value: return
  s.items[index] = value
  s.announce SeqChange(kind: scReplace, index: index, count: 1)

proc reset*[T](s: LinkSeq[T], values: seq[T]) =
  ## Replace everything. Listeners are told their old positions are void.
  s.items = values
  s.announce SeqChange(kind: scReset)

proc clear*[T](s: LinkSeq[T]) = s.reset(@[])

# ---------------------------------------------------------------------------
# Carrying positions across an edit

proc remap*(change: SeqChange, i: int): int =
  ## Where the item that was at index `i` is after `change`; -1 when it is gone.
  case change.kind
  of scInsert:
    if i >= change.index: i + change.count else: i
  of scRemove:
    if i < change.index: i
    elif i < change.index + change.count: -1
    else: i - change.count
  of scMove:
    if i == change.index: change.to
    elif change.index < change.to and i > change.index and i <= change.to: i - 1
    elif change.index > change.to and i >= change.to and i < change.index: i + 1
    else: i
  of scReplace: i
  of scReset: -1

proc remap*(change: SeqChange, indices: HashSet[int]): HashSet[int] =
  ## `remap` for a selection: items that are gone drop out.
  result = initHashSet[int]()
  for i in indices:
    let moved = change.remap(i)
    if moved >= 0: result.incl moved

proc apply*[T](change: SeqChange, items: var seq[T], source: LinkSeq[T]) =
  ## Make `items` (a widget's copy) follow `source` by doing the same edit,
  ## rather than copying the whole list.
  case change.kind
  of scInsert:
    for k in 0 ..< change.count: items.insert(source[change.index + k], change.index + k)
  of scRemove:
    for _ in 0 ..< change.count: items.delete(change.index)
  of scMove:
    let value = items[change.index]
    items.delete(change.index)
    items.insert(value, change.to)
  of scReplace:
    items[change.index] = source[change.index]
  of scReset:
    items = source.toSeq
