## Background patterns made in code: small tiles a theme repeats behind
## everything (theme_background.nim), so a theme can have a texture without
## shipping a picture.
##
## A theme names one where it would name a picture file:
##
## ```yaml
## background:
##   image: "pattern:halftone/#11111118"     # name / ink (#RRGGBB or #RRGGBBAA)
## ```
##
## or `brandTheme(BrandSpec(pattern: "halftone", patternInk: ...))`. The ink's
## alpha is how strong it is: keep it faint, text sits on it. Patterns:
##
## - `halftone`   dots on a diagonal grid (comic print)
## - `bubbles`    rings of a few sizes, scattered (fizz)
## - `scanlines`  a thin line every few pixels (a CRT)
## - `grain`      long wavy lines (wood)
## - `fibre`      scattered specks (paper, parchment)
## - `graph`      graph paper: a fine grid with a stronger line every fifth
## - `grid`       an even grid
##
## Each tile is drawn so its edges meet the next one's, so the repeat shows no
## seam. The image is made on the CPU (no window needed, so tests read its
## pixels); textures.nim uploads it once, as it does a file.

import std/[strutils, math]
import raylib

const PatternPrefix* = "pattern:"

const patternNames* = ["halftone", "bubbles", "scanlines", "grain", "fibre", "graph", "grid"]

proc hexOf(c: Color): string =
  "#" & toHex(c.r.int, 2) & toHex(c.g.int, 2) & toHex(c.b.int, 2) & toHex(c.a.int, 2)

proc patternKey*(name: string, ink: Color): string =
  ## What a theme stores to name pattern `name` in `ink`.
  PatternPrefix & name & "/" & hexOf(ink)

proc isPattern*(path: string): bool = path.startsWith(PatternPrefix)

proc parsePattern*(key: string): tuple[name: string, ink: Color, ok: bool] =
  ## `pattern:name/#RRGGBB[AA]` back into its parts; ok is false when it is
  ## not one, names no known pattern, or the ink is not a colour.
  if not key.isPattern: return
  let rest = key[PatternPrefix.len .. ^1]
  let slash = rest.find('/')
  let name = if slash < 0: rest else: rest[0 ..< slash]
  if name notin patternNames: return
  var ink = Color(r: 0, g: 0, b: 0, a: 32)
  if slash >= 0:
    let h = rest[slash + 1 .. ^1].strip(chars = {'#'})
    if h.len notin [6, 8]: return
    try:
      let v = parseHexInt(h)
      ink = if h.len == 8:
              Color(r: uint8((v shr 24) and 255), g: uint8((v shr 16) and 255),
                    b: uint8((v shr 8) and 255), a: uint8(v and 255))
            else:
              Color(r: uint8((v shr 16) and 255), g: uint8((v shr 8) and 255),
                    b: uint8(v and 255), a: 255)
    except ValueError: return
  (name, ink, true)

proc dot(img: var Image, cx, cy, r: int32, ink: Color) =
  ## A filled disc that wraps round the tile's edges.
  for y in -r .. r:
    for x in -r .. r:
      if x * x + y * y <= r * r:
        imageDrawPixel(img, floorMod(cx + x, img.width), floorMod(cy + y, img.height), ink)

proc ring(img: var Image, cx, cy, r: int32, ink: Color) =
  ## A one-pixel circle that wraps round the tile's edges.
  let steps = max(16, int(r) * 8)
  for i in 0 ..< steps:
    let a = float(i) / float(steps) * 2 * PI
    let x = cx + int32(round(cos(a) * float(r)))
    let y = cy + int32(round(sin(a) * float(r)))
    imageDrawPixel(img, floorMod(x, img.width), floorMod(y, img.height), ink)

proc patternImage*(name: string, ink: Color): Image =
  ## One tile of pattern `name` in `ink` over transparent; an empty 1x1 tile
  ## for a name it does not know.
  let clear = Color(r: ink.r, g: ink.g, b: ink.b, a: 0)
  case name
  of "halftone":
    result = genImageColor(12, 12, clear)
    dot(result, 3, 3, 2, ink)
    dot(result, 9, 9, 2, ink)
  of "bubbles":
    result = genImageColor(96, 96, clear)
    for (x, y, r) in [(12'i32, 18'i32, 6'i32), (40, 70, 10), (70, 30, 4), (84, 80, 7),
                      (28, 46, 3), (60, 54, 2), (90, 8, 3), (8, 88, 4)]:
      ring(result, x, y, r, ink)
  of "scanlines":
    result = genImageColor(4, 4, clear)
    imageDrawRectangle(result, 0, 0, 4, 1, ink)
  of "grain":
    # Wavy lines whose waves are whole periods across the tile: no seam.
    result = genImageColor(160, 48, clear)
    for line in 0 ..< 6:
      let base = float(line) * 8 + 3
      let phase = float(line) * 1.3
      let amp = 1.5 + float(line mod 3) * 0.8
      for x in 0 ..< 160:
        let t = float(x) / 160 * 2 * PI
        let y = base + sin(t * 2 + phase) * amp + sin(t * 5 + phase * 2) * 0.6
        imageDrawPixel(result, int32(x), floorMod(int32(round(y)), 48'i32), ink)
  of "fibre":
    # Scattered specks from a fixed sequence (the same tile every run).
    result = genImageColor(64, 64, clear)
    var s = 2463534242'u32
    for i in 0 ..< 90:
      s = s xor (s shl 13); s = s xor (s shr 17); s = s xor (s shl 5)
      let x = int32(s mod 64)
      let y = int32((s shr 8) mod 64)
      let long = (s shr 16) mod 4 == 0              # a few short fibres
      imageDrawPixel(result, x, y, ink)
      if long: imageDrawPixel(result, floorMod(x + 1, 64'i32), y, ink)
  of "graph":
    result = genImageColor(50, 50, clear)
    let faint = Color(r: ink.r, g: ink.g, b: ink.b, a: uint8(ink.a.int div 2))
    for i in countup(10'i32, 40, 10):
      imageDrawRectangle(result, i, 0, 1, 50, faint)
      imageDrawRectangle(result, 0, i, 50, 1, faint)
    imageDrawRectangle(result, 0, 0, 1, 50, ink)
    imageDrawRectangle(result, 0, 0, 50, 1, ink)
  of "grid":
    result = genImageColor(32, 32, clear)
    imageDrawRectangle(result, 0, 0, 1, 32, ink)
    imageDrawRectangle(result, 0, 0, 32, 1, ink)
  else:
    result = genImageColor(1, 1, clear)
