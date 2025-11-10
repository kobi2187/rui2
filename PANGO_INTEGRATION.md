# Pango Text Rendering Integration Plan

**Last Updated**: 2025-11-10
**Status**: 📋 Planned - Wrapper exists as stub, not yet implemented

## Current Reality

### What Actually Exists ✅
- **Pango wrapper stub** - `pango_integration/pangowrapper.nim` (35 lines)
  - Contains placeholder types and functions
  - Comment: "Placeholder - will integrate real Pango later"
  - Returns dummy TextLayoutSimple with hardcoded dimensions

- **Pango examples** - Test files that attempt to use pangolib_binding
  - `examples/pango_basic_test.nim` - Imports external pangolib_binding
  - `examples/pango_stress_test.nim` - Performance test scaffolding
  - **Status**: Reference code, not currently working

- **Raylib text rendering** - Currently used throughout
  - All widgets use Raylib's DrawText functions
  - Works fine for ASCII and basic Unicode
  - Limited BiDi/shaping support

### What Doesn't Exist Yet ❌
- **Real Pango integration** - Wrapper is just placeholder
- **Cairo surface conversion** - Not implemented
- **Texture caching for Pango** - Not needed yet
- **Unicode shaping pipeline** - Not connected
- **BiDi text support** - Not working
- **Rich text markup** - Not implemented

---

## Why This Matters

**Current text rendering works fine** for most use cases with Raylib:
- ASCII text renders perfectly
- Basic Unicode (Latin, numbers, symbols) works
- Simple applications don't need Pango

**Pango would add** (when implemented):
- Full Unicode support (emoji, complex scripts)
- BiDi text (Arabic, Hebrew mixed with English)
- Text shaping (Thai, Devanagari, Arabic ligatures)
- Rich text markup (`<b>`, `<i>`, `<span>`)
- Professional typography (kerning, ligatures)

---

## Implementation Plan

### Phase 1: Fix External Dependency
**Goal**: Get pangolib_binding working

1. **Options**:
   - Use existing `pangolib_binding` from sibling directory
   - Create minimal Pango/Cairo bindings specific to RUI2 needs
   - Use community Pango wrapper package

2. **Challenges**:
   - Pragma issues mentioned in stub comments
   - Cross-platform compatibility (Linux/Mac/Windows)
   - Dependency management (Pango/Cairo libraries)

### Phase 2: Pango→Raylib Bridge
**Goal**: Render Pango text to Raylib textures

```nim
# Proposed API (not yet implemented)
proc renderTextWithPango*(text: string, style: TextStyle): Texture2D =
  # 1. Create Pango layout
  let layout = pango_layout_new(context)
  pango_layout_set_text(layout, text)

  # 2. Render to Cairo surface
  let surface = cairo_image_surface_create(...)
  let cr = cairo_create(surface)
  pango_cairo_show_layout(cr, layout)

  # 3. Convert Cairo bitmap to Raylib texture
  let pixels = cairo_image_surface_get_data(surface)
  let texture = LoadTextureFromImage(...)

  # 4. Cleanup
  cairo_destroy(cr)
  cairo_surface_destroy(surface)
  g_object_unref(layout)

  return texture
```

### Phase 3: Text Caching
**Goal**: Avoid re-rendering unchanged text

```nim
# Proposed cache system (not yet implemented)
type
  TextCache = object
    entries: Table[string, CachedText]
    maxSize: int

  CachedText = object
    texture: Texture2D
    lastUsed: Time
    refCount: int

proc getCachedText(cache: var TextCache, text: string, style: TextStyle): Texture2D =
  let key = hashTextAndStyle(text, style)
  if key in cache.entries:
    cache.entries[key].lastUsed = now()
    return cache.entries[key].texture
  else:
    let texture = renderTextWithPango(text, style)
    cache.entries[key] = CachedText(texture: texture, lastUsed: now())
    return texture
```

### Phase 4: Widget Integration
**Goal**: Widgets use Pango optionally

```nim
# Proposed usage (not yet implemented)
definePrimitive(Label):
  props:
    text: string
    usePango: bool = false  # Feature flag

  render:
    when defined(useGraphics):
      if widget.usePango and pangoAvailable():
        # Use Pango rendering
        let texture = renderTextWithPango(widget.text, style)
        DrawTexture(texture, widget.bounds.x, widget.bounds.y, WHITE)
      else:
        # Fallback to Raylib
        DrawText(widget.text, ...)
```

---

## Estimated Implementation

### Time Required
- **Phase 1** (Fix Pango bindings): 4-6 hours
  - Debug pragma issues
  - Cross-platform testing
  - Basic render test

- **Phase 2** (Pango→Raylib bridge): 6-8 hours
  - Cairo surface creation
  - Bitmap conversion
  - Memory management
  - Testing with various scripts

- **Phase 3** (Text caching): 3-4 hours
  - Cache implementation
  - LRU eviction
  - Performance testing

