# yui and rui2

[yui](https://github.com/kobi2187/yui) describes a UI as YAML (`.yui` files);
rui2's `ui:` describes the same tree as Nim. They are two spellings of one
idea, by the same author, and this page is the contract between them: what
lines up, what does not, and what the loader and exporter (issue #61) promise.

```yaml
column:
  padding: 16px
  children:
    - label "Hello, {name}!"
    - input: {bind <-> name}
    - button 120x40 "Save": {on_click: save/0}
```
```nim
ui:
  Column().margin("16px"):
    Label(text = -> "Hello, {name}!")
    TextInput(text = <-> name)
    Button(text = "Save", onClick = save).size(120, 40)
```

The data lives in `packages/rui_core/src/yui_names.nim` (the element table and
the value parsers) and `store.nim` (yui's `state`); `tests/test_yui_names.nim`
fails to compile if the table names a widget that does not exist.

## Elements

Kinds: **same** (same job, same name), **rename**, **clash** (the name exists
on both sides with different meanings), **gap** (no rui2 widget yet; the table
has none left, but the loader still reports one if a row regresses).

| yui | rui2 | kind | note |
|---|---|---|---|
| row, column | Row, Column | same | |
| grid | GridView | rename | `grid 3x2` is columns x rows |
| pane | SplitView | rename | |
| tab | TabControl | rename | a page is `tab "Title"` with one child |
| scroll, viewport | ScrollView | rename | |
| group, frame | GroupBox | rename | |
| box | Container | rename | |
| stack | IndexedStack | clash | yui shows one child; our `Stack` overlays all |
| card, badge, expander, drawer | Card, Badge, Expander, Drawer | same | Drawer is in the flow, not over the content |
| toolbar, statusbar, menubar | ToolBar, StatusBar, MenuBar | same | |
| popup | ContextMenu | rename | |
| divider | Separator | rename | |
| spacer | Spacer | same | |
| label, button, checkbox, slider, switch, textarea, canvas, tooltip | same names | same | |
| radio | RadioButton | rename | a group of radios is a RadioGroup |
| input, password, search | TextInput, PasswordInput, SearchInput | rename | |
| select, combo | ComboBox | rename | |
| progress | ProgressBar | rename | |
| spinner | NumberInput | clash | our `Spinner` is a busy indicator |
| image | ImageWidget | rename | `Image` is raylib's type |
| link | Hyperlink | rename | `Link[T]` is our reactive type |
| file | FilePicker | rename | drawn, never native |
| table | DataTable | clash | our `Table` is a layout grid |
| tree, list | TreeView, ListView | rename | list `template:` not supported yet |
| icon, dialog, autocomplete | Icon, Dialog, Autocomplete | same | |
| date, time, color | DatePicker, TimePicker, ColorPicker | rename | values are text: `2026-10-11`, `14:30`, `#3366cc` |
| range | RangeSlider | rename | |

rui2 widgets with no yui element (Plot, KanbanBoard, Timeline, MapWidget,
Sparkline, Rating, SegmentedControl, Toast, DataGrid, ...) can only be
exported through an extension element -- see the open questions.

## Properties

| yui | rui2 |
|---|---|
| `id` | widget id / selector |
| `width`, `height`, `size: 120x40` | `.frame(width=, height=)`, `.size(w, h)`; `fill` is `.flex` |
| `grow: true|n` | `.flex(n)` (`parseYuiGrow`) |
| `shrink` | none: children already shrink to fit |
| `align`, `justify` | `crossAxisAlignment`, `mainAxisAlignment` -- same enum names |
| `padding`, `margin` | `.padding(...)`, `.margin(...)` (CSS shorthand `8px 16px` parses) |
| `spacing` | `spacing` on Row/Column |
| `visible`, `enabled` | the Widget fields of the same name |
| `bind <-> x`, `-> x`, `<- x` | `text = <-> x`, `= -> x`, `= <- x` in `ui:`; Links from a `Store` |
| `"{name}"` interpolation | `text = -> "…{name}…"`, `store.interpolated(...)` |
| `on_click: save/0` | `onClick`; actions are registered by name (`ruiEventName`, `parseYuiAction`) |
| `theme`, `font`, `color`, `backgroundColor` | **not mapped**: themes are the author's, global (#46). The loader warns and ignores. |

## State: `Store`

yui's `state:` block is a `Store`: named, typed `Link`s. `store.declare("n", 0)`
returns the Link, `store.get[int]("n")` / `store.set("n", 3)` read and write by
name, `getText` / `setText` give a text view of scalars (what a loader needs to
bind a name from a file), and `format` / `interpolated` fill `{name}`. Names are
flat strings; `settings.apiKey` is a name containing a dot.

## Themes

`extends:` already works for theme files and in code (`themeManager.derive`);
a child changes only what it names, per property, and the parent is untouched
(tests in `tests/test_theme.nim`, "theme: inheritance"). yui's tokens
(`$padding.input`) are free-form names; ours are fixed fields, so token
references need the work in #46.

## Where yui's own README and parser disagree

- the README writes `bind <-> x` as a bare line in a property list; the parser
  only reads a `bind:` key;
- the parser takes any token containing `x` for a size, so `label next` is
  misread; `parseYuiKey` requires digits on both sides (`120x40`).

## Still to build (issue #61)

`loadYui(path): Widget` (element table + properties + `Store` + an action
registry), a `rui2` target for `yui generate`, `toYui(widget)`, and a
round-trip conformance test. Every yui element now has a rui2 widget.

## Questions for yui's author

1. Extension elements for rui2-only widgets: `x-plot`? a namespace?
2. Should `shrink` and `wrap` keep their CSS meaning, or go?
3. Per-element `color`/`font`: keep, or move into themes?
4. Fix the README/parser disagreement on `bind`, and the `x` size heuristic?
