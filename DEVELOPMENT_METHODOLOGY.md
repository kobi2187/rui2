# RUI Development Methodology

**TDD-style approach: Baby steps with running examples**

---

## Core Principle

> **Build tiny, verify it works (renders!), then grow.**

We don't just want code that compiles - we want code that **runs and displays something on screen** at every step.

---

## The Baby Steps Approach

### 1. Start Tiny

Each component begins with the absolute minimal example:

```nim
# Example: Testing Link[T] system
# File: examples/baby/01_link_basic.nim

import raylib
import rui/core/link

type MyStore = ref object
  counter: Link[int]

proc main() =
  initWindow(400, 300, "Test: Link[T]")
  defer: closeWindow()

  let store = MyStore(counter: newLink(0))

  # Just test that Link works
  echo "Initial: ", store.counter.value
  store.counter.value = 42
  echo "After change: ", store.counter.value

  while not windowShouldClose():
    beginDrawing()
    clearBackground(RAYGREEN)
    drawText("Link[T] works! Check console.", 10, 10, 20, WHITE)
    drawText("Counter: " & $store.counter.value, 10, 40, 20, WHITE)
    endDrawing()

main()
```

**Verification**: Does it run? Does it display? Can we see the value change?

### 2. Add One Feature

Once the tiny example works, add ONE more feature:

```nim
# File: examples/baby/02_link_with_widget.nim

# Now test: Link + Widget binding
# Add minimal Widget type
type Widget = ref object
  text: string
  isDirty: bool

# Test that Link can store widget reference
let widget = Widget(text: "Label", isDirty: false)
store.counter.dependentWidgets.incl(widget)

# When value changes, does widget get marked dirty?
store.counter.value = 100
assert widget.isDirty == true  # Verify it worked!
```

**Verification**: Does the binding work? Is the widget marked dirty?

### 3. Test Rendering

Next step: Actually render something:

```nim
# File: examples/baby/03_link_widget_render.nim

# Now render a widget that responds to Link changes
proc renderWidget(widget: Widget, x, y: int) =
  if widget.isDirty:
    # Render new content
    widget.cachedTexture = renderToTexture(widget.text)
    widget.isDirty = false

  drawTexture(widget.cachedTexture, x, y)

# In main loop:
while not windowShouldClose():
  beginDrawing()
  clearBackground(RAYGREEN)

  # Update data
  if isKeyPressed(KEY_SPACE):
    store.counter.value += 1
    # Widget should auto-mark dirty!

  # Render widget
  renderWidget(widget, 100, 100)

  endDrawing()
```

**Verification**: Press space, does the displayed number update? Is texture caching working?

### 4. Grow Gradually

Each example builds on the previous:

```
01_link_basic.nim          → Link[T] value storage works
02_link_with_widget.nim    → Link can track widget dependencies
03_link_widget_render.nim  → Widget updates when Link changes
04_two_widgets.nim         → Multiple widgets bound to same Link
05_nested_store.nim        → Store with multiple Links
06_layout_basic.nim        → Add simple layout (VStack)
07_theme_basic.nim         → Add theme support
... and so on
```

---

## Implementation Strategy

### Phase 1: Core Types (Verify Each!)

```
1. examples/baby/01_rect_type.nim
   → Test Rect type works, draw a rectangle

2. examples/baby/02_widget_base.nim
   → Test Widget type, draw multiple widgets

3. examples/baby/03_widget_bounds.nim
   → Test bounds detection, click to select widget
```

### Phase 2: Link System (Build Up)

```
4. examples/baby/04_link_value.nim
   → Link stores value, value changes

5. examples/baby/05_link_dependency.nim
   → Link tracks one widget dependency

6. examples/baby/06_link_multi_deps.nim
   → Link tracks multiple widget dependencies

7. examples/baby/07_link_render.nim
   → Link change triggers widget re-render
```

### Phase 3: Layout (One Container at a Time)

```
8. examples/baby/08_vstack_two_widgets.nim
   → VStack with 2 children, vertical positioning

9. examples/baby/09_vstack_spacing.nim
   → VStack with spacing between children

10. examples/baby/10_vstack_padding.nim
    → VStack with padding around content

11. examples/baby/11_hstack_basic.nim
    → HStack with horizontal positioning

12. examples/baby/12_nested_stacks.nim
    → VStack containing HStack
```

### Phase 4: Pango Integration (Text by Text)

```
13. examples/baby/13_pango_hello.nim
    → Render "Hello" with Pango, display on screen

14. examples/baby/14_pango_unicode.nim
    → Render "שלום" (Hebrew) - test BiDi

15. examples/baby/15_pango_multiline.nim
    → Render multi-line text with wrapping

16. examples/baby/16_pango_label.nim
    → Label widget using Pango
```

### Phase 5: Events (Interaction by Interaction)

```
17. examples/baby/17_click_detect.nim
    → Detect mouse click on widget

18. examples/baby/18_button_click.nim
    → Button responds to click

19. examples/baby/19_hover_state.nim
    → Button changes on hover

20. examples/baby/20_click_updates_link.nim
    → Button click updates Link, Label updates
```

### Phase 6: Integration (Small Complete Apps)

```
21. examples/baby/21_counter_app.nim
    → Complete counter (Button + Label + Link)

22. examples/baby/22_two_counters.nim
    → Two independent counters

23. examples/baby/23_form_example.nim
    → Form with multiple inputs

24. examples/baby/24_theme_switcher.nim
    → Theme switching demo
```

---

## Development Workflow

