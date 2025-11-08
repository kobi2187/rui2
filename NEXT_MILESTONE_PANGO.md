# Next Milestone: Pango+Cairo Text Rendering Integration

## Overview

Integrate pangolib_binding (Pango+Cairo) for professional text rendering with full Unicode, BiDi, and rich text support.

## Goals

1. **Rich TextArea Widget**: Multi-line text editing with full Unicode support
2. **TextInput Widget**: Single-line version (limited TextArea)
3. **Read-only Text Widget**: Display-only version for labels/paragraphs
4. **Pango→Raylib Pipeline**: Render with Pango/Cairo, copy bitmap to Raylib texture

## Why Pango+Cairo?

- **Unicode Support**: Proper handling of all Unicode characters
- **BiDi (Bidirectional)**: Arabic, Hebrew, mixed LTR/RTL text
- **Text Shaping**: Complex scripts (Thai, Devanagari, etc.)
- **Caret Positioning**: Accurate cursor placement in complex text
- **Rich Formatting**: Bold, italic, colors, fonts, sizes
- **Professional Quality**: Industry-standard text rendering

## Architecture

```
User Input
    ↓
TextArea Widget (RUI2)
    ↓
Pango Layout (pangolib_binding)
    ↓
Cairo Surface (render to bitmap)
    ↓
Copy/Convert Bitmap
    ↓
Raylib Texture2D
    ↓
Display in Widget Bounds
```

## Existing Resources

- **Location**: `~/prog/pangolib_binding`
- **Status**: Semi-finished implementation
- **Bindings**: Pango + Cairo already wrapped

## Implementation Plan

### Phase 1: Explore Existing Binding
1. Read pangolib_binding codebase
2. Understand current API surface
3. Identify what's complete vs. what needs work
4. Test basic Pango rendering example

### Phase 2: Pango→Raylib Bridge
1. Create PangoRenderer helper module
2. Implement Cairo surface → Raylib Texture2D conversion
3. Handle texture updates (only redraw when text changes)
4. Optimize for performance (texture caching)

### Phase 3: Basic TextArea Widget
1. Single-line text input first (simpler)
2. Text state management (content, cursor position, selection)
3. Keyboard input handling (typing, backspace, delete, arrows)
4. Mouse input (click to position cursor, drag to select)
5. Render text using Pango

### Phase 4: Advanced TextArea Features
1. Multi-line support (line wrapping, word wrap)
2. Scrolling (vertical, horizontal if needed)
3. Selection rendering (highlight selected text)
4. Copy/paste (clipboard integration)
5. Undo/redo

### Phase 5: Rich Text Support
1. Pango markup parsing (<b>, <i>, <span>, etc.)
2. Multiple fonts/sizes in single widget
3. Color spans
4. Hyperlinks (optional)

### Phase 6: TextInput Widget
1. Inherit from TextArea
2. Limit to single line
3. Add on_submit event (Enter key)
4. Password mode (show dots/asterisks)

### Phase 7: Read-only Text Widget
1. Disable editing
2. Optimize for display-only
3. Support selectable text
4. Use for formatted labels, paragraphs

## Key Challenges

### 1. Bitmap Transfer Performance
- **Challenge**: Copying Cairo surface to Raylib texture every frame is expensive
- **Solution**: Only update texture when text changes (dirty flag)
- **Solution**: Use Raylib's UpdateTexture for partial updates

### 2. Caret Positioning
- **Challenge**: Complex scripts have non-linear cursor movement
- **Solution**: Use Pango's pango_layout_xy_to_index() and pango_layout_index_to_pos()

### 3. Unicode Input
- **Challenge**: Handling multi-byte UTF-8, IME input
- **Solution**: Use Raylib's GetCharPressed() for proper Unicode input

### 4. BiDi Complexity
- **Challenge**: Mixed LTR/RTL text, cursor behavior
- **Solution**: Let Pango handle it, trust pango_layout functions

### 5. Line Wrapping
- **Challenge**: Word wrap, character wrap, hyphenation
- **Solution**: Use Pango's built-in wrapping (PANGO_WRAP_WORD, etc.)

## Widget Hierarchy

```nim
TextAreaBase (abstract)
  ├── props:
  │     text: string
  │     cursorPos: int
  │     selectionStart, selectionEnd: int
  │     pangoLayout: PangoLayout
  │     texture: Texture2D
  │     isDirty: bool
  │
  ├── TextArea (full editor)
  │     multiLine: true
  │     scrollable: true
  │     richText: supported
  │
  ├── TextInput (single line)
  │     multiLine: false
  │     on_submit event
  │     password mode
  │
  └── TextDisplay (read-only)
        editable: false
        selectable: true
        richText: supported
```

