## A self-contained text engine on stb_truetype, for where Pango is not: on
## Android (the default there), or on the desktop with `-d:ruiTextStb` to see
## what a phone will draw. text_engine.nim picks it; pango_text.nim holds the
## caches and drawing it shares with the Pango engine.
##
## What it does: TrueType/OpenType (glyf) fonts found by family name in a few
## folders, Bold and Italic by file, kerning, subpixel positioning, greyscale
## antialiasing, word wrap, glyph fallback to further fonts, caret geometry and
## hit testing. What it does not (yet), next to Pango: complex-script shaping
## (Arabic joining, Indic reordering, ligatures -- no HarfBuzz), bidirectional
## reordering (right-to-left text draws left to right), grapheme clusters
## beyond combining marks, colour emoji, and markup beyond dropping the tags.
## mobile/README.md tracks closing those.
##
## Sizes mean what they mean to Pango -- points at 96 dpi -- so a layout is
## the same size under either engine.

import std/[unicode, options, strutils, tables, math, os]
import raylib
import text_types

{.compile: "stb_text_glue.c".}

proc stbOpen(data: ptr uint8, len: cint): pointer {.importc: "rui_stb_open".}
proc stbScaleEm(f: pointer, px: cfloat): cfloat {.importc: "rui_stb_scale_em".}
proc stbVMetrics(f: pointer, ascent, descent, gap: ptr cint) {.importc: "rui_stb_vmetrics".}
proc stbGlyph(f: pointer, codepoint: cint): cint {.importc: "rui_stb_glyph".}
proc stbAdvance(f: pointer, glyph: cint): cint {.importc: "rui_stb_advance".}
proc stbKern(f: pointer, g1, g2: cint): cint {.importc: "rui_stb_kern".}
proc stbBox(f: pointer, glyph: cint, scale, shiftX: cfloat,
            x0, y0, x1, y1: ptr cint) {.importc: "rui_stb_box".}
proc stbRender(f: pointer, output: ptr uint8, w, h, stride: cint,
               scale, shiftX: cfloat, glyph: cint) {.importc: "rui_stb_render".}

# raylib's file loading, which on Android reads the APK's assets first.
proc rlLoadFileData(fileName: cstring, dataSize: ptr cint): ptr UncheckedArray[uint8]
  {.importc: "LoadFileData", header: "raylib.h".}
proc rlUnloadFileData(data: ptr UncheckedArray[uint8]) {.importc: "UnloadFileData", header: "raylib.h".}

const
  engineName* = "stb"
  PointsToPixels = 96.0 / 72.0   ## Pango's sizes are points at 96 dpi

