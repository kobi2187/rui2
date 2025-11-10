# Pango Integration Plan

## Goal

Standardize text rendering across RUI2 using Pango for high-quality Unicode/RTL/emoji support.

## Current State

- `pangolib_binding/` - Pango wrapper (has compilation issues)
- `drawing_primitives/primitives/text.nim` - Uses Raylib text rendering
- Widgets use inconsistent text rendering approaches

## New Architecture

```
drawing_primitives/
  primitives/
    text.nim          # High-level API (KEEP - wraps Pango)
    text_pango.nim    # Pango backend (NEW)
    text_raylib.nim   # Raylib fallback (NEW)
```

## API Design (text.nim)

Keep the existing simple API, but use Pango backend:

```nim
# Existing API (don't break this!)
proc drawText*(text: string, rect: Rect, style: TextStyle, align = TextAlign.Left)
proc measureText*(text: string, style: TextStyle): Size

# Implementation switches backends:
when usePango:
  import text_pango
else:
  import text_raylib
```

## Implementation Steps

### 1. Fix Pango Wrapper

The binding has issues. Options:
- Fix the existing wrapper in `pangolib_binding/`
- Create simpler wrapper focused on our needs
- Use Pango directly with minimal wrapper

### 2. Create text_pango.nim Backend

```nim
## Pango backend for text rendering
import ../pangolib_binding/src/[pangotypes, pangocore]
import raylib

type
  TextCache = Table[string, Texture2D]  # Cache rendered text

var textCache: TextCache

proc drawTextPango*(text: string, rect: Rect, style: TextStyle, align: TextAlign) =
  # Check cache
  let cacheKey = $text & $style & $align

  if cacheKey in textCache:
    # Use cached texture
    drawTexture(textCache[cacheKey], rect.x, rect.y, WHITE)
  else:
    # Render with Pango
    let layout = initTextLayout(text, maxWidth = rect.width.int32)
    if layout.isOk:
      var l = layout.get()
      let texture = l.getTexture()
      if texture.isSome:
        textCache[cacheKey] = texture.get()
        drawTexture(texture.get(), rect.x, rect.y, WHITE)

proc measureTextPango*(text: string, style: TextStyle): Size =
  let layout = initTextLayout(text, maxWidth = -1)
  if layout.isOk:
    var l = layout.get()
    return Size(width: l.width.float, height: l.height.float)
  else:
    return Size(width: 0, height: 0)
```

### 3. Update text.nim to Use Backend

```nim
## High-level text rendering API
import raylib
import ../core/types

when defined(usePango) and not defined(noPango):
  import text_pango
  export drawTextPango as drawText
  export measureTextPango as measureText
else:
  import text_raylib
  # Existing Raylib implementation
```

### 4. Update Widgets

Widgets already use `drawText()` from `drawing_primitives`, so no changes needed!

```nim
# Label widget - no changes needed!
import ../../drawing_primitives/drawing_primitives

definePrimitive(Label):
  render:
    let style = TextStyle(...)
    drawText(widget.text, widget.bounds, style)  # Uses Pango automatically
```

## Benefits

1. **Transparent**: Widgets don't know or care about Pango
2. **Cached**: Text textures are cached for performance
3. **Fallback**: Can still use Raylib if Pango unavailable
4. **Unicode**: Proper support for emoji, RTL, complex scripts
5. **Quality**: Subpixel rendering, proper kerning, ligatures

## Compilation Flags

```nim
# Use Pango (default)
nim c -d:usePango myapp.nim

# Force Raylib fallback
nim c -d:noPango myapp.nim

# Or in config.nims:
when not defined(noPango):
  switch("define", "usePango")
```

## Migration Path

### Phase 1: Fix Pango Wrapper (Current)
- Debug `getBidiRuns` issue
- Ensure `initTextLayout()` works
- Test with examples

### Phase 2: Create Backends
- Create `text_pango.nim` with cache
- Create `text_raylib.nim` (extract current code)
- Update `text.nim` to switch backends

### Phase 3: Test & Polish
- Test all widgets with Pango
- Benchmark performance (cache hit rate)
- Add cache management (LRU, size limits)

### Phase 4: Advanced Features
- RTL text support
- Emoji rendering
- Custom fonts
- Text shaping for complex scripts

## Cache Strategy

```nim
type
  TextCacheEntry = object
    texture: Texture2D
    lastUsed: Time
    refCount: int

  TextCache = object
    entries: Table[string, TextCacheEntry]
    maxEntries: int = 1000
    maxMemoryMB: int = 100

proc getCachedText(cache: var TextCache, key: string): Option[Texture2D]
proc cacheText(cache: var TextCache, key: string, texture: Texture2D)
proc evictOldEntries(cache: var TextCache)  # LRU eviction
```

## Performance Targets

- Cache hit rate: >95% (typical UI has repeated text)
- First render: <5ms (Pango + texture creation)
- Cached render: <0.1ms (texture blit)
- Memory: <100MB for cache (adjustable)

## Alternative: Pre-render Text

For static text (labels, buttons), render once and cache forever:

```nim
definePrimitive(Label):
  state:
    renderedTexture: Option[Texture2D]

  render:
    if widget.renderedTexture.isNone:
      # Render once
      widget.renderedTexture = some(renderTextToPango(widget.text, ...))

    # Always use cached texture
    drawTexture(widget.renderedTexture.get(), ...)
```

This is what we should do for widgets!

## Decision

**Recommended approach**:

1. Fix Pango wrapper issues
2. Create `text_pango.nim` backend with caching
3. Update `text.nim` to use Pango by default
4. Widgets automatically benefit (no code changes)
5. Add `-d:noPango` flag for Raylib fallback

**Result**: High-quality text rendering everywhere, transparent to widgets! 🎯