## Integration with RUI2

### Theme Support
```nim
defineWidget(TextArea):
  props:
    text: string
    theme: Theme
    intent: ThemeIntent
    state: ThemeState
    # ... Pango-specific props

  render:
    # Get theme colors
    let props = widget.theme.getThemeProps(widget.intent, widget.state)

    # Set Pango attributes (font, color from theme)
    setPangoAttributes(widget.pangoLayout, props)

    # Render to Cairo surface
    renderPangoLayout(cairoContext, widget.pangoLayout)

    # Copy to Raylib texture
    updateRaylibTexture(widget.texture, cairoSurface)

    # Draw texture
    drawTexture(widget.texture, widget.bounds)
```

### YAML-UI Syntax
```yaml
- textarea:
    text: "Hello World"
    theme: "textarea.default"
    multiline: true
    on_change: handleTextChange/1

- textinput "username":
    placeholder: "Enter username"
    on_submit: login/1

- textdisplay:
    text: "<b>Bold</b> and <i>italic</i>"
    markup: true
```

## Testing Strategy

### Unit Tests
1. Pango layout creation
2. Cairo surface rendering
3. Texture conversion
4. Cursor positioning (click to index)

### Integration Tests
1. Single-line input: type, backspace, arrows
2. Multi-line editing: Enter, line navigation
3. Selection: mouse drag, Shift+arrows
4. Unicode: Emoji, Arabic, Chinese, Thai
5. BiDi: Mixed Hebrew+English

### Visual Tests
1. Render various scripts
2. Theme integration (fonts, colors)
3. Caret blinking
4. Selection highlighting

## Performance Targets

- **Typing latency**: < 16ms (60fps)
- **Texture update**: Only on text change
- **Memory**: Reuse Cairo surfaces, don't allocate per frame
- **Large text**: Handle 10,000+ characters smoothly

## Files to Create

```
rui2/
├── pango_integration/
│   ├── pango_renderer.nim      # Pango→Cairo→Texture pipeline
│   ├── text_state.nim          # Text buffer, cursor, selection
│   ├── unicode_input.nim       # Keyboard/IME handling
│   └── pango_theme_bridge.nim  # Theme→Pango attributes
├── widgets/
│   ├── textarea_base.nim       # Abstract base
│   ├── textarea.nim            # Full multi-line editor
│   ├── textinput.nim           # Single-line input
│   └── textdisplay.nim         # Read-only formatted text
└── examples/
    ├── pango_test.nim          # Basic Pango rendering
    ├── textarea_test.nim       # Full TextArea demo
    ├── textinput_test.nim      # Form with TextInput fields
    └── unicode_test.nim        # Various scripts (Arabic, Thai, Emoji)
```

## Dependencies

- `pangolib_binding` (existing at ~/prog/pangolib_binding)
- Cairo (via pangolib_binding)
- Pango (via pangolib_binding)
- Raylib (already integrated)

## Success Criteria

✅ Type ASCII text smoothly
✅ Type Unicode (emoji, Chinese, Arabic) correctly
✅ Cursor positioning works with mouse clicks
✅ Selection works (mouse drag, Shift+arrows)
✅ BiDi text displays correctly (Hebrew+English mixed)
✅ Rich formatting works (<b>, <i>, colors)
✅ Theme integration (fonts, colors from theme)
✅ Single-line TextInput widget
✅ Multi-line TextArea widget
✅ Read-only TextDisplay widget
✅ Performance: 60fps even with large text

## Timeline Estimate

- **Phase 1** (Exploration): 1-2 hours
- **Phase 2** (Pango→Raylib bridge): 2-3 hours
- **Phase 3** (Basic TextArea): 3-4 hours
- **Phase 4** (Advanced features): 4-5 hours
- **Phase 5** (Rich text): 2-3 hours
- **Phase 6** (TextInput): 1-2 hours
- **Phase 7** (TextDisplay): 1 hour

**Total**: ~15-20 hours of focused work

## Notes

- Start simple: ASCII-only single-line first
- Add Unicode after basic editing works
- BiDi is complex, test thoroughly
- Texture caching is critical for performance
- Pango handles most hard problems (shaping, wrapping, BiDi)
- Trust Pango's layout functions for cursor/selection

---

**Status**: Ready to begin
**Next Action**: Explore ~/prog/pangolib_binding codebase
