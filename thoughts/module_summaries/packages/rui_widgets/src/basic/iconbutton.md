# packages/rui_widgets/src/basic/iconbutton.nim

## Purpose

A square button showing an icon: a text glyph, or a texture loaded from disk.

## Public interface

- `newIconButton*(iconText = "", iconTexturePath = "", size = 24.0,
  disabled = false, intent = Default, onClick)`.
- State: `isPressed`, `textureLoaded`, `loadFailed`.
- `layout` makes it square from `size`.

Textures are loaded lazily on first render and kept in a module-level
`Table[string, Texture2D]`, because naylib textures are move-only and must be
borrowed rather than copied. A failed load sets `loadFailed` and is not
retried.

**No `tooltip` prop.** It had one before the restore; it could not work, because
`renderPass` clips every widget to its own bounds. Pair with the Tooltip widget.

## Usage pattern

```nim
let btn = newIconButton(iconText = "+", size = 32.0)
btn.onClick = some(proc() {.closure.} = ...)

let img = newIconButton(iconTexturePath = "assets/save.png", size = 32.0)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where both branches called raygui's
`GuiButton` with the icon text — the texture path was accepted and then ignored
(`# For now, we'll use GuiButton as fallback`). Texture drawing works now,
following the same cache pattern as `basic/image.nim`.
</content>
