# packages/rui_widgets/src/containers/tabcontrol.nim

## Purpose

Tabbed container: a row of tab buttons on top, one child shown below. Child `i`
belongs to tab `i`.

## Public interface

- `newTabControl*(tabs: seq[string] = @[], initialActiveTab = 0,
  tabBarHeight = 28.0, intent = Default, onTabChanged)`.
- State: `activeTab` (seeded from `initialActiveTab`), `hoverTab`.

Tabs are **equal width** — `bounds.width / tabs.len` — which is what both the
hit-test and the painting divide by. Switching tabs from code needs
`layoutDirty = true`, because child visibility is decided in `layout`.

## Usage pattern

```nim
let tabs = newTabControl(tabs = @["First", "Second"], initialActiveTab = 0)
tabs.bounds = Rect(x: 0, y: 0, width: 560, height: 120)
for caption in ["page one", "page two"]:
  let page = newVStack(spacing = 4.0, padding = 8.0)
  page.addChild(newLabel(text = caption, fontSize = 14.0))
  tabs.addChild(page)
tabs.onTabChanged = some(proc(newTab: int) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it wrapped raygui's `GuiTabBar` and
declared `onTabChanged` as a bare `proc` prop while calling `.isSome` on it —
which could not compile. It is an `actions:` entry now, so the DSL wraps it in
an `Option`.

**Inactive children are hidden with `visible = false`, not skipped.**
`main_loop.renderPass` walks the child list itself, so a container cannot
decide not to draw a child — marking it invisible is the only lever it has.
Inactive tabs are still laid out, so switching to one is instant.
</content>
