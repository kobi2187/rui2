# packages/rui_widgets/src/basic/separator.nim

## Purpose

A rule for dividing UI sections, horizontal or vertical.

## Public interface

- `newSeparator*(vertical = false, thickness = 1.0, intent = Default)`.

**It only claims its cross axis.** A horizontal separator sizes its height to
`thickness` and leaves the width to the stack that owns it; a vertical one does
the reverse. That is what lets it sit in a VStack without either collapsing to
nothing or demanding a width nobody wants to specify.

Colour comes from the theme's `borderColor`.

## Usage pattern

```nim
root.addChild(newSeparator())                                  # horizontal rule
row.addChild(newSeparator(vertical = true, thickness = 2.0))   # vertical divider
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it called raylib's `DrawLineEx`
directly with a hard-coded grey and had no `layout` section — so it reported
zero size and a stack collapsed it to nothing.
</content>
