# Next Steps for RUI2

## Current Status

✅ **Complete**:
- Hit-testing system with interval trees
- Widget type with all necessary fields
- Drawing primitives library
- Layout calculation helpers
- Example UIs

## Architecture Decision: OOP + defineWidget Macro

**Decision**: Use method-based OOP with `defineWidget` macro for user extensibility.

See `WIDGET_ARCHITECTURE_DECISION.md` for full analysis.

## Implementation Plan

### Phase 1: Refactor Widget System (2-3 hours)

1. **Simplify Widget base type** (`core/types.nim`):
   - Remove `WidgetKind` enum (not needed with OOP)
   - Keep only common fields
   - Define base methods (render, measure, layout, handleInput)

2. **Port `defineWidget` macro** (`core/widget_dsl.nim`):
   - Take from `/home/kl/prog/rui/dsl/enhanced_widget.nim`
   - Update to work with new Widget type
   - Add support for new fields (stringId, previousBounds, etc.)

3. **Create built-in widgets** (`widgets/` directory):
   ```
   widgets/
     button.nim        - defineWidget(Button)
     label.nim         - defineWidget(Label)
     text_input.nim    - defineWidget(TextInput)
     checkbox.nim      - defineWidget(Checkbox)
     panel.nim         - defineWidget(Panel)
   ```

4. **Create container widgets** (`widgets/containers/`):
   ```
   widgets/containers/
     vstack.nim        - defineWidget(VStack)
     hstack.nim        - defineWidget(HStack)
     grid.nim          - defineWidget(Grid)
     dock.nim          - defineWidget(DockContainer)
   ```
   - Use existing layout code from `layout_calcs.nim`

### Phase 2: Integrate with Hit-Testing (30 min)

1. Update hit-testing to work with Widget base class
2. Add hover/pressed state management
3. Wire up input events to `handleInput` method

### Phase 3: Example & Testing (1 hour)

1. Rewrite `ui_examples.nim` using `defineWidget` widgets
2. Create hit-testing demo that works
3. Create a custom user widget example (e.g., ProgressRing, Gauge)

### Phase 4: YAML-UI Integration (Future)

Once widgets work:
1. Parse YAML-UI files
2. Instantiate widgets from YAML
3. Wire up reactive bindings (Link[T])

## File Structure

```
rui2/
├── core/
│   ├── types.nim              # Base Widget + common types
│   ├── widget_dsl.nim         # defineWidget macro
│   ├── widget_builder.nim     # Helper functions (keep for tests)
│   └── link.nim               # Reactive system
│
├── widgets/
│   ├── button.nim
│   ├── label.nim
│   ├── text_input.nim
│   ├── checkbox.nim
│   ├── panel.nim
│   └── containers/
│       ├── vstack.nim
│       ├── hstack.nim
│       ├── grid.nim
│       └── dock.nim
│
├── drawing_primitives/
│   ├── drawing_primitives.nim  # All drawing functions
│   ├── layout_calcs.nim        # Reuse these!
│   └── layout_core.nim         # Reuse these!
│
├── hit-testing/
│   ├── interval_tree.nim
│   └── hittest_system.nim
│
├── managers/
│   ├── render_manager.nim
│   ├── layout_manager.nim
│   ├── event_manager.nim
│   └── hit_test_manager.nim
│
└── examples/
    ├── basic_widgets.nim
    ├── custom_widget.nim
    ├── dashboard.nim
    └── hit_testing_demo.nim
```

## Priority for Next Session

**Top Priority**: Get `defineWidget` macro working

**Steps**:
1. Copy `enhanced_widget.nim` to `core/widget_dsl.nim`
2. Update macro to generate methods instead of procs
3. Simplify Widget base type (remove kind enum)
4. Create one example widget (Button) using the macro
5. Test that it renders correctly

**Goal**: User can write:

```nim
defineWidget(Button):
  props:
    text: string

  init:
    widget.bounds = newRect(0, 0, 100, 40)

  render:
    drawRoundedRect(widget.bounds, 4.0, BLUE, filled = true)
    drawText(widget.text, ...)
```

And it just works!

## Questions to Address

1. **Do we need `measure()` method?**
   - Yes! Flutter-style layout needs it
   - Each widget reports its preferred size
   - Constraints passed down, sizes returned up

2. **How do containers handle layout?**
   - Override `layout()` method
   - Use helpers from `layout_calcs.nim`
   - Example: VStack.layout() positions children vertically

3. **How does hit-testing integrate?**
   - RenderManager maintains HitTestSystem
   - After layout pass, rebuild hit-test trees
   - On mouse event, query hit-test, dispatch to widget.handleInput()

4. **How do we avoid the compilation issues we had?**
   - Keep widgets in separate files
   - Import only what's needed
   - Use forward declarations if needed

## Success Criteria

We know it's working when:

✅ User can write `defineWidget(CustomGauge)` and it compiles
✅ Custom widget can use all drawing primitives
✅ Custom widget shows up in UI and responds to clicks
✅ Built-in widgets (Button, Label) work the same way
✅ Hit-testing works with custom widgets
✅ Layout system positions widgets correctly

## Timeline Estimate

- Phase 1 (Widget system): 2-3 hours
- Phase 2 (Hit-testing): 30 min
- Phase 3 (Examples): 1 hour
- **Total**: ~4 hours to solid foundation

Then we can add:
- Link[T] reactive system
- YAML-UI parser
- Event manager
- More widgets
- etc.

## Notes

- Reuse existing `layout_calcs.nim` and `layout_core.nim` - they're good!
- Reuse existing `drawing_primitives.nim` - comprehensive!
- The `defineWidget` macro already exists - just needs updating
- Focus on getting one widget working end-to-end first (baby steps!)
