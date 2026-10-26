## yui vocabulary: the names and small value formats that .yui files and the
## `ui:` DSL share, and the one table that says how they line up.
##
## yui (github.com/kobi2187/yui) describes a UI as YAML:
##
##     column:
##       padding: 16px
##       children:
##         - label "Hello, {name}"
##         - button 120x40 "Save": {on_click: save/0}
##
## and `ui:` writes the same tree as Nim. This module is pure data and pure
## string functions -- no widgets are built here -- so the loader, the
## generator and the exporter (docs/yui.md, issue #61) all read one source of
## truth, and a test keeps it honest against the widgets that really exist.
##
## Everything yui-shaped carries the `Yui` prefix (or `Css`, for the
## padding/margin shorthand) so that importing the whole toolkit through the
## `rui` barrel stays unambiguous.

import std/[options, strutils, sequtils]
import types, layout

type
  MapKind* = enum
    ## How a yui element relates to the rui2 widget of the same job.
    mapSame     ## same name (ignoring case), same meaning
    mapRename   ## same meaning, the other side calls it something else
    mapClash    ## the *name* exists on both sides but means different things
    mapGap      ## yui has it, rui2 has no widget for it yet (issue #53)

  ElementMap* = object
    yui*: string       ## element type as written in a .yui file
    rui*: string       ## the widget type; "" when there is none
    kind*: MapKind
    fallback*: string  ## a lesser widget that stands in for a gap; "" if none
    note*: string

func em(yui, rui: string, kind: MapKind, note = "",
        fallback = ""): ElementMap =
  ElementMap(yui: yui, rui: rui, kind: kind, fallback: fallback, note: note)

const elementMap*: seq[ElementMap] = @[
  # -- containers and layout -------------------------------------------------
  em("row", "Row", mapSame),
  em("column", "Column", mapSame),
  em("grid", "GridView", mapRename,
     "`grid 3x2` is columns x rows; frame sizes (`120x40`) are width x height"),
  em("pane", "SplitView", mapRename, "two children and a draggable divider"),
  em("tab", "TabControl", mapRename,
     "children are pages; a page is `tab \"Title\"` holding one child"),
  em("scroll", "ScrollView", mapRename),
  em("viewport", "ScrollView", mapRename, "alias of scroll"),
  em("group", "GroupBox", mapRename, "a border and a title around children"),
  em("frame", "GroupBox", mapRename, "alias of group"),
  em("box", "Container", mapRename, "plain container; decoration comes from props"),
  em("stack", "IndexedStack", mapClash,
     "yui shows ONE child at a time; rui2's Stack overlays them all"),
  em("card", "Card", mapSame),
  em("toolbar", "ToolBar", mapSame),
  em("statusbar", "StatusBar", mapSame),
  em("menubar", "MenuBar", mapSame),
  em("popup", "ContextMenu", mapRename),
  em("dialog", "Dialog", mapSame, "MessageBox is the ready-made alert/confirm"),
  em("drawer", "Drawer", mapSame, "in the flow, not over the content"),
  em("expander", "Expander", mapSame),
  em("accordion", "Accordion", mapSame, "one Expander open at a time"),
  em("hoverreveal", "HoverReveal", mapSame, "controls that show when the pointer comes near"),
  em("clip", "Clip", mapSame, "shows only part of its child"),
  em("paint", "Paint", mapSame, "a widget that is only a drawing (onPaint)"),
  em("spacer", "Spacer", mapSame),
  em("divider", "Separator", mapRename),
  # -- basic widgets ---------------------------------------------------------
  em("label", "Label", mapSame),
  em("button", "Button", mapSame),
  em("checkbox", "Checkbox", mapSame),
  em("radio", "RadioButton", mapRename, "a `group` of radios is a RadioGroup"),
  em("input", "TextInput", mapRename),
  em("password", "PasswordInput", mapRename),
  em("textarea", "TextArea", mapSame),
  em("select", "ComboBox", mapRename),
  em("combo", "ComboBox", mapRename, "the editable flavour of select"),
  em("slider", "Slider", mapSame),
  em("progress", "ProgressBar", mapRename),
  em("spinner", "NumberInput", mapClash,
     "yui's spinner is a number field with up/down buttons; rui2's Spinner is a busy indicator"),
  em("image", "ImageWidget", mapRename),
  em("switch", "Switch", mapSame),
  em("link", "Hyperlink", mapRename),
  em("icon", "Icon", mapSame, "a glyph; IconButton is the one with chrome"),
  em("canvas", "Canvas", mapSame),
  em("tooltip", "Tooltip", mapSame),
  # -- advanced input --------------------------------------------------------
  em("file", "FilePicker", mapRename, "the drawn picker; never a native dialog"),
  em("date", "DatePicker", mapRename, "value is ISO text, 2026-10-11"),
  em("time", "TimePicker", mapRename, "value is 24-hour text, 14:30"),
  em("color", "ColorPicker", mapRename, "value is hex text, #3366cc"),
  em("autocomplete", "Autocomplete", mapSame),
  em("search", "SearchInput", mapRename, "a TextInput with an x that clears it"),
  em("range", "RangeSlider", mapRename),
  # -- data display ----------------------------------------------------------
  em("table", "DataTable", mapClash,
     "rui2's Table/TableRow are a layout grid; the data widget is DataTable"),
  em("tree", "TreeView", mapRename),
  em("list", "ListView", mapRename, "`template:` rows are not supported yet"),
  em("badge", "Badge", mapSame),
]

