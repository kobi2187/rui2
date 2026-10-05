# Tests

```bash
./tools/run_tests.sh            # unit tests (one binary) + GL checks: under a minute
./tools/run_tests.sh isolated   # the same, each test file its own program (to blame one file)
./tools/run_tests.sh examples   # every example through the Nim backend (~1 min)
./tools/run_tests.sh ui         # the scripted UI run on Xvfb
./tools/run_tests.sh full       # all of the above
```

CI (`.github/workflows/ci.yml`) runs `quick`, `examples` and `ui` as three
parallel jobs on every pull request and on main, with Nimble packages and each
job's nimcache cached; a red job reproduces locally with the same command.

The default run is meant to be quick enough to run after every change, so it
does two things:

1. **Unit tests** (`tests/test_*.nim`, std/unittest), compiled into *one*
   program (a generated `tests/all_unit.nim`) so the toolkit builds once, not
   once per file. No GL context required -- layout, binding, theming,
   hit-testing and text metrics are all CPU-side. Tests share one process, so
   they restore any global they change (`currentTheme`, `prefs`,
   `animationsEnabled`); `isolated` is the way to rule out a leak.
2. **GL checks** (`tests/gl/*.nim`), each on its own Xvfb display: culling and
   the distance-field shader, read back from the GPU.

`full` adds what is slow:

3. **Example compiles.** `nim c --compileOnly`, not `nim check`: naylib's GPU
   types are move-only (`=copy` is `{.error.}`), an error raised by destructor
   injection, which `nim check` skips. Stopping before the C compiler keeps
   that check at ~5 s per example instead of ~37 s.
4. **Scripted UI tests** (`tools/ui_test.sh`) -- drives a real window on Xvfb
   through the file-based scripting protocol and asserts on the JSON replies.

| File | Covers |
|---|---|
| `test_layout.nim` | container arrangement, content-driven sizing, dirty gating, widget identity |
| `test_link.nim` | `Link[T]` value semantics, dependency tracking, `bindTo` |
| `test_theme.nim` | registry, intent × state resolution, switching reaching the screen |
| `test_events.nim` | hit-test ordering, event bubbling, per-widget input handling |
| `test_widgets.nim` | every shipped widget: construction, `initialX` seeding, sizing, scripting |
| `test_text.nim` | Pango metrics, wrapping, cursor/hit-test, markup, caches |
| `test_text_buffer.nim` | caret, selection and editing model; UTF-8 character boundaries |
| `test_textarea.nim` | line/column arithmetic, goal column across short lines, Unicode typing |
| `test_selectors.nim` | scripting selectors: ids, paths, `*` / `**`, type names |
| `test_keyboard_nav.nim`, `test_focus_groups.nim` | tab stops, chain rebuilds, key scoping, focus groups |
| `test_frame.nim` | a whole frame without a window (`stepHeadless` + `ListEventSource`) |
| `test_ui_tree.nim` | the `ui:` block syntax |
| `test_clip.nim`, `test_scroll_geometry.nim`, `test_virtual_rows.nim` | clipping, ScrollView geometry, row virtualisation |
| `test_restored_widgets.nim`, `test_map.nim`, `test_image_fit.nim` | the 35 restored widgets and their extracted models |
| `test_inspect.nim` | the `-d:ruiInspect` structure/geometry verbs |

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
