# packages/rui_widgets/src/menus/contextmenu.nim

## Purpose

A popup menu that appears where it is told to, normally on right-click. Holds
MenuItem children stacked vertically, with a drop shadow.

## Public interface

- `newContextMenu*(itemHeight = 24.0, minWidth = 150.0, padding = 4.0,
  intent = Default, onOpen, onClose)`.
- `openAt*(widget: ContextMenu, x, y: float32)` — show it with its top-left at
  (x, y). Sets `isDirty` and `layoutDirty` and fires `onOpen`.
- `close*(widget: ContextMenu)`.
- State: `isVisible`, `posX`, `posY`.
- Re-exports `menuitem`.

**While hidden it takes up no space** — zero bounds, children invisible — so it
never blocks clicks on what is underneath. Same two-pass item sizing as Menu.

## Usage pattern

```nim
let ctx = newContextMenu(minWidth = 160.0)
ctx.addChild(newMenuItem(text = "Cut", shortcut = "Ctrl+X"))
ctx.addChild(newMenuItem(separator = true))
ctx.addChild(newMenuItem(text = "Paste", shortcut = "Ctrl+V"))

ctx.openAt(200.0, 220.0)
```

Add it **last** among its siblings so it composites over them.

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where its `on_mouse_down` closed the menu
on any click with `# Check if click is outside menu bounds / For now, just
close`, so an item could never be clicked, and `render` called
`child.render()` (double-drawing under the current loop).
</content>
