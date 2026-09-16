# packages/rui_widgets/src/containers/toolbar.nim

## Purpose

A horizontal strip of quick-access controls, normally docked under a MenuBar.
Usually filled with ToolButtons.

## Public interface

- `newToolBar*(barHeight = 32.0, spacing = 2.0, padding = 4.0,
  showBorder = true, intent = Default)`.

Children keep their own width if they have one; a child still at zero width
after its own `layout` gets a **square** slot, `itemHeight × itemHeight`, which
is what makes a row of icon buttons line up without hand-set bounds.

## Usage pattern

```nim
let bar = newToolBar(barHeight = 40.0, spacing = 4.0, padding = 4.0)
for (glyph, caption) in [("B", "Bold"), ("I", "Italic")]:
  bar.addChild(newToolButton(iconText = glyph, text = caption,
                             size = 28.0, showText = true, toggleable = true))
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where `render` called `child.render()`
itself (double-drawing under the current loop) and the square-slot fallback ran
*before* the child had laid itself out, so a self-measuring child was squared
off before it had a chance to report a width.
</content>