### For Each Component:

1. **Write minimal example** in `examples/baby/NN_feature.nim`
2. **Compile**: `nim c examples/baby/NN_feature.nim`
3. **Run**: `./examples/baby/NN_feature`
4. **Verify**: Does it display correctly? Does interaction work?
5. **Fix**: If not, debug and fix
6. **Document**: Add comment at top of file explaining what it tests
7. **Commit**: Once working, commit the example + component code
8. **Log**: Update PROGRESS_LOG.md with what works

### Test Checklist for Each Example:

- [ ] Compiles without errors
- [ ] Runs without crashing
- [ ] Window displays correctly
- [ ] Content renders as expected
- [ ] Interaction works (if applicable)
- [ ] Console output is correct (if using echo)
- [ ] No memory leaks (run with valgrind if concerned)

---

## Example File Template

Every baby step example should follow this template:

```nim
# examples/baby/NN_feature_name.nim
#
# What this tests: [Brief description]
# Expected behavior: [What you should see]
# How to verify: [What to do/check]
#
# Status: [✅ WORKING | 🚧 IN PROGRESS | ❌ BROKEN]

import raylib
import rui/[relevant, modules]

proc main() =
  # Setup
  initWindow(400, 300, "Test: Feature Name")
  defer: closeWindow()
  setTargetFPS(60)

  # Initialize test data
  var testData = createTestData()

  # Main loop
  while not windowShouldClose():
    # Update
    updateTestData(testData)

    # Draw
    beginDrawing()
    clearBackground(RAYGREEN)  # Green = test mode

    drawTestVisuals(testData)

    # Instructions for user
    drawText("Test: Feature Name", 10, 10, 20, WHITE)
    drawText("[Instructions]", 10, 40, 16, WHITE)

    endDrawing()

main()
```

---

## Directory Structure

```
examples/
├── baby/                      # Baby step examples (atomic tests)
│   ├── 01_link_basic.nim
│   ├── 02_link_with_widget.nim
│   ├── 03_link_widget_render.nim
│   └── ...
│
├── integration/               # Slightly larger examples
│   ├── counter_app.nim
│   ├── form_example.nim
│   └── theme_demo.nim
│
└── showcase/                  # Complete applications
    ├── todo_list.nim
    ├── calculator.nim
    └── text_editor.nim
```

---

## Benefits of This Approach

### 1. **Confidence**
Every step is verified to work - no guessing if things are broken.

### 2. **Debuggability**
Tiny examples are easy to debug. If `07_theme_basic.nim` breaks, you know the theme system has an issue.

### 3. **Documentation**
Examples serve as living documentation showing exactly how each feature works.

### 4. **Regression Testing**
If you break something, you can run all baby examples to see what failed.

### 5. **Onboarding**
New contributors can understand the system by reading examples in order.

### 6. **Progress Tracking**
Each working example is visible progress - keeps motivation high!

---

## Anti-Patterns to Avoid

### ❌ Don't: Write lots of code before testing
```nim
# Bad: Implement entire Layout system before testing anything
proc layoutVStack() = ...
proc layoutHStack() = ...
proc layoutGrid() = ...
proc layoutFlex() = ...
# Never tested any of these!
```

### ✅ Do: Test each piece immediately
```nim
# Good: Test VStack alone first
proc layoutVStack() = ...

# examples/baby/08_vstack.nim - VERIFY IT WORKS!
# Then move on to HStack...
```

### ❌ Don't: Skip visual verification
```nim
# Bad: Just check that it compiles
assert widget.bounds.x == 100  # But does it LOOK right on screen?
```

### ✅ Do: Always render to screen
```nim
# Good: Draw it and SEE that it's positioned correctly
drawWidget(widget)
drawText("Widget at x=100", 10, 10, 16, WHITE)
```

### ❌ Don't: Make giant examples
```nim
# Bad: First example tests everything
# - Link system
# - Layout
# - Events
# - Themes
# - 10 different widgets
# Which part is broken when it fails???
```

### ✅ Do: One concept per example
```nim
# Good: This example ONLY tests Link[T] value changes
# If it breaks, we know Link[T] has the problem
```

---

## Success Criteria

An example is "complete" when:

1. ✅ Compiles without warnings
2. ✅ Runs without crashes
3. ✅ Displays expected visuals
4. ✅ User interaction works (if applicable)
5. ✅ Console output is correct (if using)
6. ✅ Code is commented explaining what it tests
7. ✅ Status marked as ✅ WORKING in file header

---

## Progress Tracking

Maintain a checklist in PROGRESS_LOG.md:

```markdown
### Baby Step Examples Progress

#### Phase 1: Core Types
- [x] 01_rect_type.nim - Basic Rect rendering
- [x] 02_widget_base.nim - Widget with bounds
- [ ] 03_widget_bounds.nim - Click detection

#### Phase 2: Link System
- [ ] 04_link_value.nim - Value storage
- [ ] 05_link_dependency.nim - Widget tracking
...
```

---

## Implementation Start Point

**Next Session: Begin with Link[T] system**

Create in this order:
1. `rui/core/link.nim` - Minimal Link[T] implementation
2. `examples/baby/01_link_basic.nim` - Test value storage
3. Run, verify, commit
4. Add widget tracking to Link[T]
5. `examples/baby/02_link_with_widget.nim` - Test dependency
6. Run, verify, commit
7. Continue...

**Golden Rule**: Never move forward until current example works!

---

*Baby steps ensure we build on solid ground. Every component is proven to work before we build the next layer.*
