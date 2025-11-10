# DSL v2 Implementation Status

## ✅ Completed: definePrimitive Macro

The `definePrimitive` macro is fully implemented and tested.

### What It Generates

From this DSL:
```nim
definePrimitive(Button):
  props:
    text: string
    disabled: bool = false

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed.value = true
        return true

  render:
    echo "Rendering: ", widget.text
```

It generates:
1. **Type definition** with all fields (props + state as Link[T] + actions as Option[proc])
2. **Constructor** (`newButton`) with:
   - Props as required/optional parameters
   - Actions as optional proc parameters (default nil)
   - Automatic state initialization with `newLink(defaultValue)`
   - Action wrapping in `Option[proc]`
3. **render() method** with visibility check and child rendering
4. **handleInput() method** with event routing (on_mouse_down → evMouseDown)

### Test Results

**Simple Label** (props only):
- ✅ Compiles correctly
- ✅ Constructor works with default parameters
- ✅ Render method executes
- See: `examples/dsl_test_label.nim`

**Button** (props + state + actions + events):
- ✅ Compiles correctly
- ✅ State as Link[bool] works
- ✅ Action callbacks fire correctly
- ✅ Event routing works (mouse down/up)
- ✅ State changes persist
- See: `examples/dsl_test_button.nim`

### Implementation Details

**File**: `core/widget_dsl_v2.nim`

