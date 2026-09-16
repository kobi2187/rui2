# packages/rui_widgets/src/data/treeview.nim

## Purpose

Hierarchical tree with expand/collapse, selection and virtual scrolling, so a
tree of thousands of nodes only ever draws the rows on screen.

## Public interface

- `TreeNode*` — `id`, `text`, `icon`, `expanded`, `children`, `data: JsonNode`,
  `level` (filled in by the flatten pass, not by you).
- `FlatNode*` — `node`, `level`. One visible row.
- `flatten*(node: TreeNode, level: int, dest: var seq[FlatNode])` —
  depth-first over the **expanded** part of the tree. Tolerates a nil node.
- `twistyX*(flat, originX, indent): float32`,
  `hitsTwisty*(flat, mouseX, originX, indent): bool` — the expand triangle's
  position and hit target, computed once so the click and the drawing agree.
  A leaf has no twisty, so it never claims the click.
- `newTreeView*(rootNode = nil, nodeHeight = 24.0, indent = 20.0, showIcons,
  visibleRows = 10, intent, onSelect, onExpand, onCollapse)`.
- State: `selectedId`, `hoveredId` (**not** `hovered` — `Widget` already has
  that, as a `bool`), `flatNodes`, `scrollY`.

## Usage pattern

```nim
let tree = TreeNode(id: "root", text: "project", expanded: true, children: @[
  TreeNode(id: "src", text: "src", expanded: true, children: @[
    TreeNode(id: "main", text: "main.nim")])])

let view = newTreeView(rootNode = tree, nodeHeight = 22.0, visibleRows = 6)
view.onSelect = some(proc(nodeId: string) {.closure.} = ...)
```

Toggling `node.expanded` from outside requires `view.layoutDirty = true`: the
flat list is rebuilt in `layout`, and its length is what the scrollbar and the
hit-test are computed from.

## Circumstances

Restored 2026-09-15 from `a4bcc18`. The original flattened the tree *and*
polled the mouse inside `render`, so selection only updated on frames that
happened to repaint. Flattening moved to `layout` — which is also the only way
the event handlers can hit-test against the same list the paint used.

Refactored 2026-09-16 onto `RowViewport`.
</content>
