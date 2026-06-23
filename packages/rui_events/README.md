# rui_events

Event processing and focus management.

Part of the [RUI2](https://github.com/kobi2187/rui2) monorepo. Self-contained and
`git subtree split`-ready (see [SPLITTING.md](../../SPLITTING.md)).

**Depends on:** rui_core

```nim
import rui_events
```

A time-budgeted event manager with coalescing patterns (replaceable, debounced,
throttled, batched, ordered) and a focus manager (focus tracking + keyboard
routing).
