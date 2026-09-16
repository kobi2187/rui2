# packages/rui_widgets/src/containers/statusbar.nim

## Purpose

A status strip, normally docked at the bottom of a window: left-aligned
message, optional right-aligned detail (counts, cursor position, mode).

## Public interface

- `newStatusBar*(text = "", rightText = "", barHeight = 24.0, fontSize = 10.0,
  intent = Default)`.

Full width comes from the parent; only the height is the widget's own decision.

## Usage pattern

```nim
let status = newStatusBar(text = "Ready", rightText = "Ln 1, Col 1",
                          barHeight = 24.0)
status.bounds = Rect(x: 0, y: 0, width: 560, height: 24)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiStatusBar`.

**The prop is `barHeight`, not `height`.** `Widget` already carries geometry in
`bounds`, and a prop called `height` next to `bounds.height` reads as though
one of them is authoritative when neither is; the same rename applies to
ToolBar and MenuBar.
</content>
