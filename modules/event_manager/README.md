# Event Manager Module

Time-budgeted event processing with pattern-based coalescing and keyboard focus management.

## Public API

```nim
import modules/event_manager/api
```

### Core Types
- `EventManager` — Central event coordinator with priority queue and pattern routing
- `FocusManager` — Keyboard focus tracking and tab navigation

### Event Patterns

| Pattern | Behavior | Use Case |
|---|---|---|
| `epNormal` | Process immediately | Default |
| `epReplaceable` | Keep only last event | Mouse move |
| `epDebounced` | Wait for quiet period | Window resize |
| `epThrottled` | Rate limited | Scroll |
| `epBatched` | Collect N events | Touch gestures |
| `epOrdered` | Preserve sequence | Keyboard input |

### Key Functions

**EventManager:**
- `newEventManager(budget)` — Create with default time budget
- `addEvent(em, event)` — Route event by pattern
- `update(em)` — Flush replaceable/batched events (call once per frame)
- `processEvents(em, budget, handler)` — Process within time budget
- `hasPendingEvents(em)` — Check for pending work

**FocusManager:**
- `newFocusManager()` — Create with Tab/Shift+Tab navigation
- `setFocus(fm, widget)` — Focus a widget (auto-unfocuses previous)
- `nextFocus(fm, root)` / `prevFocus(fm, root)` — Tab navigation
- `handleKeyboardEvent(fm, event, root)` — Route keyboard events

### Testing Without Graphics

```nim
var em = newEventManager()
em.addEvent(GuiEvent(kind: evMouseMove, priority: epNormal, ...))
em.update()
assert em.hasPendingEvents()
```

### Dependencies
- `core/types` (GuiEvent, EventKind, Widget, etc.)
