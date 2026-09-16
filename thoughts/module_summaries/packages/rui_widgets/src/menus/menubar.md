# packages/rui_widgets/src/menus/menubar.nim

## Purpose

Horizontal strip of menu titles. Each child is a `Menu` whose `title` the bar
draws in the strip and whose dropdown it positions underneath.

## Public interface

- `newMenuBar*(barHeight = 28.0, intent = Default, onMenuOpen, onMenuClose)`.
- `TitleSlot*` — `index`, `x`, `width`.
- `titleSlots*(children: seq[Widget], startX: float32): seq[TitleSlot]` — where
  each Menu child's title sits. Layout, hit-testing and painting all call this,
  so they cannot drift apart.
- `slotAt*(slots, mouseX): int` — index of the Menu under the pointer, or -1.
- State: `activeMenuIndex` (-1 for none), `hoverIndex`.
- Re-exports `menu` and `menuitem`.
- `init` sets `hasOverlay = true` so dropdowns sort above later siblings.

## Usage pattern

```nim
let bar = newMenuBar(barHeight = 28.0)

let fileMenu = newMenu(title = "File", minWidth = 180.0)
fileMenu.addChild(newMenuItem(text = "Open", shortcut = "Ctrl+O"))
fileMenu.addChild(newMenuItem(separator = true))
fileMenu.addChild(newMenuItem(text = "Quit", shortcut = "Ctrl+Q"))
bar.addChild(fileMenu)
```

Clicking a title opens that menu and closes the others; clicking the open one
closes it.

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it drew the literal string `"Menu"`
for every title at a fixed 80px width, with `# TODO: measure text width` and
`# TODO: Get actual title from Menu child` where the real logic belonged.

**The Menu type is written `menu.Menu` throughout.** `rui_core` does
`export raylib` wholesale and naylib's `KeyboardKey` has a `Menu` field, so the
bare name is ambiguous anywhere raylib is in scope. This is the clearest cost of
that wholesale re-export.

**The bar grows to cover an open dropdown.** `renderPass` composites a child
into the parent's render texture, which is sized to the parent's bounds — a
dropdown taller than the strip would be cut off at the strip's bottom edge, so
`layout` extends `bounds.height` to the open menu's bottom.
</content>
