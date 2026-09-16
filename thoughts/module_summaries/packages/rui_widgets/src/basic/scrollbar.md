# packages/rui_widgets/src/basic/scrollbar.nim

## Purpose

A standalone scroll bar, vertical or horizontal. Note that the scrollable
widgets (ListView, DataTable, …) draw their own bar inline — this is for
scrolling something that is not one of them.

## Public interface

- `newScrollBar*(initialValue = 0.0, minValue = 0.0, maxValue = 100.0,
  pageSize = 10.0, wheelStep = 10.0, vertical = true, disabled = false,
  intent = Default, onChange)`.
- State: `value`, `dragging`.
- `pageSize` is the size of the visible area; it drives the thumb's proportion.

Clicking the track jumps straight to that position and starts tracking, so a
click-and-drag works without a separate grab gesture. The cross axis is fixed
at 12px in `layout`; the parent decides the main axis.

## Usage pattern

```nim
let bar = newScrollBar(initialValue = 0.0, maxValue = 100.0,
                       pageSize = 20.0, vertical = false)
bar.bounds = Rect(x: 0, y: 0, width: 300, height: 12)
bar.onChange = some(proc(value: float32) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiScrollBar`
and its `on_mouse_wheel` handler was a `# For now, placeholder` comment.

**Vertical and horizontal draw differently.** `rui_drawing`'s themed
`drawScrollbar` measures the thumb off `rect.height`, so it only works
vertically; the horizontal case draws its own track and thumb. That also meant
inlining the alpha maths for the track, because `fadeColor` in
`primitives/controls.nim` is not exported — worth fixing at some point.
</content>
