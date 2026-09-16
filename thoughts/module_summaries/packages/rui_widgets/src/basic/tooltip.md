# packages/rui_widgets/src/basic/tooltip.nim

## Purpose

A hover tip that appears after the pointer has rested for `delay` seconds and
follows it. Placed as a **sibling overlay** of whatever it describes.

## Public interface

- `newTooltip*(text = "", delay = 0.5, offsetX = 10.0, offsetY = 10.0,
  fontSize = 10.0, padding = 6.0)`.
- State: `showing` (**not** `visible` — `Widget` already has that field),
  `hoverStartTime`, `mouseX`, `mouseY`.

`layout` sizes the widget to its text and positions it at the pointer, so the
tip *is* its own bounds — necessary, because a widget cannot draw outside them.

## Usage pattern

```nim
let zone = newZStack()
zone.bounds = Rect(x: 0, y: 0, width: 240, height: 60)
zone.addChild(newRectangle(color = paleBlue, cornerRadius = 6.0, filled = true))
zone.addChild(newTooltip(text = "This is a tooltip", delay = 0.4))
```

Buttons cannot draw their own tip; pair them with one of these.

## Circumstances

Restored 2026-09-15 from `a4bcc18`.

**The DSL has no `on_mouse_enter` / `on_mouse_leave`.** `eventNameToKind` maps
only `on_mouse_down/up/move/hover/wheel`, `on_key_down/up` and `on_char`, and
an unknown name is a compile error. Hover *entry* is therefore detected from
the repeated `on_mouse_hover` events, and hover *exit* from the base `hovered`
flag in `render`.

> **Known blocker.** Nothing in the codebase ever sets `hovered` back to
> `false` — `packages/rui/src/app.nim:391` is the only write to it and it only
> ever sets `true`. Until that is fixed this Tooltip can never hide once shown.
> It is candidate #4 in the architecture review.
</content>
