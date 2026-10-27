## Avatar and AvatarStack -- a person (or a team, a bot) as a round picture.
##
## ```nim
## ui:
##   Avatar(name = "Ada Lovelace", imagePath = "ada.png", status = asOnline)
##   AvatarStack(names = @["Ada", "Grace Hopper", "Alan Turing", "Edsger", "Barbara"],
##               maxShown = 3)                   # three, then "+2"
## ```
##
## With no picture (or one that will not load) an avatar shows the initials on
## a colour of its own: the same name always gets the same colour, and the
## letters take black or white, whichever reads better on it. A stack overlaps
## its avatars, the first on top, each ringed in the background colour so they
## stay apart, and shows how many more there are.
##
## `drawAvatar` is the drawing itself, for a primitive of your own (a chat
## row, a comment).

import rui_core
import rui_drawing
import std/[options, unicode, hashes, strutils, math]
import raylib

type AvatarStatus* = enum
  asNone, asOnline, asAway, asBusy, asOffline

proc initialsOf*(name: string): string =
  ## The first letter of the first and the last word, as capitals ("Ada
  ## Lovelace": "AL", "grace": "G"); "?" for no name.
  let words = strutils.splitWhitespace(strutils.strip(name))
  if words.len == 0: return "?"
  result = $words[0].runeAt(0).toUpper
  if words.len > 1: result.add $words[^1].runeAt(0).toUpper

proc colorFor*(name: string): Color =
  ## A colour of the name's own: the same name, the same colour, on any run.
  ## Mid saturation and lightness, so either black or white reads on it.
  let h = float32(abs(hash(name.toLowerAscii)) mod 360)
  let s = 0.45'f32
  let l = 0.55'f32
  let c = (1 - abs(2 * l - 1)) * s
  let x = c * (1 - abs(floorMod(h / 60, 2) - 1))
  let m = l - c / 2
  let (r, g, b) = if h < 60: (c, x, 0'f32) elif h < 120: (x, c, 0'f32)
                  elif h < 180: (0'f32, c, x) elif h < 240: (0'f32, x, c)
                  elif h < 300: (x, 0'f32, c) else: (c, 0'f32, x)
  Color(r: uint8((r + m) * 255), g: uint8((g + m) * 255), b: uint8((b + m) * 255), a: 255)

proc statusColor(s: AvatarStatus): Color =
  case s
  of asOnline: currentTheme.getThemeProps(Success).activeColor.get(Color(r: 40, g: 170, b: 80, a: 255))
  of asAway: currentTheme.getThemeProps(Warning).activeColor.get(Color(r: 230, g: 160, b: 30, a: 255))
  of asBusy: currentTheme.getThemeProps(Danger).activeColor.get(Color(r: 210, g: 50, b: 50, a: 255))
  of asOffline, asNone: Color(r: 150, g: 150, b: 150, a: 255)

proc drawAvatar*(rect: Rect, name: string, imagePath = "", status = asNone,
                 ring = 0'f32, props: ThemeProps = currentTheme.getThemeProps(Default)) =
  ## One avatar in `rect` (a square: the shorter side is used), with a `ring`
  ## of the background colour round it (to stand apart from others).
  let d = min(rect.width, rect.height)
  let box = Rect(x: rect.x + (rect.width - d) / 2, y: rect.y + (rect.height - d) / 2,
                 width: d, height: d)
  let bg = props.backgroundColor.get(WHITE)
  if ring > 0:
    discard drawSdfBox(Rect(x: box.x - ring, y: box.y - ring, width: d + 2 * ring,
                            height: d + 2 * ring), d / 2 + ring, 0, bg, bg)
  let tex = textureFor(imagePath)
  var drawn = false
  if tex != nil:
    # The middle square of the picture: a circle shows no stretched faces.
    let w = tex[].width.float32
    let h = tex[].height.float32
    let side = min(w, h)
    let src = Rectangle(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
    drawn = drawSdfImage(tex[], src, box, d / 2)
  if not drawn:
    let fill = colorFor(name)
    discard drawSdfBox(box, d / 2, 0, fill, fill)
    var style = props.captionStyle(
      if contrastRatio(fill, BLACK) >= contrastRatio(fill, WHITE): BLACK else: WHITE)
    style.fontSize = max(8'f32, d * 0.36)
    style.bold = true
    let text = initialsOf(name)
    let size = measureText(text, style)
    drawStyledText(text, box.x + (d - size.width) / 2, box.y + (d - size.height) / 2, style)
  if status != asNone:
    let dot = max(6'f32, d * 0.28)
    let at = Rect(x: box.x + d - dot, y: box.y + d - dot, width: dot, height: dot)
    let c = statusColor(status)
    discard drawSdfBox(at, dot / 2, max(1.5'f32, dot * 0.18), c, bg)

definePrimitive(Avatar):
  props:
    name: string = ""
    imagePath: string = ""
    size: float32 = 36.0
    status: AvatarStatus = asNone
    intent: ThemeIntent = Default

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = widget.size
    if widget.bounds.height <= 0: widget.bounds.height = widget.size

  render:
    drawAvatar(widget.bounds, widget.name, widget.imagePath, widget.status,
               props = currentTheme.getThemeProps(widget.intent, Normal))

proc stackSlots*(count, maxShown: int, size, overlap: float32): seq[float32] =
  ## The x offset of each circle in a stack (the shown avatars, then "+N"
  ## when some are left out), each `overlap` (a share of `size`) over the last.
  let shown = min(count, maxShown)
  let more = count > shown
  for i in 0 ..< shown + (if more: 1 else: 0):
    result.add float32(i) * size * (1 - overlap)

definePrimitive(AvatarStack):
  props:
    names: seq[string] = @[]
    imagePaths: seq[string] = @[]   ## by position, beside `names`; may be shorter
    maxShown: int = 4
    size: float32 = 32.0
    overlap: float32 = 0.25         ## how much each is covered by the one before, a share of `size`
    intent: ThemeIntent = Default

  layout:
    let slots = stackSlots(widget.names.len, widget.maxShown, widget.size, widget.overlap)
    if widget.bounds.width <= 0:
      widget.bounds.width = (if slots.len > 0: slots[^1] + widget.size else: widget.size) + 4
    if widget.bounds.height <= 0: widget.bounds.height = widget.size + 4

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let slots = stackSlots(widget.names.len, widget.maxShown, widget.size, widget.overlap)
    let y = widget.bounds.y + 2
    let shown = min(widget.names.len, widget.maxShown)
    for i in countdown(slots.high, 0):    # the first on top, as people read them
      let r = Rect(x: widget.bounds.x + 2 + slots[i], y: y, width: widget.size, height: widget.size)
      if i < shown:
        let path = if i < widget.imagePaths.len: widget.imagePaths[i] else: ""
        drawAvatar(r, widget.names[i], path, ring = 2, props = props)
      else:
        # How many more: a neutral circle with "+N".
        let ink = props.foregroundColor.get(BLACK)
        let bg = props.backgroundColor.get(WHITE)
        discard drawSdfBox(Rect(x: r.x - 2, y: r.y - 2, width: r.width + 4, height: r.height + 4),
                           r.width / 2 + 2, 0, bg, bg)
        discard drawSdfBox(r, r.width / 2, 0, ink.withAlpha(0.15), ink.withAlpha(0.15))
        var style = props.captionStyle(ink)
        style.fontSize = max(8'f32, widget.size * 0.36)
        let text = "+" & $(widget.names.len - shown)
        let size = measureText(text, style)
        drawStyledText(text, r.x + (r.width - size.width) / 2,
                       r.y + (r.height - size.height) / 2, style)
