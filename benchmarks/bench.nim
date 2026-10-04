## RUI2 benchmark: how long each part of a frame takes at 1k and 10k widgets.
##
##   nim c -r -d:release -d:useGraphics benchmarks/bench.nim [--sizes=1000,10000]
##                                                           [--json] [--gate]
##
## It needs a display (run it under Xvfb on a server): the render rows paint
## into real GL textures. Layout, hit-testing and tree building are plain
## tree work and would run headless, but one binary keeps the numbers
## comparable.
##
## The tree is a Column of Rows of mixed controls (Label, Button, Checkbox),
## ten to a row, so N widgets means about N + N/10 nodes. Each row is the
## median of several runs, in milliseconds.
##
##   build           constructing the tree
##   layout (full)   every widget dirty, as at startup or on a window resize
##   layout (1 leaf) one label's text changes: what typing or a counter costs
##   hit-test build  the hit-test system rebuilt from the tree (per layout)
##   hit-test query  one pointer lookup
##   render (full)   every widget repainted into its texture
##   render (visible) the same, culled to what a 1200x800 window shows
##   render (1 leaf) one label repainted and its ancestors re-composited
##   idle frame      a frame in which nothing changed
##
## `--gate` exits non-zero when a row exceeds its budget (see `budgets`), so
## CI can fail a regression; `--json` prints one machine-readable line.

import rui
import rui_hittest
import raylib
import std/[os, strutils, algorithm, monotimes, json, strformat, sequtils, options]
import std/times except getTime   # raylib has a getTime too

type Row = tuple[name: string, ms: float]

proc ms(d: Duration): float = d.inNanoseconds.float / 1e6

template timeit(runs: int, body: untyped): float =
  ## Median wall time of `body`, in ms.
  var samples: seq[float]
  for _ in 1 .. runs:
    let t0 = getMonoTime()
    body
    samples.add (getMonoTime() - t0).ms
  samples.sort()
  samples[samples.len div 2]

proc build(n: int): tuple[root: Widget, leaves: seq[Label]] =
  let root = newVStack(spacing = 2.0)
  var leaves: seq[Label]
  var count = 0
  while count < n:
    let row = newHStack(spacing = 4.0)
    for c in 0 ..< 10:
      if count >= n: break
      case count mod 3
      of 0:
        let l = newLabel(text = "item " & $count)
        leaves.add l
        row.addChild l
      of 1: row.addChild newButton(text = "b" & $count)
      else: row.addChild newCheckbox(text = "c" & $count)
      inc count
    root.addChild row
  (Widget(root), leaves)

proc markAllDirty(w: Widget) =
  w.layoutDirty = true
  w.isDirty = true
  for c in w.children: markAllDirty(c)

proc countNodes(w: Widget): int =
  result = 1
  for c in w.children: result += countNodes(c)

proc textureBytes(w: Widget): int =
  if w.cachedTexture.isSome:
    # `.get` would copy the texture, which a RenderTexture refuses: borrow it.
    result = w.cachedTexture.get().texture.width.int *
             w.cachedTexture.get().texture.height.int * 4
  for c in w.children: result += textureBytes(c)

proc releaseTextures(w: Widget) =
  ## Free the GL textures while the window still exists: letting them die
  ## after closeWindow crashes.
  freeWidgetTexture(w)
  for c in w.children: releaseTextures(c)

proc oversize(w: Widget, limit: float32, found: var seq[string]) =
  ## Widgets bigger than a GPU texture can be: their cache cannot be built.
  if w.bounds.width > limit or w.bounds.height > limit:
    found.add &"{w.getTypeName()} {w.bounds.width:.0f}x{w.bounds.height:.0f}"
  for c in w.children: oversize(c, limit, found)

proc insertAll(system: var HitTestSystem, w: Widget) =
  if w.visible:
    system.insertWidget(w)
    for c in w.children: insertAll(system, c)

