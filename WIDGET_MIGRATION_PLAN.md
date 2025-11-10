# Widget Migration Plan - DSL v1 → v2

## Current State

Existing widgets use `widget_dsl` (v1) which has:
- `defineWidget` macro
- `init:`, `render:`, `measure:`, `layout:`, `input:` blocks
- Mixed concerns (primitives and composites both use defineWidget)

## New Architecture (DSL v2)

Clear separation:
- **definePrimitive** = Pure drawing (Label, Rectangle, Circle)
- **defineWidget** = Composition (Button, VStack, Checkbox)

## Migration Strategy

### Phase 1: Create New Primitives (definePrimitive)
These wrap `drawing_primitives` functions:

✅ widgets/primitives/label.nim - Wraps drawText
✅ widgets/primitives/rectangle.nim - Wraps drawRect/drawRoundedRect
✅ widgets/primitives/circle.nim - Wraps drawCircle
⬜ widgets/primitives/line.nim - Wraps drawLine
⬜ widgets/primitives/icon.nim - Wraps drawTexture

### Phase 2: Migrate Composite Widgets (defineWidget)
Rewrite to compose primitives:

⬜ widgets/basic/button_v2.nim - Rectangle + Label
⬜ widgets/basic/checkbox_v2.nim - Rectangle + Circle + Label
⬜ widgets/containers/vstack_v2.nim - Layout container
⬜ widgets/containers/hstack_v2.nim - Layout container
⬜ widgets/containers/zstack_v2.nim - Layout container

### Phase 3: Test & Replace
- Test new widgets with real rendering
- Once verified, replace old widgets
- Update examples to use v2

## Key Differences

### Old DSL v1:
```nim
defineWidget(Button):
  props:
    text: string
    onClick: ButtonCallback  # Direct proc

  init:
    widget.text = "Button"
    widget.onClick = nil

  render:
    drawRoundedRect(widget.bounds, ...)  # Direct drawing
    drawText(widget.text, ...)

  input:
    if event.kind == evMouseUp:
      if widget.onClick != nil:
        widget.onClick()
```

### New DSL v2:
```nim
defineWidget(Button):
  props:
    text: string

  state:
    isPressed: bool  # Reactive Link[bool]

  actions:
    onClick()  # Signature, wrapped in Option[proc]

  events:
    on_mouse_up:  # Declarative
      if widget.onClick.isSome:
        widget.onClick.get()()

  layout:
    # Compose primitives
    widget.children.add(newRectangle(...))
    widget.children.add(newLabel(...))
```

## Benefits of Migration

1. **Clear separation**: Primitives just draw, composites just arrange
2. **Reactive state**: Link[T] with automatic dirty tracking
3. **Better composition**: Button IS Rectangle + Label, not draws like them
4. **Type safety**: Actions as Option[proc] with proper signatures
5. **Declarative events**: on_mouse_up instead of if event.kind
6. **Two-pass rendering**: Automatic layout + render separation

## Migration Checklist

For each widget:
- [ ] Identify if it's a primitive (draws) or composite (composes)
- [ ] Create _v2.nim version using correct macro
- [ ] Update props (remove init defaults, use param defaults)
- [ ] Convert callbacks to actions block
- [ ] Convert input to events block
- [ ] Test with actual rendering
- [ ] Replace old version once verified

## Widget Inventory

### Drawing Primitives (definePrimitive)
- Label - text rendering
- Rectangle - boxes, backgrounds
- Circle - dots, indicators
- Line - dividers, connections
- Icon - images, sprites
- Checkmark - ✓ symbol
- RadioDot - ● symbol

### Composite Widgets (defineWidget)
- Button - Rectangle + Label
- Checkbox - Rectangle + Checkmark + Label
- RadioButton - Circle + RadioDot + Label
- Slider - Rectangle(track) + Rectangle(fill) + Circle(thumb) + Label
- ProgressBar - Rectangle(bg) + Rectangle(fill) + Label
- TextInput - Rectangle + Label (editable)
- Panel - Rectangle(background) + VStack(children)

### Containers (defineWidget)
- VStack - vertical layout
- HStack - horizontal layout
- ZStack - layered layout
- ScrollView - VStack/HStack with scrolling
- Panel - decorated container
- Card - rounded panel with shadow

## Implementation Order

1. ✅ Core primitives (Label, Rectangle, Circle)
2. ⬜ Button (most common, good test case)
3. ⬜ VStack/HStack (essential containers)
4. ⬜ Checkbox, RadioButton (input widgets)
5. ⬜ Slider, ProgressBar (complex composites)
6. ⬜ TextInput (text editing)
7. ⬜ ScrollView, Panel (advanced containers)

## Notes

- Keep old widgets until migration complete (_v2 suffix for new ones)
- Test each widget individually before integration
- Update examples incrementally
- Document any API changes for users