const ruiOnly*: seq[string] = @[
  ## rui2 widgets yui has no element for. Exporting a tree that contains one
  ## needs an extension element (open question in docs/yui.md).
  "Plot", "Sparkline", "KanbanBoard", "Timeline", "MapWidget", "Rating",
  "SegmentedControl", "Toast", "DataGrid", "ListBox", "ComboList", "DragDropArea",
  "Dock", "Docked", "FocusRing", "HelpOverlay", "FileDialog",
  "MessageBox", "Menu", "MenuItem", "ToolButton", "IconButton", "Panel",
  "ScrollBar", "Circle", "Rectangle", "Spinner",
  # layout vocabulary that yui spells as properties (align, grow, padding...)
  "Flex", "Expanded", "Flexible", "Align", "Center", "Padding", "SizedBox",
  "ConstrainedBox", "Positioned", "Wrap", "Table", "TableRow", "Stack",
  "VStack", "HStack", "ZStack", "TooltipTip", "Container",
]

func sameName(a, b: string): bool = cmpIgnoreCase(a, b) == 0

func yuiElement*(name: string): Option[ElementMap] =
  ## The table row for a yui element type, or none for an unknown one.
  for entry in elementMap:
    if sameName(entry.yui, name): return some(entry)

func yuiNameFor*(widget: string): Option[string] =
  ## The canonical yui element for a rui2 widget type (the first row that
  ## names it), or none for a rui2-only widget.
  for entry in elementMap:
    if entry.rui.len > 0 and sameName(entry.rui, widget): return some(entry.yui)

func widgetFor*(yuiType: string): Option[string] =
  ## The rui2 widget to build for a yui element: the real one, else the gap's
  ## stand-in. None when the element is unknown, a clash with no meaning here,
  ## or a gap with no stand-in -- the caller reports that, it does not guess.
  let row = yuiElement(yuiType)
  if row.isNone: return none(string)
  if row.get.rui.len > 0: return some(row.get.rui)
  if row.get.fallback.len > 0: return some(row.get.fallback)

func isRuiOnly*(widget: string): bool =
  for name in ruiOnly:
    if sameName(name, widget): return true

# ---------------------------------------------------------------------------
# Numbers

func fmtNum(v: float32): string =
  ## 16 -> "16", 8.5 -> "8.5": no trailing zeros, no exponent.
  if v == float32(int(v)): return $int(v)
  result = formatFloat(float(v), ffDecimal, 3)
  result.trimZeros()

func parsePx(s: string): Option[float32] =
  ## "16", "16px", "8.5px" -> the number. Negative or malformed -> none.
  var text = s.strip()
  if text.endsWith("px"): text.setLen(text.len - 2)
  if text.len == 0: return none(float32)
  try:
    let v = parseFloat(text)
    if v >= 0 and v == v: return some(float32(v))
  except ValueError: discard
  none(float32)

