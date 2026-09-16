# packages/rui_widgets/src/menus/menu.nim

## Purpose

A dropdown panel holding MenuItem children. Used as a MenuBar drop-down or on
its own. Draws only the panel — `title` is for a parent MenuBar to display, not
for the Menu itself.

## Public interface

- `newMenu*(title = "", itemHeight = 24.0, minWidth = 150.0, padding = 4.0,
  intent = Default, onOpen, onClose)`.
- `open*(widget: Menu)` / `close*(widget: Menu)` — the supported way to toggle.
  Both set `isDirty` **and** `layoutDirty`, and fire the matching action.
- State: `isOpen`, `selectedIndex`.

**While closed the menu occupies no space**: `layout` sets `bounds.width` and
`bounds.height` to 0 and hides every child, so whatever is underneath stays
clickable. Do not read `bounds` for a closed menu and expect the open size.

Items are sized in two passes: each measures itself, then all are squared off
to the widest, so a dropdown's items share one width.

## Usage pattern

```nim
let fileMenu = newMenu(title = "File", minWidth = 180.0)
fileMenu.addChild(newMenuItem(text = "New", shortcut = "Ctrl+N"))
fileMenu.addChild(newMenuItem(separator = true))
fileMenu.addChild(newMenuItem(text = "Quit"))

fileMenu.open()     # not `isOpen = true` — open() sets layoutDirty too
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where `render` called `child.render()` for
every item. That double-draws under the current loop: `main_loop.renderPass`
already recurses over `children` itself, so a container draws only its own
chrome and lets the pass composite the children.

Opening must invalidate layout, not just trigger a repaint, because the panel
is drawn inside this widget's own bounds-sized render texture.
</content>
