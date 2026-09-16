# packages/rui_widgets/src/dialogs/modal.nim

## Purpose

The geometry every modal dialog needs: how big it is, and where its panel sits
inside that. Small on purpose — it exists because both MessageBox and
FileDialog exported a `panelRect`, which made every call to it ambiguous once
`dialogs.nim` exported both.

## Public interface

- `overlayBounds*(): Rect` — the full-screen rect a modal should occupy,
  `(0, 0, getScreenWidth(), getScreenHeight())`.
- `panelRect*(bounds: Rect, width, height: float32): Rect` — the dialog box,
  centred in those bounds.

## Usage pattern

```nim
  layout:
    # Fill the screen so the dim overlay has somewhere to go.
    widget.bounds = overlayBounds()

  render:
    if not widget.isVisible: return
    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 128))     # the dim
    let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
    drawThemedBackground(panel, props)
```

## Circumstances

2026-09-15, restoring the dialogs deleted in `a4bcc18`.

**Why a modal is screen-sized.** `main_loop.renderPass` draws each widget into
a `RenderTexture2D` sized to its own `bounds`, with `bounds.x/y` temporarily
zeroed. Anything a widget draws outside its bounds is silently clipped. A
dialog sized to its own panel therefore *cannot* dim anything around itself —
so the widget takes the whole screen and the panel is drawn in the middle of
it. The same constraint is why ComboBox grows its bounds when its dropdown
opens, and why MenuBar grows to cover an open dropdown.
</content>