# ---------------------------------------------------------------------------
# Element keys: `type [WxH] ["content"]`

type YuiKey* = object
  kind*: string      ## the element type: "button"
  hasSize*: bool     ## a WxH token was present
  width*, height*: float32
  content*: string   ## the text after the type and size, quotes removed

func isSizeToken(s: string): bool =
  ## "120x40" or "12.5x4". Not "text", "box" or "x": yui's own parser takes any
  ## token containing an `x` for a size; this one needs digits on both sides.
  let parts = s.split('x')
  if parts.len != 2: return false
  parsePx(parts[0]).isSome and parsePx(parts[1]).isSome and
    parts[0].len > 0 and parts[1].len > 0 and
    parts[0][0] in Digits and parts[1][0] in Digits

func unquote(s: string): string =
  if s.len >= 2 and s[0] == '"' and s[^1] == '"':
    s[1 ..< s.len - 1].replace("\\\"", "\"")
  else: s

func parseYuiKey*(key: string): YuiKey =
  ## `button 120x40 "Save"` -> (button, 120x40, Save).
  var rest = key.strip()
  var cut = 0
  while cut < rest.len and rest[cut] notin Whitespace: inc cut
  result.kind = rest[0 ..< cut]
  rest = rest[cut .. ^1].strip()
  cut = 0
  while cut < rest.len and rest[cut] notin Whitespace: inc cut
  if cut > 0 and isSizeToken(rest[0 ..< cut]):
    let parts = rest[0 ..< cut].split('x')
    result.hasSize = true
    result.width = parsePx(parts[0]).get
    result.height = parsePx(parts[1]).get
    rest = rest[cut .. ^1].strip()
  result.content = unquote(rest)

func formatYuiKey*(k: YuiKey): string =
  ## The inverse of parseYuiKey. Content is always quoted, as in yui's own
  ## examples, so a label that looks like a size survives the round trip.
  result = k.kind
  if k.hasSize: result.add " " & fmtNum(k.width) & "x" & fmtNum(k.height)
  if k.content.len > 0:
    result.add " \"" & k.content.replace("\"", "\\\"") & "\""

# ---------------------------------------------------------------------------
# width / height

type
  YuiDimKind* = enum dimAuto, dimFixed, dimFill
  YuiDim* = object
    kind*: YuiDimKind
    px*: float32       ## only for dimFixed

func parseYuiDim*(s: string): Option[YuiDim] =
  ## `240px`, `240` and `fill`. `auto` and empty mean "size to content".
  let text = s.strip().toLowerAscii
  if text == "fill": return some(YuiDim(kind: dimFill))
  if text in ["", "auto"]: return some(YuiDim(kind: dimAuto))
  let v = parsePx(text)
  if v.isSome: some(YuiDim(kind: dimFixed, px: v.get)) else: none(YuiDim)

# ---------------------------------------------------------------------------
# padding / margin: CSS shorthand

func parseCssInsets*(s: string): Option[EdgeInsets] =
  ## "16px" (all), "8px 16px" (vertical horizontal), "1px 2px 3px" (top
  ## horizontal bottom), "1px 2px 3px 4px" (top right bottom left).
  let parts = s.splitWhitespace()
  var v: seq[float32]
  for p in parts:
    let n = parsePx(p)
    if n.isNone: return none(EdgeInsets)
    v.add n.get
  case v.len
  of 1: some(EdgeInsets(top: v[0], right: v[0], bottom: v[0], left: v[0]))
  of 2: some(EdgeInsets(top: v[0], right: v[1], bottom: v[0], left: v[1]))
  of 3: some(EdgeInsets(top: v[0], right: v[1], bottom: v[2], left: v[1]))
  of 4: some(EdgeInsets(top: v[0], right: v[1], bottom: v[2], left: v[3]))
  else: none(EdgeInsets)

func formatCssInsets*(e: EdgeInsets): string =
  ## The shortest shorthand that parses back to `e`.
  func px(v: float32): string = fmtNum(v) & "px"
  if e.top == e.bottom and e.left == e.right:
    if e.top == e.left: return px(e.top)
    return px(e.top) & " " & px(e.right)
  px(e.top) & " " & px(e.right) & " " & px(e.bottom) & " " & px(e.left)

