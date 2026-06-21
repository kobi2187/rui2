# rui_hittest

Spatial hit-testing for widget trees.

Part of the [RUI2](https://github.com/kobi2187/rui2) monorepo. Self-contained and
`git subtree split`-ready (see [SPLITTING.md](../../SPLITTING.md)).

**Depends on:** rui_core

```nim
import rui_hittest
```

A generic interval tree (`interval_tree`) plus a Widget-aware hit-test system
(`hittest_system`) for O(log n) "what is under this point?" queries. The
interval tree has no RUI dependency and can be lifted out on its own.
