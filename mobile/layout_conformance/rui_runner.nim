## Layout conformance, the RUI side: builds every case of cases.json (written
## in Flutter's vocabulary) out of RUI widgets, lays it out headless in a
## viewport of the case's size, and prints each node's rect as JSON.
##
##   rui_runner cases.json > rui.json
##
## The interpreter is strict on purpose. Every prop a case gives must be
## *consumed* -- mapped onto something RUI has -- or the case is reported as
## inexpressible, naming the widget and prop ("Align.widthFactor"). Nothing is
## silently dropped, so the report's "inexpressible" list is exactly what a
## Flutter developer cannot say in RUI today. Where a mapping is only close
## (a different widget standing in), it is recorded as an approximation.
##
## Where RUI's default differs from Flutter's, Flutter's is passed explicitly:
## the case means what it means in Flutter.

import std/[json, sets, strutils, math, options, tables]
import rui

type
  Inexpressible = object of CatchableError

  Ctx = object
    approx: seq[string]                 ## mappings that are only close
    ids: seq[(string, Widget)]          ## node id -> the widget that stands for it

proc nope(what: string) {.noreturn.} =
  raise newException(Inexpressible, what)

# --- reading props, strictly ---------------------------------------------------

type Props = object
  w: string
  p: JsonNode
  used: HashSet[string]

proc props(node: JsonNode): Props =
  Props(w: node["w"].getStr, p: (if node.hasKey("p"): node["p"] else: newJObject()))

proc has(ps: Props, k: string): bool = ps.p.hasKey(k)

proc get(ps: var Props, k: string): JsonNode =
  ps.used.incl k
  ps.p[k]

proc num(ps: var Props, k: string, d: float32): float32 =
  if not ps.has(k): return d
  let v = ps.get(k)
  if v.kind == JString and v.getStr == "inf": Inf.float32 else: v.getFloat.float32

proc str(ps: var Props, k, d: string): string =
  if ps.has(k): ps.get(k).getStr else: d

proc unsupported(ps: var Props, keys: varargs[string]) =
  ## These props have no RUI counterpart: give one and the case is inexpressible.
  for k in keys:
    if ps.has(k): nope(ps.w & "." & k & "=" & $ps.p[k])

proc done(ps: Props) =
  ## Everything given was used.
  for k, _ in ps.p:
    if k notin ps.used: nope(ps.w & "." & k & " (no mapping)")

proc insets(v: JsonNode): EdgeInsets =
  EdgeInsets(left: v[0].getFloat.float32, top: v[1].getFloat.float32,
             right: v[2].getFloat.float32, bottom: v[3].getFloat.float32)

proc alignment(ps: var Props, k: string, d: Alignment): Alignment =
  if not ps.has(k): return d
  let v = ps.get(k)
  Alignment(x: v[0].getFloat.float32, y: v[1].getFloat.float32)

proc enumOf[T: enum](ps: var Props, k: string, d: T): T =
  if not ps.has(k): return d
  let name = ps.get(k).getStr
  for e in T:
    if ($e).strip(chars = {'`'}) == name: return e
  nope(ps.w & "." & k & "=" & name)

# --- building --------------------------------------------------------------------

proc build(node: JsonNode, ctx: var Ctx): Widget

proc kids(node: JsonNode, ctx: var Ctx): seq[Widget] =
  if node.hasKey("c"):
    for c in node["c"]: result.add build(c, ctx)

proc adopt(w: Widget, children: seq[Widget]): Widget =
  for c in children: w.addChild c
  w

proc flexOf(ps: var Props, axis: Axis): Flex =
  ps.unsupported("verticalDirection", "textDirection")
  result = newFlex(direction = axis,
    mainAxisAlignment = ps.enumOf("mainAxisAlignment", MainAxisAlignment.start),
    crossAxisAlignment = ps.enumOf("crossAxisAlignment", CrossAxisAlignment.center),
    mainAxisSize = ps.enumOf("mainAxisSize", MainAxisSize.max),
    spacing = ps.num("spacing", 0))

proc columnWidth(v: JsonNode): TableColumnWidth =
  case v[0].getStr
  of "fixed": FixedColumnWidth(v[1].getFloat.float32)
  of "intrinsic": IntrinsicColumnWidth()
  of "flex": FlexColumnWidth(v[1].getFloat.float32)
  else: nope("Table.columnWidths " & v[0].getStr & "ColumnWidth")