# ---------------------------------------------------------------------------
# align / justify

func squash(s: string): string =
  s.toLowerAscii.replace("-", "").replace("_", "")

func parseJustify*(s: string): Option[MainAxisAlignment] =
  ## `justify:` is the main axis. `spaceBetween`, `space-between` and
  ## `space_between` all read.
  let want = squash(s.strip())
  for a in MainAxisAlignment:
    if squash($a) == want: return some(a)

func parseAlign*(s: string): Option[CrossAxisAlignment] =
  ## `align:` is the cross axis.
  let want = squash(s.strip())
  for a in CrossAxisAlignment:
    if squash($a) == want: return some(a)

# ---------------------------------------------------------------------------
# grow

func parseYuiGrow*(s: string): Option[float32] =
  ## `grow: true` is one share, `grow: 2` is two, `grow: false` is none.
  case s.strip().toLowerAscii
  of "true", "yes", "on": some(1'f32)
  of "false", "no", "off", "": some(0'f32)
  else: parsePx(s)

func formatYuiGrow*(weight: float32): string = fmtNum(weight)

# ---------------------------------------------------------------------------
# bind

type
  YuiBindDirection* = enum
    bindTwoWay    ## `<->`  state and widget follow each other
    bindToWidget  ## `->`   state flows into the widget
    bindToState   ## `<-`   the widget's value flows into state

  YuiBinding* = object
    direction*: YuiBindDirection
    path*: string   ## the state path: `username`, `settings.apiKey`, `tasks[{index}].done`

func parseYuiBind*(s: string): Option[YuiBinding] =
  ## The text after the word `bind`: `<-> username`, `-> name`, `<- "tasks[{i}].done"`.
  var rest = s.strip()
  var dir: YuiBindDirection
  if rest.startsWith("<->"): dir = bindTwoWay; rest = rest[3 .. ^1]
  elif rest.startsWith("->"): dir = bindToWidget; rest = rest[2 .. ^1]
  elif rest.startsWith("<-"): dir = bindToState; rest = rest[2 .. ^1]
  else: return none(YuiBinding)
  let path = unquote(rest.strip())
  if path.len == 0: return none(YuiBinding)
  some(YuiBinding(direction: dir, path: path))

func formatYuiBind*(b: YuiBinding): string =
  let arrow = case b.direction
    of bindTwoWay: "<->"
    of bindToWidget: "->"
    of bindToState: "<-"
  let needsQuotes = b.path.anyIt(it notin IdentChars + {'.'})
  arrow & " " & (if needsQuotes: "\"" & b.path & "\"" else: b.path)

# ---------------------------------------------------------------------------
# on_* handlers: `save/0` is the action `save` taking 0 arguments

type YuiAction* = object
  name*: string
  arity*: int

func parseYuiAction*(s: string): Option[YuiAction] =
  let text = s.strip()
  let slash = text.rfind('/')
  if slash <= 0 or slash == text.high: return none(YuiAction)
  let name = text[0 ..< slash]
  if name[0] notin IdentStartChars or name.anyIt(it notin IdentChars):
    return none(YuiAction)
  let digits = text[slash + 1 .. ^1]
  if digits.anyIt(it notin Digits): return none(YuiAction)
  some(YuiAction(name: name, arity: parseInt(digits)))

func formatYuiAction*(a: YuiAction): string = a.name & "/" & $a.arity

func ruiEventName*(prop: string): string =
  ## `on_value_change` -> `onValueChange`. Not an event -> "".
  if not prop.startsWith("on_") or prop.len == 3: return ""
  result = "on"
  for word in prop[3 .. ^1].split('_'):
    if word.len > 0: result.add word[0].toUpperAscii & word[1 .. ^1]

func yuiEventName*(handler: string): string =
  ## `onValueChange` -> `on_value_change`. Not a handler name -> "".
  if handler.len < 3 or not handler.startsWith("on") or
     handler[2] notin {'A' .. 'Z'}: return ""
  result = "on"
  for ch in handler[2 .. ^1]:
    if ch in {'A' .. 'Z'}: result.add '_'
    result.add ch.toLowerAscii
