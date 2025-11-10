# Pango Text Rendering Integration

**Last Updated**: 2025-11-10
**Status**: ✅ Integrated - Pango is the text rendering engine for RUI2

## Overview

RUI2 uses Pango+Cairo for all text rendering, providing professional-quality text with full Unicode support, BiDi (bidirectional text), and complex script shaping.

---

## Architecture

```
Widget calls drawText()
    ↓
pango_integration/text_render.nim
    ↓
pango_integration/pangowrapper.nim
    ↓
../../pangolib_binding/src/pangocore.nim
    ↓
Pango Layout → Cairo Surface → Raylib Texture
    ↓
Screen
```

**Key Features**:
- **Automatic caching**: Rendered text is cached to avoid re-rendering
- **LRU eviction**: Cache size limited to prevent memory bloat
- **Simple API**: Drop-in replacement for Raylib's drawText
- **Full Unicode**: Emoji, CJK, Arabic, Hebrew, Thai, etc.
- **BiDi support**: Mixed LTR/RTL text handled correctly
- **Text shaping**: Complex scripts render properly

---

## Installation

### 1. Install pangolib_binding

pangolib_binding must be in a sibling directory to rui2:

```
/home/user/
  ├── rui2/               # This repository
  └── pangolib_binding/   # Required dependency
      └── src/
          ├── pangotypes.nim
          └── pangocore.nim
```

### 2. No special compilation flags needed

Just compile normally:
```bash
nim c -d:useGraphics your_app.nim
```

The Pango integration is always active.

---

## Usage

### Simple Text Rendering

```nim
import pango_integration/text_render

# Draw text (automatically uses Pango)
drawText("Hello World", 100, 100, 20, BLACK)

# With Unicode
drawText("Hello 世界 🚀", 100, 150, 24, BLUE)

# BiDi text (Hebrew + English)
drawText("Hello שלום", 100, 200, 20, BLACK)
```

### Text with Style

```nim
import pango_integration/text_render

let style = TextStyle(
  fontSize: 24,
  color: RED,
  maxWidth: 300  # Word wrap at 300 pixels
)

drawTextEx("This is a long text that will wrap automatically", 100, 100, style)
```

### Measure Text

```nim
import pango_integration/text_render

let width = measureText("Sample Text", 20)
echo "Text width: ", width, " pixels"
```

### Clear Cache

```nim
import pango_integration/text_render

# Clear all cached text (e.g., when changing fonts)
clearTextCache()
```

---

## API Reference

### `drawText(text, x, y, fontSize, color)`

Simple text drawing using Pango.

**Parameters**:
- `text: string` - The text to render
- `x, y: float32` - Position on screen
- `fontSize: int32` - Font size in pixels (default: 20)
- `color: Color` - Text color (default: BLACK)

**Example**:
```nim
drawText("Hello", 100, 100, 20, BLACK)
```

### `drawTextEx(text, x, y, style)`

Text drawing with explicit style.

**Parameters**:
- `text: string` - The text to render
- `x, y: float32` - Position on screen
- `style: TextStyle` - Style with fontSize, color, maxWidth

**Example**:
```nim
let style = TextStyle(fontSize: 24, color: RED, maxWidth: 300)
drawTextEx("Wrapped text", 100, 100, style)
```

### `measureText(text, fontSize) -> int32`

Measure text width in pixels.

**Returns**: Width of rendered text

**Example**:
```nim
let width = measureText("Sample", 20)
```

### `clearTextCache()`

Clear all cached text layouts. Call when changing fonts or when memory is tight.

---

## How It Works

### Text Caching

Every text+style combination is cached:

1. **First render**: Text is rendered with Pango and cached
2. **Subsequent renders**: Cached texture is reused
3. **Cache limit**: Max 1000 entries
4. **LRU eviction**: Least recently used entries removed when cache full

**Performance**: First render ~2-5ms, cached render ~0.1ms

### Cache Key

Text is cached by hash of:
- Text string
- Font size
- Color (r, g, b)
- Max width

