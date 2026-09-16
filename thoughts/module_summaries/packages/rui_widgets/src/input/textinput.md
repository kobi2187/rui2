# packages/rui_widgets/src/input/textinput.nim

## Purpose

Single-line text field with a real caret: click to place it, drag to select,
shift+arrows to extend, Enter to submit.

## Public interface

- `newTextInput*(initialText = "", placeholder = "Type here...",
  fontSize = 14.0, maxLength = -1, padding = 8.0, disabled = false,
  intent = Default, onChange, onSubmit)`.
- State: `text`, `cursorPos` (**byte** index), `selectionStart` /
  `selectionEnd` (-1 when there is no selection), `dragging`.
- `maxLength = -1` is unlimited.
- Scripting: the DSL-generated bridge handles `write` with
  `{"field": "text", "value": ...}`, plus `getText` / `read`.

Keys: Backspace, Delete, Left, Right, Home, End (shift extends the selection),
Enter / KpEnter submit, printable ASCII inserts. Typing over a selection
replaces it.

## Usage pattern

```nim
let input = newTextInput(placeholder = "Type something...",
                         fontSize = 16.0, maxLength = 40)
input.bounds = Rect(x: 0, y: 0, width: 440, height: 36)
input.onChange = some(proc(newText: string) {.closure.} = ...)
input.onSubmit = some(proc(text: string) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`. The original declared `input:` and
`on_click:` sections — **names the DSL never parsed** (`findSection` looks only
for props/state/actions/events/render/layout/init), so none of its editing
logic had ever run. It also hand-wrote `handleScriptAction`,
`getScriptableState` and `getTypeName`, all three of which the DSL now
generates; keeping them would not have compiled.

**Caret geometry goes through Pango**, which is the main gain from the merge
this restore sat on top of: `indexFromPosition` for click-to-caret and
`cursorPosition` for where to draw it. The pre-merge version measured every
prefix of the string in a loop to find the nearest character — O(n)
measurements per click, against raylib's 10px bitmap font, so wrong for any
real font.
</content>
