# packages/rui_widgets/src/containers/radiogroup.nim

## Purpose

A group of mutually exclusive options: picking one clears the rest.

## Public interface

- `newRadioGroup*(options: seq[string] = @[], initialSelectedIndex = 0,
  spacing = 24.0, disabled = false, intent = Default, onSelect)`.
- State: `selectedIndex`, `hoverIndex`.
- Keys: Up / Down move the selection and fire `onSelect`.

**`initialSelectedIndex`, not `initialSelected`** — the DSL seeds state from a
prop named `initial<StateField>`, and the state field is `selectedIndex`. The
pre-restore name matched nothing, so the prop was ignored and the group always
started on option 0.

## Usage pattern

```nim
let radios = newRadioGroup(options = @["Standard", "Express", "Overnight"],
                           initialSelectedIndex = 0, spacing = 24.0)
radios.onSelect = some(proc(index: int) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where `render` called raygui's
`GuiRadioButton` per option and mutated `selectedIndex` from inside the paint.

**It draws its own options rather than owning RadioButton children**, even
though it lives in `containers/`. Exclusivity is the entire point of the
widget, and one `selectedIndex` in one place is what makes it exclusive — a bag
of independent RadioButton children would each own a `selected` flag with
nothing to reconcile them. The original was already shaped this way; the
restore kept it deliberately rather than by inertia.
</content>