var
  fontDirs*: seq[string] =
    when defined(android): @["fonts", "/system/fonts"]   # APK assets, then the system's
    else: @["/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF",
            "/usr/share/fonts/truetype/roboto/hinted",
            "/usr/share/fonts/truetype/dejavu"]
    ## Where fonts are looked for, first match wins. `RUI_FONT_DIR` (a
    ## path list) is searched before these.
  defaultFamily* = "Roboto"
    ## What a generic family (sans-serif, Sans, system-ui) means.
  fallbackFiles*: seq[string] =
    when defined(android): @["/system/fonts/NotoSansSymbols-Regular-Subsetted.ttf",
                             "/system/fonts/NotoSansSymbols-Regular-Subsetted2.ttf",
                             "/system/fonts/DroidSans.ttf"]
    else: @["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    ## Fonts asked for a glyph the chosen one lacks, in order.

type
  Face = ref object
    data: seq[uint8]           # stb reads the font in place: kept alive here
    info: pointer
    ascent, descent, gap: int32   # font units

  Font = object
    faces: seq[Face]           # the chosen face, then the fallbacks
    px: float32                # em size in pixels
    style: tuple[bold, italic: bool]

  Line = object
    first, last: int           # byte range [first, last) of the text
    xs: seq[float32]           # x of each codepoint start in the line, then its end
    starts: seq[int]           # byte offset of each codepoint, then `last`
    width: float32

  Laid = object
    lines: seq[Line]
    lineHeight, ascent: float32

var
  faceCache: Table[string, Face]       # by file; nil = tried, not there
  fontCache: Table[string, Font]       # by description string

proc engineSetOptions*(opts: FontRenderOptions) = discard
  ## stb has one antialiasing mode (greyscale, unhinted); nothing to set.

proc loadFace(path: string): Face =
  if path in faceCache: return faceCache[path]
  var face: Face = nil
  when not defined(android):
    if not fileExists(path):
      faceCache[path] = nil
      return nil
  var size: cint
  let raw = rlLoadFileData(path.cstring, addr size)
  if raw != nil and size > 0:
    var data = newSeq[uint8](size)
    copyMem(addr data[0], raw, size)
    rlUnloadFileData(raw)
    let info = stbOpen(addr data[0], size)
    if info != nil:
      face = Face(data: move data, info: info)
      var a, d, g: cint
      stbVMetrics(info, addr a, addr d, addr g)
      face.ascent = a; face.descent = d; face.gap = g
  faceCache[path] = face
  face

proc searchDirs(): seq[string] =
  for d in strutils.split(getEnv("RUI_FONT_DIR"), PathSep):
    if d.len > 0: result.add d
  result.add fontDirs

proc findFace(family: string, bold, italic: bool): Face =
  let style = (if bold and italic: "BoldItalic" elif bold: "Bold"
               elif italic: "Italic" else: "Regular")
  let base = family.replace(" ", "")
  var names = @[base & "-" & style & ".ttf", base & "-" & style & ".otf"]
  if style == "Regular": names.add [base & ".ttf", base & ".otf"]
  else: names.add base & "-" & style.replace("Italic", "Oblique") & ".ttf"   # DejaVu's name
  for dir in searchDirs():
    for n in names:
      let f = loadFace(dir / n)
      if f != nil: return f

proc parseFont(desc: string): Font =
  ## "Roboto, sans-serif Bold Italic 14.0" -> families, style, size.
  if desc in fontCache: return fontCache[desc]
  var words = strutils.splitWhitespace(desc)
  var size = 10.0'f32
  if words.len > 0:
    try:
      size = parseFloat(words[^1]).float32
      words.setLen(words.len - 1)
    except ValueError: discard
  var bold, italic = false
  while words.len > 0 and words[^1].toLowerAscii in
      ["bold", "italic", "oblique", "medium", "semi-bold", "light", "regular"]:
    case words[^1].toLowerAscii
    of "bold", "semi-bold": bold = true
    of "italic", "oblique": italic = true
    else: discard
    words.setLen(words.len - 1)
  var font = Font(px: size * PointsToPixels, style: (bold, italic))
  for fam in strutils.split(words.join(" "), ','):
    var name = fam.strip()
    if name.toLowerAscii in ["", "sans", "sans-serif", "system-ui", "serif", "monospace"]:
      name = defaultFamily
    var f = findFace(name, bold, italic)
    if f == nil and (bold or italic): f = findFace(name, false, false)
    if f != nil:
      font.faces.add f
      break
  if font.faces.len == 0:
    let f = findFace(defaultFamily, bold, italic)
    if f != nil: font.faces.add f
  for path in fallbackFiles:
    let f = loadFace(path)
    if f != nil and f notin font.faces: font.faces.add f
  fontCache[desc] = font
  font

proc primary(font: Font): Face = (if font.faces.len > 0: font.faces[0] else: nil)

proc glyphFor(font: Font, cp: int): tuple[face: Face, glyph: cint] =
  ## The first face with a glyph for `cp`; the primary's missing-glyph box if none.
  for f in font.faces:
    let g = stbGlyph(f.info, cp.cint)
    if g != 0: return (f, g)
  (font.primary, 0.cint)

proc scaleOf(font: Font, face: Face): float32 = stbScaleEm(face.info, font.px).float32

proc stripMarkup(s: string): string =
  ## Pango markup as plain text: tags dropped, the five entities decoded.
  var i = 0
  while i < s.len:
    if s[i] == '<':
      let j = s.find('>', i)
      if j < 0: break
      i = j + 1
    else:
      result.add s[i]; inc i
  result = result.multiReplace(("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
                               ("&apos;", "'"), ("&amp;", "&"))

proc advances(font: Font, text: string, first, last: int,
              starts: var seq[int], xs: var seq[float32]) =
  ## Pen position before each codepoint of text[first ..< last], and after.
  var x = 0.0'f32
  var prev: tuple[face: Face, glyph: cint] = (nil, 0.cint)
  var i = first
  while i < last:
    var r: Rune
    let at = i
    fastRuneAt(text, i, r)
    let g = glyphFor(font, int(r))
    if g.face == nil:
      starts.add at; xs.add x
      continue
    let s = scaleOf(font, g.face)
    # Whole-pixel advances and kerning, as Cairo's hinted metrics give Pango:
    # otherwise a long line drifts a few pixels from the desktop's.
    if prev.face == g.face and prev.glyph != 0 and g.glyph != 0:
      x += round(stbKern(g.face.info, prev.glyph, g.glyph).float32 * s)
    starts.add at; xs.add x
    x += round(stbAdvance(g.face.info, g.glyph).float32 * s)
    prev = g
  starts.add last; xs.add x

proc layoutText(text, fontDesc: string, wrapWidth: int32): Laid =
  let font = parseFont(fontDesc)
  let face = font.primary
  if face != nil:
    let s = scaleOf(font, face)
    # Whole pixels, ascent and descent each rounded up, as Pango's hinted
    # metrics do: the same line height under either engine.
    result.ascent = ceil(face.ascent.float32 * s)
    result.lineHeight = result.ascent + ceil(-face.descent.float32 * s) +
                        round(face.gap.float32 * s)
  else:
    result.ascent = font.px * 0.8; result.lineHeight = font.px * 1.2
  var p = 0
  while true:                                   # one paragraph per '\n'
    # Unwrapped text is one paragraph, as in Pango's single-paragraph mode:
    # callers that show several lines split them themselves.
    var e = (if wrapWidth > 0: text.find('\n', p) else: -1)
    if e < 0: e = text.len
    var first = p
    while true:                                 # one line per wrap
      var line = Line(first: first)
      advances(font, text, first, e, line.starts, line.xs)
      var cut = e
      if wrapWidth > 0 and line.xs[^1] > wrapWidth.float32 and line.starts.len > 2:
        var k = 1                               # codepoints that fit
        while k < line.xs.len - 1 and line.xs[k + 1] <= wrapWidth.float32: inc k
        var brk = -1                            # last space within what fits
        for j in countdown(k, 1):
          if text[line.starts[j]] == ' ' or text[line.starts[j - 1]] == '-':
            brk = j; break
        var keep = (if brk > 0: brk else: k)
        cut = line.starts[keep]
        while cut < e and text[cut] == ' ': inc cut    # spaces hang off the line
        line.starts.setLen(keep + 1); line.xs.setLen(keep + 1)
        line.starts[keep] = line.starts[keep]
      line.last = line.starts[^1]
      # trailing spaces do not count toward the width
      var w = line.xs[^1]
      var j = line.starts.len - 2
      while j >= 0 and line.starts[j] < text.len and text[line.starts[j]] == ' ':
        w = line.xs[j]; dec j
      line.width = w
      result.lines.add line
      if cut >= e: break
      first = cut
    if e >= text.len: break
    p = e + 1

proc engineMeasure*(text: string, font: string, wrapWidth: int32 = -1,
                    markup = false, dir = tdAuto): TextMeasure =
  let content = if text.len == 0: " " elif markup: stripMarkup(text) else: text
  let laid = layoutText(content, font, wrapWidth)
  var w = 0.0'f32
  for l in laid.lines: w = max(w, l.width)
  TextMeasure(width: (if text.len == 0: 0.0'f32 else: ceil(w)),
              height: ceil(laid.lineHeight * laid.lines.len.float32),
              baseline: laid.ascent, lineCount: laid.lines.len)

proc isMark(cp: int): bool =
  cp in 0x0300 .. 0x036F or cp in 0x1AB0 .. 0x1AFF or cp in 0x20D0 .. 0x20FF or
    cp in 0xFE00 .. 0xFE0F or cp in 0xFE20 .. 0xFE2F or cp == 0x200D or
    cp in 0x1F3FB .. 0x1F3FF

proc isWordChar(r: Rune): bool = r.isAlpha or int(r) in ord('0') .. ord('9')

proc engineCharAttrs*(text: string): CharAttrs =
  ## Codepoint-level boundaries: a caret stops before every codepoint that is
  ## not a combining mark, a variation selector, a skin tone or after a joiner;
  ## words are runs of letters and digits.
  var runes: seq[Rune]
  var i = 0
  while i < text.len:
    result.byteAt.add i
    var r: Rune
    fastRuneAt(text, i, r)
    runes.add r
  result.byteAt.add text.len
  let n = result.byteAt.len
  result.cursorStop = newSeq[bool](n)
  result.backspaceChar = newSeq[bool](n)
  result.wordStart = newSeq[bool](n)
  result.wordEnd = newSeq[bool](n)
  for k in 0 ..< n:
    let here = (if k < runes.len: some(runes[k]) else: none(Rune))
    let before = (if k > 0: some(runes[k - 1]) else: none(Rune))
    result.cursorStop[k] = not (here.isSome and isMark(int(here.get))) and
                           not (before.isSome and int(before.get) == 0x200D)
    result.backspaceChar[k] = true
    let wHere = here.isSome and isWordChar(here.get)
    let wBefore = before.isSome and isWordChar(before.get)
    result.wordStart[k] = wHere and not wBefore
    result.wordEnd[k] = wBefore and not wHere

proc moveCaretVisually*(text: string, index: int, direction: int): Option[int] =
  ## Left to right only: one codepoint back (-1) or on (+1).
  if text.len == 0: return
  var i = index
  if direction < 0:
    if i <= 0: return none(int)
    dec i
    while i > 0 and (ord(text[i]) and 0xC0) == 0x80: dec i
  else:
    if i >= text.len: return none(int)
    inc i
    while i < text.len and (ord(text[i]) and 0xC0) == 0x80: inc i
  some(i)

proc softBreaks*(text, font: string, wrapWidth: int32): seq[int] =
  result = @[0]
  if text.len == 0 or wrapWidth <= 0: return
  let laid = layoutText(text, font, wrapWidth)
  for i in 1 ..< laid.lines.len: result.add laid.lines[i].first

proc lineOf(laid: Laid, byteIndex: int): int =
  result = 0
  for i, l in laid.lines:
    if byteIndex >= l.first: result = i

proc cursorPosition*(text, font: string, byteIndex: int,
                     wrapWidth: int32 = -1, dir = tdAuto): CursorPos =
  let laid = layoutText(text, font, wrapWidth)
  let li = lineOf(laid, byteIndex)
  let line = laid.lines[li]
  var x = line.xs[^1]
  for k, s in line.starts:
    if s >= byteIndex: x = line.xs[k]; break
  CursorPos(x: x, y: li.float32 * laid.lineHeight, height: laid.lineHeight)

proc indexFromPosition*(text, font: string, x, y: float32,
                        wrapWidth: int32 = -1, dir = tdAuto): HitResult =
  let laid = layoutText(text, font, wrapWidth)
  let row = int(floor(y / max(1.0'f32, laid.lineHeight)))
  let li = clamp(row, 0, laid.lines.len - 1)
  let line = laid.lines[li]
  result.inside = row == li and x >= 0 and x <= line.width
  if line.starts.len < 2 or x <= 0:
    result.index = line.first
    return
  for k in 0 ..< line.starts.len - 1:
    if x < line.xs[k + 1]:
      result.index = line.starts[k]
      result.trailing = (if x >= (line.xs[k] + line.xs[k + 1]) / 2: 1 else: 0)
      return
  result.index = line.starts[^2]          # past the end: after the last codepoint
  result.trailing = 1

proc coverage(text, fontDesc: string, wrapWidth: int32, m: TextMeasure): seq[uint8] =
  ## An A8 picture of the laid-out text, `m.width` x `m.height`.
  let w = max(1, m.width.int)
  let h = max(1, m.height.int)
  result = newSeq[uint8](w * h)
  let font = parseFont(fontDesc)
  let laid = layoutText(text, fontDesc, wrapWidth)
  var tmp: seq[uint8]
  for li, line in laid.lines:
    let baseline = li.float32 * laid.lineHeight + laid.ascent
    for k in 0 ..< line.starts.len - 1:
      var at = line.starts[k]
      var r: Rune
      fastRuneAt(text, at, r)
      let g = glyphFor(font, int(r))
      if g.face == nil or g.glyph == 0 and int(r) <= 0x20: continue
      let s = scaleOf(font, g.face)
      let penX = line.xs[k]
      let shift = penX - floor(penX)
      var x0, y0, x1, y1: cint
      stbBox(g.face.info, g.glyph, s, shift, addr x0, addr y0, addr x1, addr y1)
      let gw = int(x1 - x0)
      let gh = int(y1 - y0)
      if gw <= 0 or gh <= 0: continue
      tmp.setLen(gw * gh)
      stbRender(g.face.info, addr tmp[0], gw.cint, gh.cint, gw.cint, s, shift, g.glyph)
      let ox = int(floor(penX)) + int(x0)
      let oy = int(round(baseline)) + int(y0)
      for yy in 0 ..< gh:
        let ty = oy + yy
        if ty < 0 or ty >= h: continue
        for xx in 0 ..< gw:
          let tx = ox + xx
          if tx < 0 or tx >= w: continue
          let c = tmp[yy * gw + xx]
          if c != 0:
            let d = addr result[ty * w + tx]
            d[] = uint8(min(255, d[].int + c.int))

proc engineRasteriseA8*(text, font: string, wrapWidth: int32,
                        m: TextMeasure, dir = tdAuto): seq[Color] =
  ## Coverage mask -> white RGBA. Colour comes from the draw tint.
  let a = coverage(text, font, wrapWidth, m)
  result = newSeq[Color](a.len)
  for i, c in a: result[i] = Color(r: 255, g: 255, b: 255, a: c)

proc engineRasteriseArgb32*(markupText, font: string, wrapWidth: int32,
                            m: TextMeasure): seq[Color] =
  ## Markup without its colours: the text in black (drawn with a White tint).
  let a = coverage(stripMarkup(markupText), font, wrapWidth, m)
  result = newSeq[Color](a.len)
  for i, c in a: result[i] = Color(r: 0, g: 0, b: 0, a: c)

proc paragraphDir*(text: string): TextDir =
  ## Always left to right: this engine does not reorder right-to-left text.
  tdLtr
