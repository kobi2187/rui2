# packages/rui_core/src/types.nim

*Only the parts this session touched are described in detail; the rest of the
module is summarised for orientation.*

## Purpose

The framework's fundamental types: geometry, the `Widget` base object and its
overridable methods, events, and the reactive `Link[T]` cell. Everything else
in rui2 is built on this file.

## Public interface (orientation)

- Geometry: `Rect`, `Point`, `Size`, `EdgeInsets` (+ `edgeInsets*` helpers),
  `Constraints`.
- **`contains*(rect: Rect, x, y: float32): bool`** — is a point inside a rect.
  **Inclusive on all four edges.**
- `Widget*` — identity (`id`, `stringId`), geometry (`bounds`,
  `previousBounds`), state (`visible`, `enabled`, `hovered`, `pressed`,
  `focused`), dirty flags (`isDirty`, `layoutDirty`), `cachedTexture`,
  `zIndex`, `hasOverlay`, `onFocus` / `onBlur` / `onRefresh`, `parent`,
  `children`.
- `WidgetTree*`, `WidgetId*`, `newWidgetId*()`.
- Events: `EventKind*`, `GuiEvent*` (`kind`, `mousePos`, `key`, `char`,
  `windowSize`, `wheelDelta`), `EventPriority`, `EventPattern`.
- Base methods: `render`, `measure`, `layout`, `handleInput`,
  `handleScriptAction`, `getScriptableState`, `getTypeName`.
- `Link*[T]` — the reactive cell. Read and write through `value` / `value=`,
  **never** the backing field `val`.
- Re-exports raylib wholesale (see Circumstances).

## Usage pattern

```nim
if widget.bounds.contains(event.mousePos.x, event.mousePos.y):
  ...
```

## Circumstances

**`contains` moved here 2026-09-16.** It lived in
`packages/rui_hittest/src/hittest_system.nim` and was re-declared by four of
the restored widgets; importing two of them through the `rui` barrel made every
call ambiguous. One definition now, next to `Rect`.

Its **inclusive** edge semantics were kept deliberately. Half-open would be
tidier for adjacent rects, but hit-testing has always been inclusive and
changing it would silently stop clicks landing on a widget's right or bottom
edge.

> **Known issue — line 10.** `export raylib.Color, raylib.KeyboardKey,
> raylib.RenderTexture2D, raylib` names three symbols and then exports the whole
> module anyway, so every raylib enum field (`Menu`, `Info`, `Error`, `Warning`,
> `Default`) is in scope in every widget. This already costs six `menu.Menu`
> qualifications in `menus/menubar.nim` and two typed-proc workarounds in
> `dialogs/messagebox.nim`. Candidate #6 in the architecture review.
</content>
