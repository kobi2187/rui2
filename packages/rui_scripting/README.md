# rui_scripting

File-based GUI automation for testing.

Part of the [RUI2](https://github.com/kobi2187/rui2) monorepo. Self-contained and
`git subtree split`-ready (see [SPLITTING.md](../../SPLITTING.md)).

**Depends on:** rui_core

```nim
import rui_scripting
```

A file-based protocol to query and set widget values for automated testing:
address widgets by id or CSS-like path, per-widget script actions/state, and a
`blockReading` privacy flag. Ships a `client.nim` driver and examples.
