# packages/rui_widgets/src/input/textarea.nim

## Purpose

The one text widget. Label, TextInput and TextArea are this widget with
limiting properties: `editable = false` (display only, no frame) is a Label,
`multiline = false` is a TextInput, and the defaults are a TextArea.
Replaces the former `primitives/label.nim` and `input/textinput.nim`.

## Public interface

- `newTextArea*(initialText, placeholder, fontSize, color, fontFamily, bold,
  italic, underline, align, wrap, markup, editable, multiline, maxLength,
  maxLines, framed, padding, visibleLines, disabled, intent, onChange,
  onSubmit)`.
- `newLabel*(text, fontSize, color = BLACK, ...)` and
  `newTextInput*(initialText, placeholder, fontSize, maxLength, padding, ...)`
  set the limiting properties. `Label` and `TextInput` are aliases of
  `TextArea`.
- State: `text` (first, so a bare script `write` targets it), `cursorPos`
  (byte index), `selectionStart`/`selectionEnd` (-1: none), `goalColumn`.
- `getTypeName` reports the role: "Label", "TextInput" or "TextArea".
- Pure helpers: `lineStarts`, `lineOf`, `columnOf` (characters),
  `lineEnd`, `indexAtLineColumn`, `verticalMove`, `roomForLine`.

## Behaviour

A widget that is not editable takes no input at all (all handlers return
false), so a Button's caption never swallows its click. Enter inserts a
newline when multiline and under `maxLines`, otherwise fires `onSubmit`.
Up/Down move by line keeping the goal column; single-line leaves them to
focus navigation. Wrap and markup apply to display text only. `color` with
alpha 0 (`ThemeColor`) means the theme's foreground.
