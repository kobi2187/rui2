# packages/rui_widgets/src/basic/listbox.nim

## Purpose

Single or multi-select list with **keyboard navigation** — the keyboard-driven
sibling of ListView. Keeps a focus row that arrow keys move and Enter
activates. Virtual rendering and lazy loading, like ListView.

## Public interface

- `newListBox*(items: seq[string] = @[], totalItemCount = -1, itemHeight = 20.0,
  visibleRows = 8, multiSelect = false, disabled = false, intent = Default,
  onSelect, onItemActivate, onLoadMore, onScrollNearEnd)`.
- `totalItems*(widget)` — rows the list *claims* to have, which with lazy
  loading exceeds `items.len`.
- `viewportOf*(widget): RowViewport` — the scrollable body.
- State: `selection: HashSet[int]`, `focusIndex`, `hoverIndex`, `scrollY`.
- Re-exports `virtual_rows` and `list_input`.

Keys: Up, Down, Home, End, PageUp, PageDown move the focus and scroll it into
view; Enter / KpEnter / Space activate the focused row. Any other key is left
**unhandled**, so it bubbles rather than being swallowed.

## Usage pattern

```nim
let box = newListBox(items = @["alpha", "beta", "gamma"],
                     itemHeight = 20.0, visibleRows = 4)
box.onItemActivate = some(proc(index: int) {.closure.} = ...)

# Lazy loading: claim the size, fill in as asked.
let big = newListBox(items = firstPage, totalItemCount = 1_000_000)
big.onLoadMore = some(proc(startIndex, count: int) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`. The original polled `getMousePosition()`
and `isMouseButtonPressed()` inside `render` and mutated the selection there,
so it only responded on frames that happened to repaint; all of that is now in
`events`.

Refactored 2026-09-16 onto `RowViewport` and `list_input`. Multi-select reads
ctrl straight from the keyboard because `GuiEvent` carries no modifier state —
acceptable, since that is an input query rather than render-time polling — but
the flag passed on is `multiSelect and ctrlDown`, so a single-select list
cannot be talked into multi-selecting.
</content>
