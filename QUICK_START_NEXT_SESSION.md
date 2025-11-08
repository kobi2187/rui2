# Quick Start for Next Session

## Where We Left Off

✅ **Hit-testing system complete** - 27 tests passing
✅ **Widget architecture decided** - OOP + defineWidget macro
✅ **Found existing code** - macro, layout helpers, drawing primitives

## What to Do Next (3-4 hours)

### Step 1: Create the widget_dsl.nim module (30 min)

```bash
cd /home/kl/prog/rui2
cp /home/kl/prog/rui/dsl/enhanced_widget.nim core/widget_dsl.nim
```

Then edit `core/widget_dsl.nim`:
1. Update imports to use new paths
2. Change to generate `method` instead of `proc` for render/layout/input
3. Add support for `measure()` method
4. Test compilation

### Step 2: Simplify Widget base type (15 min)

Edit `core/types.nim`:
1. Remove `WidgetKind` enum (not needed with OOP)
2. Remove variant fields (text, colors, etc. - move to specific widgets)
3. Keep only common fields: id, stringId, bounds, visible, enabled, children, parent
4. Add base methods:

```nim
method render*(w: Widget) {.base.} = discard
method measure*(w: Widget, constraints: Constraints): Size {.base.} = ...
method layout*(w: Widget) {.base.} = ...
method handleInput*(w: Widget, event: Event): bool {.base.} = false
```

### Step 3: Create first widget using macro (30 min)

Create `widgets/button.nim`:

```nim
import ../core/[types, widget_dsl]
import ../drawing_primitives/drawing_primitives
import raylib

defineWidget(Button):
  props:
    text: string
    backgroundColor: Color
    textColor: Color
    onClick: proc()

  init:
    widget.text = ""
    widget.backgroundColor = Color(r: 70, g: 130, b: 180, a: 255)
    widget.textColor = WHITE
    widget.bounds = newRect(0, 0, 100, 40)
    widget.onClick = nil

  render:
    var bgColor = widget.backgroundColor
    if widget.pressed:
      bgColor = darken(bgColor, 0.2)  # You'll need to add this helper
    elif widget.hovered:
      bgColor = lighten(bgColor, 0.1)

    drawRoundedRect(widget.bounds, 4.0, bgColor, filled = true)

    if widget.text.len > 0:
      let textWidth = measureText(widget.text, 18'i32)
      let textX = widget.bounds.x + (widget.bounds.width - float32(textWidth)) / 2
      let textY = widget.bounds.y + (widget.bounds.height - 18) / 2
      drawText(widget.text, int32(textX), int32(textY), 18'i32, widget.textColor)

  measure:
    result = Size(width: widget.bounds.width, height: widget.bounds.height)

  input:
    if isMouseButtonPressed(MouseButton.Left):
      if widget.bounds.contains(getMousePosition().x, getMousePosition().y):
        if widget.onClick != nil:
          widget.onClick()
        return true
    return false
```

Compile and fix any errors.

### Step 4: Create simple test (30 min)

Create `examples/button_test.nim`:

```nim
import raylib
import ../widgets/button
import ../core/types

proc main() =
  initWindow(800, 600, "Button Test")
  setTargetFPS(60)

  let btn = newButton()
  btn.text = "Click Me!"
  btn.bounds = newRect(350, 275, 100, 50)
  btn.onClick = proc() =
    echo "Button clicked!"

  while not windowShouldClose():
    # Update hover state
    let mousePos = getMousePosition()
    btn.hovered = btn.bounds.contains(mousePos.x, mousePos.y)

    # Handle input
    discard btn.handleInput(nil)  # TODO: proper event

    # Render
    beginDrawing()
    clearBackground(RAYWHITE)
    btn.render()
    endDrawing()

  closeWindow()

when isMainModule:
  main()
```

Run it: `nim c -r -d:useGraphics button_test.nim`

### Step 5: Add more widgets (1 hour)

Copy button.nim and modify for:
- `widgets/label.nim` - Simple text display
- `widgets/panel.nim` - Container with background

### Step 6: Create VStack container (1 hour)

Create `widgets/containers/vstack.nim`:

