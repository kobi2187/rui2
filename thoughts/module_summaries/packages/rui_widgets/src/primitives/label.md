# packages/rui_widgets/src/primitives/label.nim

## Purpose

Static text, rendered through Pango — so full Unicode, BiDi (Hebrew, Arabic) and
complex-script shaping come for free, along with real font metrics. The most
widely used widget in the library, and the one that proves the text stack works.

## Public interface

- `newLabel*(text: string, fontSize = 14.0, color = BLACK, fontFamily = "",
  bold = false, italic = false, underline = false, align = TextAlign.Left,
  wrap = false, markup = false)`.
- `fontFamily = ""` resolves to the system Sans alias.
- `markup = true` treats `text` as **Pango markup** —
  `"<b>bold</b> <span foreground='#c00'>red</span>"`. Colours then come from the
  markup, so the `color` prop is ignored.
- `wrap = true` wraps to the width the parent assigned.
- State: `selfWidth`, `selfHeight` — the size this label last measured for itself.

## Usage pattern

```nim
root.addChild(newLabel(text = "Heading", fontSize = 18.0, bold = true))
root.addChild(newLabel(text = "<b>Bold</b> and <i>italic</i>", markup = true))
```

## Circumstances

**A Label sizes itself.** Its `layout` measures the text with `measureText`
(real Pango metrics) and sets its own height, plus its width when the parent has
not imposed one. That is what lets VStack and HStack arrange labels without
every caller assigning `bounds` by hand — the stacks pass width 0 down and read
the measured size back.

Before the Pango merge this measured with `raylib.measureText`, which sizes the
built-in 10-pixel bitmap font and reports the *requested* size as the height
with the baseline guessed at 0.8 of it. Both were wrong for any real font, which
is why labels were mis-centred and containers could not size to content.

One of the repo's git hot spots — 4 of the last 12 commits before the widget
restore touched this file.