**Key Features**:
- Props with defaults: `fontSize: float = 14.0` → optional constructor parameter
- State auto-wrapping: `pressed: bool` → `Link[bool]` field, initialized with `newLink(false)`
- Action signatures: `onClick()` → `Option[proc()]` field, nil default in constructor
- Event mapping: `on_mouse_up` → case branch for `evMouseUp`
- Proper AST construction (manually built type def, can't splice RecList into quote)

**Code Metrics**:
- Manual Button implementation: ~80 lines (type + constructor + methods)
- DSL Button definition: ~30 lines (just the logic)
- **62% code reduction**

## 🚧 Known Issues and Limitations

### 1. Link API Inconsistency

Currently, Link uses `.value` for both read and write:
```nim
let x = widget.isPressed.value     # Read
widget.isPressed.value = true      # Write
```

This is inconsistent with documentation which showed `.get()` and `.set()`.

**Solution**: Add convenience methods to Link:
```nim
proc get*[T](link: Link[T]): T = link.value
proc set*[T](link: Link[T], val: T) = link.value = val
```

### 2. Base Widget Field Conflicts

The base `Widget` type has `pressed`, `hovered`, `focused` as plain bool fields.

With reactive state, widgets may want these as `Link[bool]` instead.

**Current workaround**: Use different names (`isPressed`, `isHovered`)

**Proper solution**:
- Remove `pressed`, `hovered`, `focused` from base Widget
- Let each widget define its own reactive state
- These fields are widget-specific anyway

### 3. Layout Block Not Implemented

The `layout:` block for hybrid primitives is marked TODO:
```nim
definePrimitive(Slider):
  layout:
    # Internal composition
    hstack:
      SliderTrack(...)
      SliderThumb(...)
```

This needs:
- Layout DSL parser
- Container creation (hstack, vstack, zstack)
- Child widget instantiation
- Integration with render

### 4. defineWidget Not Implemented

The composite widget macro is still a stub:
```nim
defineWidget(VStack):
  props:
    spacing: float = 8.0

  layout:
    # User-provided children arranged vertically
```

Needs:
- Similar to definePrimitive but REQUIRES layout block
- Public `addChild()` method
- Children are public API
- No render block (children render themselves)

## 📋 Next Steps

### Priority 1: Add Link Convenience Methods

Add to `core/link.nim`:
```nim
proc get*[T](link: Link[T]): T =
  link.value

proc set*[T](link: Link[T], val: T) =
  link.value = val
```

This matches the documented API and makes code cleaner.

### Priority 2: Clean Up Base Widget Type

Remove conflicting state fields:
```nim
type Widget = ref object of RootObj
  # Remove these (widget-specific, should be in Link[T]):
  # hovered*: bool
  # pressed*: bool
  # focused*: bool

  # Keep these (truly shared across all widgets):
  id*: WidgetId
  bounds*: Rect
  visible*: bool
  enabled*: bool
  isDirty*: bool
  layoutDirty*: bool
  children*: seq[Widget]
  parent*: Widget
  # etc.
```

### Priority 3: Implement defineWidget Macro

Similar structure to definePrimitive but:
- Layout block is REQUIRED
- Generates public `addChild()` method
- Children are part of public API
- No render block (or render only draws decorations)

### Priority 4: Implement Layout DSL

Parse layout blocks:
```nim
layout:
  vstack:           # Creates container
    spacing = 10    # Sets property
    Label(...)      # Adds child
    Button(...)     # Adds child
```

This is shared between definePrimitive (internal layout) and defineWidget (public children).

### Priority 5: Port Hummingbird Widgets

Once macros are complete, port the 35 widgets from Hummingbird:
- Basic inputs: Button, TextInput, Checkbox, etc.
- Display: Label, Image, ProgressBar, etc.
- Containers: VStack, HStack, ZStack, ScrollView, etc.
- Complex: DatePicker, ColorPicker, TreeView, etc.

## 📝 Testing Strategy

Each widget should have:
1. **Unit test**: Test widget in isolation (like dsl_test_button.nim)
2. **Visual test**: Render widget to window, interact with it
3. **Integration test**: Use widget in realistic app context

## 🎯 Success Criteria

The DSL v2 system is complete when:
- ✅ definePrimitive works for simple widgets (Label, Button)
- ✅ definePrimitive works with state and actions
- ✅ Event routing works correctly
- ✅ Link has clean get/set API
- ⬜ Base Widget type is clean (no conflicts)
- ⬜ Layout block works (internal composition) - for hybrid primitives
- ✅ defineWidget works for containers
- ⬜ All 35 Hummingbird widgets ported
- ⬜ Full app built with new DSL

## 📊 Current Progress

**definePrimitive**: 95% complete (missing internal layout DSL for hybrid primitives)
**defineWidget**: 100% complete ✅
**Link API**: 100% complete ✅ (get/set methods added)
**Documentation**: 100% complete (all design docs written)
**Testing**: 60% complete (5 widget tests: Label, Button, VStack, HStack, Combined)

**Overall**: ~70% complete

## 🔍 Code Examples

### What Works Now ✅

```nim
# Simple primitive widget
definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
  render:
    drawText(widget.text, widget.bounds, fontSize = widget.fontSize)

let label = newLabel("Hello", fontSize = 16.0)
label.render()
```

```nim
# Complex primitive with state and actions
definePrimitive(Button):
  props:
    text: string
    disabled: bool = false

  state:
    isPressed: bool

  actions:
    onClick()

  events:
    on_mouse_up:
      if not widget.disabled and widget.onClick.isSome:
        widget.onClick.get()()

  render:
    let bg = if widget.isPressed.get(): darkGray else: lightGray
    drawRect(widget.bounds, bg)
    drawText(widget.text, widget.bounds)

let button = newButton("Click", onClick = proc() = echo "Clicked!")
button.handleInput(mouseUpEvent)
```

```nim
# Composite widget ✅ WORKS NOW!
defineWidget(VStack):
  props:
    spacing: float = 8.0

  layout:
    # Arrange user-provided children vertically
    var y = widget.bounds.y
    for child in widget.children:
      child.bounds.y = y
      y += child.bounds.height + widget.spacing

let stack = newVStack(spacing = 10.0)
stack.children.add(newLabel("Title"))
stack.children.add(newButton("Click"))
stack.updateLayout()
stack.render()
```

```nim
# Combined: Building UI hierarchy ✅ WORKS NOW!
let ui = newVStack(spacing = 10.0)
ui.children.add(newLabel("Welcome!"))

let buttons = newHStack(spacing = 5.0)
buttons.children.add(newButton("OK"))
buttons.children.add(newButton("Cancel"))

ui.children.add(buttons)
ui.render()
```

### What Doesn't Work Yet ⚠️

```nim
# Internal layout DSL for hybrid primitives (not implemented yet)
definePrimitive(Slider):
  props:
    value: float

  layout:  # ❌ TODO - declarative child creation
    hstack:
      SliderTrack(value: widget.value)
      SliderThumb(position: widget.value)
```

Currently, for hybrid primitives, you need to manually create children in the init block.

## 📂 File Organization

```
core/
  widget_dsl_v2.nim          # ✅ Macro implementation
  types.nim                  # ⚠️  Needs cleanup (remove pressed/hovered)
  link.nim                   # ⚠️  Needs get/set methods

examples/
  dsl_test_label.nim         # ✅ Simple widget test
  dsl_test_button.nim        # ✅ Complex widget test
  dsl_test_manual_vs_macro.nim  # ✅ Comparison example

documentation/
  WIDGET_DSL_STANDARD.md     # ✅ DSL specification
  DSL_CLARIFICATIONS.md      # ✅ Design decisions
  PRIMITIVE_PURITY_ANALYSIS.md  # ✅ Hybrid widget analysis
  DSL_HYBRID_DESIGN.md       # ✅ Dual macro design
  DSL_V2_STATUS.md           # ✅ This file
```
