# RUI2 Modules

Self-contained, independently importable subsystems extracted from the RUI2 core.

## Quick Start

```nim
# Import everything (traditional)
import rui

# Import individual modules (new, modular)
import modules/link/api
import modules/theme/api
import modules/hit_testing/api
```

## Module Map

```
modules/
  hit_testing/         Spatial queries via dual interval trees
  event_manager/       Time-budgeted event processing + focus management
  theme/               State/intent-based theming with property merging
  pango_text/          Pango+Cairo text rendering with LRU caching
  layout/              Flutter-style two-pass layout (HStack, VStack, Grid, ...)
  widget_dsl/          defineWidget / definePrimitive macros
  link/                Link[T] reactive unidirectional data binding
  widgets/             All UI widgets (primitives, basic, containers)
  drawing_primitives/  Layered drawing: shapes -> effects -> themed widgets
```

## Module Overview

| Module | Public API | Description | Headless? |
|---|---|---|---|
| `hit_testing` | `modules/hit_testing/api` | O(log n) spatial queries with interval trees | Yes |
| `event_manager` | `modules/event_manager/api` | Event coalescing, time budgets, focus | Yes |
| `theme` | `modules/theme/api` | ThemeProps lookup by (intent, state) with caching | Yes |
| `pango_text` | `modules/pango_text/api` | Pango text rendering + texture cache | No (needs Pango) |
| `layout` | `modules/layout/api` | Layout types, spacing/alignment calculations | Yes |
| `widget_dsl` | `modules/widget_dsl/api` | Nim macros for widget definition | Yes |
| `link` | `modules/link/api` | Reactive binding with O(1) dirty marking | Yes |
| `widgets` | `modules/widgets/api` | Label, Button, VStack, ScrollView, etc. | Partial |
| `drawing_primitives` | `modules/drawing_primitives/api` | Shapes, effects, themed rendering | No (needs Raylib) |

## Architecture

```
                          ┌──────────────┐
                          │   core/types │  (Widget, Rect, Color, etc.)
                          └──────┬───────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
        ┌─────┴─────┐    ┌──────┴──────┐    ┌───────┴───────┐
        │   link     │    │   layout    │    │  hit_testing  │
        │  Link[T]   │    │  HStack/    │    │  IntervalTree │
        │  binding   │    │  VStack/etc │    │  findWidgetAt │
        └─────┬──────┘    └──────┬──────┘    └───────┬───────┘
              │                  │                   │
        ┌─────┴─────┐    ┌──────┴──────┐    ┌───────┴───────┐
        │widget_dsl │    │   theme     │    │event_manager  │
        │ macros    │    │  ThemeProps  │    │  coalescing   │
        └─────┬─────┘    └──────┬──────┘    │  focus mgr    │
              │                  │           └───────┬───────┘
              │                  │                   │
        ┌─────┴──────────────────┴───────────────────┘
        │
  ┌─────┴──────────┐         ┌────────────────┐
  │    widgets      │─────────│drawing_prims   │
  │ Button, Label,  │ uses    │ shapes, effects│
  │ VStack, etc.    │         │ widget prims   │
  └────────────────┘         └───────┬────────┘
                                     │
                              ┌──────┴──────┐
                              │ pango_text  │
                              │ text cache  │
                              └─────────────┘
```

## Dependency Rules

1. All modules depend on `core/types` (Widget, Rect, Color, etc.)
2. `link` has no other module dependencies
3. `hit_testing` has no other module dependencies
4. `event_manager` has no other module dependencies
5. `layout` has no other module dependencies
6. `theme` depends on `drawing_primitives/primitives/text` (for TextStyle)
7. `widget_dsl` depends on `link`
8. `widgets` depend on `widget_dsl` and `drawing_primitives`
9. `drawing_primitives` depends on `theme` (for ThemeProps)
10. `pango_text` depends on external `pangolib_binding`

## Testing Without Graphics

Most modules work headlessly (compile without `-d:useGraphics`):

```nim
# Test hit testing
var system = newHitTestSystem()
var w = Widget(bounds: Rect(x: 0, y: 0, width: 100, height: 50))
system.insertWidget(w)
assert system.getWidgetAt(50, 25) == w

# Test link binding
var link = newLink(0)
var widget = Widget(isDirty: false)
link.addDependent(widget)
link.set(42)
assert widget.isDirty

# Test layout calculations
let inner = applyPadding(Rect(x: 0, y: 0, width: 800, height: 600),
                         EdgeInsets(top: 10, right: 10, bottom: 10, left: 10))
assert inner.width == 780

# Test theme
var theme = createLightTheme()
let props = theme.getThemeProps(Default, Hovered)
assert props.cornerRadius.isSome

# Test event manager
var em = newEventManager()
em.addEvent(GuiEvent(kind: evMouseMove))
assert em.hasPendingEvents()
```

## Migrating Existing Code

The original import paths still work. The `rui.nim` entry point is unchanged. To use modules individually:

```nim
# Before (still works):
import rui

# After (pick what you need):
import modules/link/api
import modules/theme/api
import modules/widgets/api
```

Each module has its own README with full API documentation.
