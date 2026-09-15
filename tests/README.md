# Tests

```bash
./tools/run_tests.sh          # everything
./tools/run_tests.sh unit     # unit tests only (no display needed)
```

`run_tests.sh` does three things:

1. **Unit tests** (`tests/test_*.nim`, std/unittest). No GL context required —
   layout, binding, theming, hit-testing and text metrics are all CPU-side.
2. **Example compiles.** A real `nim c`, not `nim check`: naylib's GPU types are
   move-only (`=copy` is `{.error.}`) and those failures only appear in a full
   build, so a check-only run passes code that cannot link.
3. **Scripted UI tests** (`tools/ui_test.sh`) — drives a real window on Xvfb
   through the file-based scripting protocol and asserts on the JSON replies.

| File | Covers |
|---|---|
| `test_layout.nim` | container arrangement, content-driven sizing, dirty gating, widget identity |
| `test_link.nim` | `Link[T]` value semantics, dependency tracking, `bindTo` |
| `test_theme.nim` | registry, intent × state resolution, switching reaching the screen |
| `test_events.nim` | hit-test ordering, event bubbling, per-widget input handling |
| `test_widgets.nim` | every shipped widget: construction, `initialX` seeding, sizing, scripting |
| `test_text.nim` | Pango metrics, wrapping, cursor/hit-test, markup, caches |

## Why these tests exist

Each suite pins down something that was silently broken, compiled cleanly, and
produced a blank or frozen window:

- `defineWidget` emitted a method named `updateLayout`, but the render loop
  dispatches on `layout` — no container ever positioned its children.
- Generated constructors never initialised the inherited `Widget` fields, so
  every widget was born `visible = false`.
- `Link[T]`'s backing field was called `value`, the same name as its `value=`
  setter. Nim resolves `link.value = x` to the field, so every assignment
  skipped the notification: no dependent was marked dirty and `onChange` never
  fired. The whole reactive system was inert.
- Hit-testing broke z-index ties arbitrarily; since everything in a container
  has z-index 0, clicks always resolved to the root and no button saw them.
- `setTheme` updated the global theme but marked nothing dirty, so a switch
  never repainted.

Add a test alongside any fix in these areas.
