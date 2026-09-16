# packages/rui_widgets/src/containers/vstack_v2.nim

## Purpose

Arrange children vertically with a gap. The default container — reach for
[Column](column.md) only when you need main-axis distribution or cross-axis
alignment, which VStack does not implement.

## Public interface

- `newVStack*(spacing = 8.0, padding = 0.0)`.
- `hstack_v2` and `zstack_v2` are the siblings: horizontal, and layered.

## The contract every widget in the library depends on

VStack passes each child **width 0** when it has no width of its own, then reads
`child.bounds` back after calling `child.layout()`. That is the whole
content-driven sizing mechanism:

- A child that sets its own size when `bounds.width <= 0` gets measured.
- A child with **no `layout` section** reports zero and collapses to nothing.

This is why every restored widget gained a `layout` section during the port, and
why `Separator` claims only its cross axis — so a stack can decide the rest.

After arranging, VStack sizes *itself* to its content when the parent did not
impose a size, so the same rule propagates up the tree.

## Usage pattern

```nim
let root = newVStack(spacing = 12.0, padding = 20.0)
root.addChild(newLabel(text = "Heading", fontSize = 16.0))
root.addChild(newButton(text = "Submit"))
# No bounds set on any child — each measures itself.
```

## Circumstances

Named `_v2` because it replaced a pre-DSL `vstack.nim` during the v2 port; the
old one was deleted as `vstack.nim.old` in `a4bcc18` and deliberately not
restored.

Does **not** call `child.render()`. `main_loop.renderPass` already recurses over
`children` and composites their cached textures, so a container that rendered
its own children would draw them twice — which is exactly what several of the
restored containers did before the port.

`Spacer.flexGrow` is inert because this stack does not distribute leftover
space; a Spacer contributes its minimums and nothing more.
