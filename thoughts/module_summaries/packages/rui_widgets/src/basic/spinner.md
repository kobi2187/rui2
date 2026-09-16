# packages/rui_widgets/src/basic/spinner.nim

## Purpose

Numeric stepper: a value with up/down buttons in a 16px gutter on the right.
Step-only — for typed entry use NumberInput.

## Public interface

- `newSpinner*(initialValue = 0.0, minValue = 0.0, maxValue = 100.0, step = 0.5,
  decimals = 2, textLeft = "", disabled = false, intent = Default, onChange)`.
- State: `value`, `upHovered`, `downHovered`.
- `initialValue` seeds `value` (the DSL's `initial<StateField>` convention).

Clicking the top half of the right-hand gutter steps up, the bottom half steps
down; the value is clamped to `[minValue, maxValue]` and `onChange` fires only
when it actually moved.

## Usage pattern

```nim
let spin = newSpinner(initialValue = 5.0, minValue = 0.0, maxValue = 10.0,
                      step = 0.5, decimals = 1)
spin.onChange = some(proc(value: float32) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiSpinner`.

**`decimals: int` replaced a `format: string = "%.2f"` prop that never worked.**
The original called `fmt(widget.format) % value` — Nim's `%` is not printf and
`fmt` is a compile-time macro over a literal, so that could not have compiled
with graphics enabled. Rather than preserve a broken API the prop became a
decimal count, formatted with `strutils.formatFloat`.

The button gutter is 16px because that is what `drawSpinnerButtons` in
`rui_drawing` draws; the `ButtonWidth` constant here must match it.
</content>
