# packages/rui_widgets/src/menus/menuitem.nim

## Purpose

One row in a Menu, MenuBar dropdown or ContextMenu: text, optional icon glyph,
optional shortcut hint, optional check state — or a separator rule instead.

## Public interface

- `newMenuItem*(text = "", shortcut = "", iconText = "", checkable = false,
  initialChecked = false, separator = false, hasSubmenu = false,
  itemHeight = 24.0, disabled = false, intent = Default, onClick, onToggle)`.
- State: `checked` (seeded from `initialChecked`).
- A separator sizes itself to 7px and draws a rule; everything else about it is
  skipped.

Layout: `IconGutter` (20px) + text, plus `ShortcutGap` (24px) + the shortcut
when present, plus another gutter when `hasSubmenu`. Width 0 means "measure
yourself", which is what Menu's two-pass sizing relies on.

## Usage pattern

```nim
let save = newMenuItem(text = "Save", shortcut = "Ctrl+S")
save.onClick = some(proc() {.closure.} = ...)

let wrap = newMenuItem(text = "Word wrap", checkable = true)
wrap.onToggle = some(proc(checked: bool) {.closure.} = ...)

menu.addChild(newMenuItem(separator = true))
```

A checkable item flips `checked` and fires `onToggle` **before** `onClick`, so
a handler reading `checked` sees the new value.

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it called raygui's `GuiMenuItem`
inside `render` and fired `onClick` from there — the click was detected during
painting, so it only fired on frames that happened to repaint. Now an
`on_mouse_down` handler, drawn with `drawMenuItem` plus the icon gutter,
checkmark and shortcut column.
</content>