proc runSize(n: int): tuple[rows: seq[Row], nodes: int, texMB: float] =
  var rows: seq[Row]
  let runs = if n >= 10000: 3 else: 7

  var tree: tuple[root: Widget, leaves: seq[Label]]
  rows.add ("build", timeit(runs) do: tree = build(n))
  let root = tree.root
  root.bounds = Rect(x: 0, y: 0, width: 1200, height: 800)

  rows.add ("layout (full)", timeit(runs) do:
    markAllDirty(root)
    root.layoutPass())

  var round = 0
  rows.add ("layout (1 leaf)", timeit(runs * 3) do:
    inc round
    tree.leaves[tree.leaves.len div 2].text = "changed " & $round
    tree.leaves[tree.leaves.len div 2].layoutDirty = true
    tree.leaves[tree.leaves.len div 2].markDirtyToRoot()
    var p = tree.leaves[tree.leaves.len div 2].parent
    while p != nil:
      p.layoutDirty = true
      p = p.parent
    root.layoutPass())

  var system = newHitTestSystem()
  rows.add ("hit-test build", timeit(runs) do:
    system.clear()
    insertAll(system, root))
  rows.add ("hit-test query", timeit(runs * 20) do:
    discard system.findTopWidgetAt(600.0, 400.0))

  rows.add ("render (full)", timeit(runs) do:
    markAllDirty(root)
    root.renderPass())

  # The same repaint with only the window's worth on screen: what an app
  # that has the whole UI laid out but scrolled to the top actually pays.
  renderView = some(Rect(x: 0, y: 0, width: 1200, height: 800))
  rows.add ("render (visible)", timeit(runs) do:
    markAllDirty(root)
    root.renderPass())
  renderView = none(Rect)

  rows.add ("render (1 leaf)", timeit(runs * 3) do:
    inc round
    let leaf = tree.leaves[tree.leaves.len div 2]
    leaf.text = "again " & $round
    leaf.markDirtyToRoot()
    root.renderPass())

  rows.add ("idle frame", timeit(runs * 20) do: runFrame(root))

  var big: seq[string]
  oversize(root, 16384, big)
  if big.len > 0:
    echo &"  note: {big.len} widget(s) exceed the 16384px texture limit: {big[0 .. min(2, big.high)]}"
  let stats = (countNodes(root), textureBytes(root).float / (1024 * 1024))
  releaseTextures(root)
  (rows, stats[0], stats[1])

# What a healthy build stays under, per 1000 widgets, in ms (scaled linearly
# for bigger trees). About 3x what a mid-range machine measures: loose enough
# for a noisy CI runner, tight enough to catch an accidental O(n^2) or a
# cache that stopped working.
const budgets = {
  "layout (full)": 10.0, "layout (1 leaf)": 5.0, "hit-test build": 10.0,
  "hit-test query": 0.05, "render (1 leaf)": 3.0, "idle frame": 0.5}

when isMainModule:
  var sizes = @[1000, 10000]
  var asJson, gate = false
  for arg in commandLineParams():
    if arg.startsWith("--sizes="): sizes = arg[8 .. ^1].split(',').map(parseInt)
    elif arg == "--json": asJson = true
    elif arg == "--gate": gate = true

  setTraceLogLevel(TraceLogLevel.Error)   # raylib logs one line per texture
  initWindow(1200, 800, "RUI2 benchmark")
  setCurrentTheme(brandTheme(daylightSpec()))

  var report = newJObject()
  var failed: seq[string]
  for n in sizes:
    let (rows, nodes, texMB) = runSize(n)
    if not asJson:
      echo &"\n== {n} widgets ({nodes} nodes, {texMB:.1f} MB of textures) =="
      for (name, t) in rows:
        echo &"  {name:<18} {t:>9.3f} ms"
    var j = newJObject()
    for (name, t) in rows:
      j[name] = %t
      for (bname, budget) in budgets:
        if bname == name and t > budget * (n.float / 1000):
          failed.add &"{n}: {name} {t:.2f} ms > {budget * n.float / 1000:.1f} ms"
    j["nodes"] = %nodes
    j["textureMB"] = %texMB
    report[$n] = j
  if asJson: echo $report
  if failed.len > 0:
    echo "\nOver budget:"
    for f in failed: echo "  ", f
    if gate: quit(1)
  # Leave without tearing the window down: the GL textures of the last tree
  # are gone already, and raylib/Pango teardown at exit is not what we measure.
  quit(0)
