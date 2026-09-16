# packages/rui_widgets/src/basic/numberinput.nim

## Purpose

Numeric field that can be **typed into** as well as stepped. Spinner's editable
cousin: same up/down gutter, plus click-to-edit with validation on commit.

## Public interface

- `newNumberInput*(initialValue = 0.0, minValue = 0.0, maxValue = 100.0,
  step = 1.0, decimals = 2, placeholder = "0.0", disabled = false,
  intent = Default, onChange, onValidationError)`.
- State: `value`, `editing`, `textValue`, `upHovered`, `downHovered`.

Editing: click the text area to start (seeded from the current value), type
`0-9 . - +`, Backspace deletes. **Enter commits** — parses, clamps to range,
fires `onChange`; unparseable text fires `onValidationError` and reverts.
**Escape reverts** without firing anything.

## Usage pattern

```nim
let num = newNumberInput(initialValue = 0.0, minValue = -50.0, maxValue = 50.0,
                         step = 1.0, decimals = 2)
num.onChange = some(proc(value: float32) {.closure.} = ...)
num.onValidationError = some(proc(input: string) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiSpinner` and
its `on_focus_gained` / `on_focus_lost` handlers named events the DSL does not
have (`eventNameToKind` maps only `on_mouse_*`, `on_key_*` and `on_char`), so
none of its editing logic was ever reachable. Editing now runs on `on_char` and
`on_key_down`, with `editing` starting on a click in the text area.

Carries the same `decimals` change as Spinner, for the same reason.
</content>
