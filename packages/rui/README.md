# rui

Umbrella package: the whole framework.

Part of the [RUI2](https://github.com/kobi2187/rui2) monorepo. Self-contained and
`git subtree split`-ready (see [SPLITTING.md](../../SPLITTING.md)).

**Depends on:** all RUI2 packages + naylib, yaml

```nim
import rui
```

Re-exports every subsystem and provides the `App` object and main-loop
integrator. `import rui` to get everything:

```nim
let app = newApp("My App", 800, 600)
app.setRootWidget(buildUI())
app.run()
```