```nim
import ../../core/[types, widget_dsl]
import ../../drawing_primitives/[drawing_primitives, layout_calcs]

defineWidget(VStack):
  props:
    spacing: float32
    padding: EdgeInsets
    align: Alignment

  init:
    widget.spacing = 8.0
    widget.padding = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)
    widget.align = Leading

  layout:
    # Use existing layout helpers!
    var y = widget.bounds.y + widget.padding.top
    for child in widget.children:
      let size = child.measure(...)  # Need to pass constraints
      child.bounds.x = widget.bounds.x + widget.padding.left
      child.bounds.y = y
      child.layout()
      y += size.height + widget.spacing

  measure:
    var totalHeight: float32 = 0
    var maxWidth: float32 = 0
    for child in widget.children:
      let size = child.measure(constraints)
      totalHeight += size.height
      maxWidth = max(maxWidth, size.width)
    totalHeight += widget.spacing * float32(widget.children.len - 1)
    result = Size(
      width: maxWidth + widget.padding.left + widget.padding.right,
      height: totalHeight + widget.padding.top + widget.padding.bottom
    )
```

### Step 7: End-to-end test (30 min)

Create `examples/vstack_test.nim`:

```nim
let stack = newVStack()
stack.spacing = 16

let btn1 = newButton()
btn1.text = "Button 1"

let lbl = newLabel()
lbl.text = "Hello, World!"

let btn2 = newButton()
btn2.text = "Button 2"

stack.addChild(btn1)
stack.addChild(lbl)
stack.addChild(btn2)

stack.bounds = newRect(100, 100, 300, 200)
stack.layout()  # Position children

# In render loop
stack.render()  # Renders all children
```

## Files to Reference

**Macro source**:
- `/home/kl/prog/rui/dsl/enhanced_widget.nim` - Copy and modify this

**Existing helpers to use**:
- `drawing_primitives/drawing_primitives.nim` - All drawing functions
- `drawing_primitives/layout_calcs.nim` - Layout calculations
- `drawing_primitives/layout_core.nim` - Container types

**Tests to learn from**:
- `hit-testing/test_interval_tree.nim` - Testing pattern
- `examples/baby/link_basic_01.nim` - Raylib example

## Common Issues & Solutions

**Issue**: Widget type conflicts
**Solution**: Remove old Widget definitions from hittest_system.nim (already done)

**Issue**: Method not found
**Solution**: Make sure base Widget has `{.base.}` methods defined

**Issue**: Macro doesn't compile
**Solution**: Check that all sections (props, init, render) are optional

**Issue**: Can't access drawing_primitives
**Solution**: Import with: `import ../drawing_primitives/drawing_primitives`

## Success Criteria

You know it's working when:

✅ `defineWidget(Button)` compiles
✅ `newButton()` creates a Button
✅ Button renders on screen
✅ Button responds to clicks
✅ Can create VStack with multiple buttons
✅ Layout positions them correctly

## Quick Commands

```bash
# Compile button test
cd /home/kl/prog/rui2/examples
nim c -d:useGraphics button_test.nim

# Run tests
cd /home/kl/prog/rui2/hit-testing
nim c -r test_interval_tree.nim
nim c -r test_hittest_system.nim

# Check what's in drawing primitives
grep "^proc " /home/kl/prog/rui2/drawing_primitives/drawing_primitives.nim | head -20
```

## Baby Steps Approach

1. Get macro compiling (even if it does nothing)
2. Get Button to compile (even if it doesn't render)
3. Get Button to render (even if it doesn't respond to clicks)
4. Get Button to respond to clicks
5. Get VStack to compile
6. Get VStack to layout children
7. Get example with VStack + Buttons working

Each step should compile and run before moving to next!

## Estimated Time

- Macro porting: 30 min
- Widget simplification: 15 min
- First widget (Button): 30 min
- Test it: 30 min
- More widgets: 1 hour
- Container (VStack): 1 hour
- End-to-end: 30 min

**Total**: 3-4 hours to working foundation

Then you can build anything!

---

**Key Insight**: The macro already exists. You have all the pieces. Just need to connect them. Baby steps! 🚀