proc build(node: JsonNode, ctx: var Ctx): Widget =
  var ps = props(node)
  let fill = Color(r: 0, g: 170, b: 0, a: 128)
  case ps.w
  of "Box":
    # Flutter's SizedBox: 0 is a size, null is "not given". RUI's SizedBox
    # takes 0 to mean "not given", so a 0 cannot be said.
    let w = ps.num("width", 0)
    let h = ps.num("height", 0)
    if (ps.has("width") and w == 0) or (ps.has("height") and h == 0):
      nope("SizedBox.width/height=0 (RUI reads 0 as unset)")
    result = newSizedBox(width = w, height = h).adopt(@[Widget(newRectangle(color = fill))])
  of "Fill":
    result = newContainer(color = fill)
  of "Text":
    # Flutter sizes text in logical pixels, RUI (Pango) in points at 96 dpi.
    ctx.approx.add "Text: fontSize px->pt (x0.75)"
    result = newLabel(text = ps.get("text").getStr, fontFamily = "Roboto",
                      fontSize = ps.num("size", 14) * 0.75,
                      wrap = (if ps.has("wrap"): ps.get("wrap").getBool else: true))
  of "Row": result = flexOf(ps, Axis.horizontal).adopt(kids(node, ctx))
  of "Column": result = flexOf(ps, Axis.vertical).adopt(kids(node, ctx))
  of "Flex":
    let axis = ps.enumOf("direction", Axis.horizontal)
    result = flexOf(ps, axis).adopt(kids(node, ctx))
  of "Expanded":
    result = newExpanded(flex = ps.num("flex", 1).int).adopt(kids(node, ctx))
  of "Flexible":
    result = newFlexible(flex = ps.num("flex", 1).int,
                         fit = ps.enumOf("fit", FlexFit.loose)).adopt(kids(node, ctx))
  of "Spacer":
    result = newSpacer(flex = ps.num("flex", 1).int)
  of "Padding":
    result = newPadding(padding = insets(ps.get("padding"))).adopt(kids(node, ctx))
  of "SizedBox":
    let w = ps.num("width", 0)
    let h = ps.num("height", 0)
    if (ps.has("width") and w == 0) or (ps.has("height") and h == 0):
      nope("SizedBox.width/height=0 (RUI reads 0 as unset)")
    result = newSizedBox(width = w, height = h).adopt(kids(node, ctx))
  of "ConstrainedBox":
    let c = Constraints(minWidth: ps.num("minWidth", 0), maxWidth: ps.num("maxWidth", Inf),
                        minHeight: ps.num("minHeight", 0), maxHeight: ps.num("maxHeight", Inf))
    result = newConstrainedBox(constraints = c).adopt(kids(node, ctx))
  of "Container":
    ps.unsupported("minWidth", "minHeight")       # Container.constraints
    result = newContainer(width = ps.num("width", 0), height = ps.num("height", 0),
      padding = (if ps.has("padding"): insets(ps.get("padding")) else: EdgeInsets()),
      margin = (if ps.has("margin"): insets(ps.get("margin")) else: EdgeInsets()),
      color = (if ps.has("color"): (discard ps.get("color"); fill) else: Color()),
      alignment = (if ps.has("alignment"): some(ps.alignment("alignment", AlignmentCenter))
                   else: none(Alignment))).adopt(kids(node, ctx))
  of "Align":
    ps.unsupported("widthFactor", "heightFactor")
    result = newAlign(alignment = ps.alignment("alignment", AlignmentCenter)).adopt(kids(node, ctx))
  of "Center":
    ps.unsupported("widthFactor", "heightFactor")
    result = newCenter().adopt(kids(node, ctx))
  of "Stack":
    ps.unsupported("textDirection")
    let fit = ps.str("fit", "loose")
    if fit == "passthrough": nope("Stack.fit=passthrough")
    result = newStack(alignment = ps.alignment("alignment", AlignmentTopLeft),
                      fit = (if fit == "expand": StackFit.expand else: StackFit.loose)
                     ).adopt(kids(node, ctx))
  of "Positioned":
    ps.unsupported("start", "end")                # PositionedDirectional
    result = newPositioned(left = ps.num("left", NaN), top = ps.num("top", NaN),
      right = ps.num("right", NaN), bottom = ps.num("bottom", NaN),
      width = ps.num("width", NaN), height = ps.num("height", NaN)).adopt(kids(node, ctx))
  of "IndexedStack":
    result = newIndexedStack(index = ps.num("index", 0).int).adopt(kids(node, ctx))
  of "Wrap":
    ps.unsupported("direction", "runAlignment", "textDirection")
    result = newWrap(spacing = ps.num("spacing", 0), runSpacing = ps.num("runSpacing", 0),
      alignment = ps.enumOf("alignment", MainAxisAlignment.start),
      crossAxisAlignment = ps.enumOf("crossAxisAlignment", WrapCrossAlignment.start)
     ).adopt(kids(node, ctx))
  of "Table":
    var widths: seq[TableColumnWidth]
    var default = FlexColumnWidth(1)
    if ps.has("defaultColumnWidth"): default = columnWidth(ps.get("defaultColumnWidth"))
    if ps.has("columnWidths"):
      let cw = ps.get("columnWidths")
      var most = -1
      for k, _ in cw: most = max(most, parseInt(k))
      for i in 0 .. most:
        widths.add(if cw.hasKey($i): columnWidth(cw[$i]) else: default)
    # Flutter's default is top; RUI's is middle.
    let v = ps.str("defaultVerticalAlignment", "top")
    if v == "fill": nope("Table.defaultVerticalAlignment=fill")
    let t = newTable(columnWidths = widths, defaultColumnWidth = default,
      defaultVerticalAlignment = (case v
        of "middle": TableCellVerticalAlignment.middle
        of "bottom": TableCellVerticalAlignment.bottom
        else: TableCellVerticalAlignment.top))
    for r in node["c"]:
      let row = newTableRow()
      ctx.ids.add (r["id"].getStr, Widget(row))
      for cell in r["c"]: row.addChild build(cell, ctx)
      t.addChild row
    result = t
  of "TableRow":
    nope("TableRow outside a Table")
  of "GridView":
    ps.unsupported("maxCrossAxisExtent")          # GridView.extent
    ctx.approx.add "GridView: RUI's does not scroll"
    result = newGridView(crossAxisCount = ps.num("crossAxisCount", 2).int,
      mainAxisSpacing = ps.num("mainAxisSpacing", 0), crossAxisSpacing = ps.num("crossAxisSpacing", 0),
      childAspectRatio = ps.num("childAspectRatio", 1)).adopt(kids(node, ctx))
  of "SingleChildScrollView":
    if ps.str("scrollDirection", "vertical") != "vertical":
      nope("SingleChildScrollView.scrollDirection=horizontal")
    var pad = 0.0'f32                             # RUI's default is 8
    if ps.has("padding"):
      let e = insets(ps.get("padding"))
      if not (e.left == e.top and e.top == e.right and e.right == e.bottom):
        nope("ScrollView.padding (uneven EdgeInsets)")
      pad = e.left
    result = newScrollView(padding = pad, wrapToWidth = true).adopt(kids(node, ctx))
    ctx.approx.add "SingleChildScrollView: ScrollView(wrapToWidth)"
  of "ListView":
    ps.unsupported("itemExtent")
    if ps.str("scrollDirection", "vertical") != "vertical":
      nope("ListView.scrollDirection=horizontal")
    # RUI's ListView shows strings; a list of widgets is a ScrollView over a
    # stretched Column.
    ctx.approx.add "ListView: ScrollView + Column(stretch)"
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch,
                        mainAxisSize = MainAxisSize.min).adopt(kids(node, ctx))
    result = newScrollView(padding = 0, wrapToWidth = true).adopt(@[Widget(col)])
  of "AspectRatio", "FractionallySizedBox", "IntrinsicHeight", "IntrinsicWidth",
     "LimitedBox", "UnconstrainedBox", "OverflowBox", "Offstage", "Visibility":
    nope(ps.w & " (no such widget)")
  else:
    nope(ps.w & " (unknown to the runner)")
  ps.done()
  ctx.ids.add (node["id"].getStr, result)

proc rectOf(w: Widget): JsonNode =
  %*[w.bounds.x, w.bounds.y, w.bounds.width, w.bounds.height]

proc runCase(c: JsonNode): JsonNode =
  var ctx: Ctx
  result = %*{"rects": {}, "errors": [], "inexpressible": nil, "approx": []}
  let w = c["size"][0].getInt
  let h = c["size"][1].getInt
  try:
    let root = build(c["tree"], ctx)
    resetUi()
    let app = newApp("conformance", w, h, resizable = false)
    app.setRootWidget(root)
    app.stepHeadless()
    for (id, widget) in ctx.ids:
      result["rects"][id] = rectOf(widget)
  except Inexpressible as e:
    result["inexpressible"] = %e.msg
  except CatchableError as e:
    result["errors"].add %($e.name & ": " & e.msg.splitLines()[0])
  for a in ctx.approx: result["approx"].add %a

when isMainModule:
  import std/os
  let cases = parseFile(paramStr(1))["cases"]
  var only = if paramCount() >= 2: paramStr(2) else: ""
  var results = newJObject()
  for c in cases:
    if only.len > 0 and c["name"].getStr != only: continue
    results[c["name"].getStr] = runCase(c)
  echo results.pretty
