# Pango Text Module

High-quality text rendering using Pango+Cairo with texture caching for Raylib.

## Public API

```nim
import modules/pango_text/api
```

### Components
- `pangowrapper` — Re-exports pangolib_binding (Pango+Cairo -> Raylib texture pipeline)
- `text_render` — Cached drawText/measureText using Pango backend
- `pango_helpers` — Low-level Pango integration helpers
- `text_cache` — LRU text texture cache (100MB max, 1000 entries default)

### Key Functions

| Function | Description |
|---|---|
| `drawText(text, x, y, fontSize, color, fontFamily)` | Cached Pango text rendering |
| `drawTextEx(text, x, y, style)` | Explicit style rendering |
| `measureText(text, fontSize, fontFamily)` | Measure text width |
| `clearTextCache()` | Free all cached textures |
| `initTextLayout(text, maxWidth)` | Low-level Pango layout |
| `freeTextLayout(layout)` | Free Pango layout |

### External Dependency

Requires `pangolib_binding` as a sibling directory:
```
/home/user/
  rui2/
  pangolib_binding/
    src/
      pangotypes.nim
      pangocore.nim
```

### Dependencies
- `core/types` (Color, Rect)
- External: pangolib_binding, raylib
