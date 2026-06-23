# rui_core

Shared base for all RUI2 packages.

Part of the [RUI2](https://github.com/kobi2187/rui2) monorepo. Self-contained and
`git subtree split`-ready (see [SPLITTING.md](../../SPLITTING.md)).

**Depends on:** naylib

```nim
import rui_core
```

Provides the core types (`Widget`, `Rect`, `Color`, events), the reactive
`Link[T]` primitive with O(1) dirty-marking, the two-pass layout/render main
loop, and the `definePrimitive` / `defineWidget` DSL macros.
