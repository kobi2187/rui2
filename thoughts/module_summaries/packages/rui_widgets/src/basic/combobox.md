# packages/rui_widgets/src/basic/combobox.nim

## Purpose

Dropdown selection: the chosen item in a closed box, an expanding item list
below it when open.

## Public interface

- `newComboBox*(items: seq[string] = @[], initialSelectedIndex = -1,
  placeholder = "Select...", itemHeight = 24.0, boxHeight = 28.0,
  disabled = false, intent = Default, onSelect)`.
- State: `selectedIndex`, `isOpen`, `hoverIndex`.
- Keys: Up / Down move the selection, Escape closes.

**`initialSelectedIndex`, not `initialSelected`.** The DSL seeds a state field
from a prop named `initial<StateField>`, and the state field here is
`selectedIndex`. The pre-restore name `initialSelected` matched nothing, so the
prop was silently ignored and the widget always started on item 0.

**`boxHeight` is the closed box; `bounds.height` is not.** When open, `layout`
grows `bounds.height` to `boxHeight + items.len * itemHeight`, so read
`boxHeight` when you want the box and `bounds` when you want the whole widget.

## Usage pattern

```nim
let combo = newComboBox(items = @["Small", "Medium", "Large"],
                        initialSelectedIndex = 1)
combo.onSelect = some(proc(index: int) {.closure.} = ...)
```

Opening the dropdown from code must set **both** flags:

```nim
combo.isOpen = true
combo.isDirty = true
combo.layoutDirty = true    # required — see below
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it was a thin wrapper over raygui's
`GuiComboBox`; the dropdown is now drawn with `drawComboBox` + `drawListItem`.

**Why opening is a layout change.** `main_loop.renderPass` draws each widget
into a `RenderTexture2D` sized to its `bounds`. A dropdown drawn below a
box-sized widget would be clipped away entirely, so the widget must *own* the
space its popup occupies — which means re-running `layout`, not just
repainting. The same applies to Menu, MenuBar, ContextMenu and the modals.
</content>