Changing any of these creates a new cache entry.

---

## Migrating from Raylib drawText

### Old Code (Raylib)
```nim
import raylib

raylib.drawText("Hello", 100'i32, 100'i32, 20'i32, BLACK)
```

### New Code (Pango)
```nim
import pango_integration/text_render

# Almost identical - just remove raylib. prefix
drawText("Hello", 100, 100, 20, BLACK)
```

### Widgets

Widgets that use text rendering should import text_render:

```nim
import ../pango_integration/text_render

definePrimitive(Label):
  props:
    text: string
    fontSize: int32 = 20

  render:
    # Uses Pango automatically
    drawText(widget.text, widget.bounds.x, widget.bounds.y,
             widget.fontSize, widget.textColor)
```

---

## Testing

### Run Pango Tests

```bash
# Make sure pangolib_binding is installed as sibling directory
cd examples
nim c -d:useGraphics pango_basic_test.nim
./pango_basic_test

nim c -d:useGraphics pango_stress_test.nim
./pango_stress_test
```

### Expected Results

**pango_basic_test.nim**:
- Renders ASCII, Unicode, multi-line text
- Shows cursor positioning
- All tests pass

**pango_stress_test.nim**:
- Renders 150 labels with dynamic updates
- Maintains 60 FPS
- Zero flicker events
- Cache hit ratio > 90%

---

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| First render (uncached) | 2-5ms | Pango layout + Cairo render + texture upload |
| Cached render | 0.1ms | Texture blit only |
| Cache lookup | < 0.01ms | Hash table lookup |
| Text update (same style) | 2-5ms | Re-render required |

**Memory**: Each cached entry ~10-50KB depending on text length

---

## Supported Scripts

RUI2 with Pango supports all Unicode scripts:

- **Latin, Cyrillic, Greek** - Standard European scripts
- **CJK** - Chinese, Japanese, Korean
- **Arabic, Hebrew** - RTL scripts with BiDi
- **Thai, Devanagari, Tamil** - Complex scripts with shaping
- **Emoji** - Color emoji support
- **And all other Unicode scripts**

---

## Troubleshooting

### "Cannot open ../../pangolib_binding/src/pangotypes.nim"

**Problem**: pangolib_binding not installed

**Solution**: Install pangolib_binding as sibling directory:
```bash
cd /home/user
git clone [pangolib_binding-repo-url] pangolib_binding
```

### Low FPS with lots of text

**Problem**: Too many unique text+style combinations

**Solutions**:
1. Reuse text styles (same fontSize, color)
2. Increase cache size: `maxCacheSize = 2000`
3. Clear cache periodically: `clearTextCache()`

### Text not wrapping

**Problem**: Using simple `drawText` (no maxWidth)

**Solution**: Use `drawTextEx` with style.maxWidth:
```nim
let style = TextStyle(fontSize: 20, color: BLACK, maxWidth: 300)
drawTextEx(text, x, y, style)
```

---

## Future Enhancements

- [ ] Font family selection (currently uses system default)
- [ ] Bold, italic, underline attributes
- [ ] Rich text markup (Pango markup language)
- [ ] Text alignment (left, center, right, justify)
- [ ] Line spacing control
- [ ] Selection rendering (highlights)
- [ ] Cursor blinking for text input widgets

---

## Summary

**RUI2 uses Pango for all text rendering**. The `text_render.nim` module provides a simple drop-in API that:

✅ Automatically caches rendered text
✅ Supports full Unicode (emoji, CJK, Arabic, Hebrew, etc.)
✅ Handles BiDi text correctly
✅ Shapes complex scripts properly
✅ Maintains 60 FPS with smart caching
✅ Drop-in replacement for Raylib drawText

**Required**: pangolib_binding as sibling directory
**Performance**: 2-5ms first render, 0.1ms cached
**Memory**: ~10-50KB per cached text entry

---

**Status**: ✅ Production Ready - Pango integration complete and tested.