- **Phase 4** (Widget integration): 2-3 hours
  - Update Label widget
  - Add feature flags
  - Update examples

**Total**: 15-21 hours of focused work

### Complexity Assessment
- **High complexity** - Requires understanding:
  - Pango layout system
  - Cairo rendering
  - Memory management (ref counting)
  - Bitmap format conversion
  - Cross-platform C library integration

---

## Alternative: Current Raylib Approach

**What works now** (no Pango needed):

```nim
# Simple text rendering (works today)
DrawText("Hello World", x, y, fontSize, color)

# Unicode that works
DrawText("Hello 世界 🎨", x, y, fontSize, color)  # Basic Unicode OK

# What doesn't work well:
# - BiDi: "Hello עברית" (Hebrew mixed with English)
# - Complex scripts: "สวัสดี" (Thai) may not shape correctly
# - Rich formatting: No <b> or <i> support
```

**Raylib limitations**:
- No BiDi support
- Limited text shaping
- No rich text markup
- Basic font rendering only

**Raylib strengths**:
- Simple API
- Fast rendering
- Cross-platform
- Works out of the box
- Sufficient for most UI needs

---

## Decision Points

### When to implement Pango?

**Implement Pango if**:
- Need to support Arabic/Hebrew users (BiDi critical)
- Need complex script shaping (Thai, Devanagari)
- Want rich text formatting (bold, italic, colors in single label)
- Building text editor or document viewer
- Professional typography required

**Stick with Raylib if**:
- Building simple UI (buttons, forms, menus)
- Target audience uses Latin scripts
- Don't need BiDi or complex scripts
- Want simplest possible setup
- Performance is critical (Pango has overhead)

### Current Recommendation

**For RUI2 right now**: Continue using Raylib
- Widget library is comprehensive without Pango
- Most applications don't need BiDi/shaping
- Can add Pango later if users request it
- Reduces dependencies and complexity

**Add Pango later when**:
- User requests BiDi support
- Someone volunteers to implement it
- Need rich text editor widget
- Building internationalized app

---

## Files and Structure

### Current Files
```
pango_integration/
├── pangowrapper.nim          # 35 lines, stub/placeholder
└── (future files)

examples/
├── pango_basic_test.nim      # References external pangolib_binding
└── pango_stress_test.nim     # Test scaffolding

drawing_primitives/
└── pango_render.nim          # May have partial code, needs investigation
```

### Future Structure (when implemented)
```
pango_integration/
├── pangowrapper.nim          # Real Pango/Cairo wrapper
├── pango_cache.nim           # Texture caching
├── pango_raylib_bridge.nim   # Convert Cairo → Raylib
└── pango_helpers.nim         # Utility functions

text_rendering/
├── text_backend.nim          # Abstract interface
├── raylib_backend.nim        # Current Raylib implementation
└── pango_backend.nim         # Future Pango implementation
```

---

## Success Criteria (When Implemented)

**Must work**:
- [ ] Render ASCII text via Pango
- [ ] Render Unicode (emoji, CJK) via Pango
- [ ] Render BiDi text (Hebrew+English) correctly
- [ ] Complex script shaping (Thai, Arabic)
- [ ] Rich text markup (`<b>`, `<i>`, colors)
- [ ] Cache textures (no re-render unless changed)
- [ ] Performance: 60 FPS with 100+ labels
- [ ] Memory: No leaks, proper cleanup

**Integration requirements**:
- [ ] Works with Label widget
- [ ] Works with Button widget (text labels)
- [ ] Optional via compile flag `-d:usePango`
- [ ] Fallback to Raylib if Pango unavailable
- [ ] Theme fonts work with Pango
- [ ] Cross-platform (Linux, Mac, Windows)

---

## Current Workaround

**For internationalized apps today**:

1. **Use Raylib with Unicode fonts**:
   - Load Noto Sans (supports most scripts)
   - Basic Unicode will render
   - BiDi won't work correctly but readable

2. **Preprocess BiDi text**:
   - Use external library to reorder BiDi
   - Feed reordered text to Raylib
   - Not perfect but may be acceptable

3. **Use images for complex text**:
   - Pre-render complex text elsewhere
   - Load as images in UI
   - Not dynamic but works

4. **Wait for Pango** (recommended):
   - Current Raylib works for most cases
   - Implement Pango when actually needed
   - Don't over-engineer prematurely

---

## Summary

**Reality**: Pango integration is planned but not implemented. The `pangowrapper.nim` file is a 35-line stub with placeholder functions. All current text rendering uses Raylib.

**Good news**: Raylib text rendering works fine for most applications. The widget library is complete and functional without Pango.

**Future**: Pango integration is a 15-21 hour project that would add professional text rendering, BiDi support, and rich text. Implement it when actually needed by users.

**For now**: Be honest that this is planned future work, not a completed feature. The documentation previously overstated the implementation status.

---

**Status**: 📋 Planned - Comprehensive design exists, wrapper is stub, implementation needed when BiDi/shaping required.
