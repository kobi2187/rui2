# packages/rui_widgets/src/basic/toolbutton.nim

## Purpose

A flat button for toolbars: icon glyph on top, optional label underneath.
Unlike IconButton it can be **toggleable**, and it paints no background until
it is hovered, pressed or toggled on.

## Public interface

- `newToolButton*(iconText = "", text = "", size = 24.0, showText = false,
  toggleable = false, disabled = false, intent = Default, onClick, onToggle)`.
- State: `isPressed`, `toggled`.
- A toggleable button flips `toggled` and fires `onToggle` **before** `onClick`,
  so a handler reading `toggled` sees the new value.
- Height grows by the label row when `showText` is set and `text` is non-empty.

**No `tooltip` prop** — same reason as IconButton. Pair with Tooltip.

## Usage pattern

```nim
let bold = newToolButton(iconText = "B", text = "Bold", size = 28.0,
                         showText = true, toggleable = true)
bold.onToggle = some(proc(state: bool) {.closure.} = ...)
toolbar.addChild(bold)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it drew with raylib's
`DrawRectangleRec` / `DrawText` directly, hard-coded its greys, and read
`widget.isHovered` — a field that does not exist; the base flag is `hovered`.
It draws through the theme now.
</content>
