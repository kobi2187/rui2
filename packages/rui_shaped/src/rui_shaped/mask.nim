## A window's shape as rectangles, from an alpha channel.
##
## Operating systems shape a window by a region: a list of rectangles (X11's
## SHAPE extension, Windows' SetWindowRgn). This turns an alpha mask -- a PNG's,
## or a shader's sampled on the CPU -- into one: each row's runs of opaque
## pixels, with consecutive rows that have the same runs merged into one band,
## which keeps a smooth shape to a few hundred rectangles instead of one per
## row per run.

type
  ShapeRect* = object
    x*, y*, w*, h*: int

  AlphaMask* = object
    width*, height*: int
    alpha*: seq[uint8]           ## row-major, one byte a pixel

proc at*(m: AlphaMask, x, y: int): uint8 {.inline.} = m.alpha[y * m.width + x]

proc rowRuns(m: AlphaMask, y: int, threshold: uint8): seq[(int, int)] =
  ## The [start, end) runs of row `y` at or above `threshold`.
  var x = 0
  while x < m.width:
    while x < m.width and m.at(x, y) < threshold: inc x
    if x >= m.width: break
    let start = x
    while x < m.width and m.at(x, y) >= threshold: inc x
    result.add (start, x)

proc toRects*(m: AlphaMask, threshold: uint8 = 128): seq[ShapeRect] =
  ## The opaque part of `m` (alpha >= `threshold`) as rectangles, row bands
  ## merged. An empty mask gives no rectangles: a window shaped by that shows
  ## nothing and takes no clicks.
  var band: seq[(int, int)]
  var bandTop = 0
  for row in 0 .. m.height:
    let runs = if row < m.height: m.rowRuns(row, threshold) else: @[]
    if row == 0:
      band = runs
      bandTop = 0
      continue
    if row < m.height and runs == band:
      continue
    for (a, b) in band:
      result.add ShapeRect(x: a, y: bandTop, w: b - a, h: row - bandTop)
    band = runs
    bandTop = row

proc covers*(rects: seq[ShapeRect], x, y: int): bool =
  ## Whether the point is inside the shape: what a hit test asks.
  for r in rects:
    if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h: return true

proc maskFromRGBA*(width, height: int, rgba: openArray[uint8]): AlphaMask =
  ## The alpha channel of an RGBA8 image (raylib's PixelFormat.UncompressedR8g8b8a8).
  result = AlphaMask(width: width, height: height, alpha: newSeq[uint8](width * height))
  for i in 0 ..< width * height:
    result.alpha[i] = rgba[i * 4 + 3]

proc maskFromFunc*(width, height: int, inside: proc(x, y: float32): float32): AlphaMask =
  ## A mask from a coverage function (0 outside .. 1 inside), sampled at pixel
  ## centres: how a shader's shape becomes a region the OS can use.
  result = AlphaMask(width: width, height: height, alpha: newSeq[uint8](width * height))
  for y in 0 ..< height:
    for x in 0 ..< width:
      let c = clamp(inside(float32(x) + 0.5, float32(y) + 0.5), 0.0, 1.0)
      result.alpha[y * width + x] = uint8(c * 255)

proc rectsFromFunc*(width, height: int, inside: proc(x, y: float32): float32,
                    step = 1, threshold = 0.5'f32): seq[ShapeRect] =
  ## The shape of a coverage function as rectangles, sampled every `step`
  ## pixels. For an input region that follows an animated shape: sampling a
  ## 420x420 shape every pixel took ~4 ms a frame in the spikes, every 3rd
  ## pixel a ninth of that, and a click target a pixel or two coarse at its
  ## edge is not something anyone can feel (the drawn edge stays exact).
  let s = max(1, step)
  let cw = (width + s - 1) div s
  let ch = (height + s - 1) div s
  var coarse = AlphaMask(width: cw, height: ch, alpha: newSeq[uint8](cw * ch))
  for cy in 0 ..< ch:
    for cx in 0 ..< cw:
      let c = inside(float32(cx * s) + float32(s) / 2, float32(cy * s) + float32(s) / 2)
      coarse.alpha[cy * cw + cx] = if c >= threshold: 255'u8 else: 0'u8
  for r in coarse.toRects(128):
    let x = r.x * s
    let y = r.y * s
    result.add ShapeRect(x: x, y: y, w: min(r.w * s, width - x), h: min(r.h * s, height - y))

proc boundingBox*(rects: seq[ShapeRect]): ShapeRect =
  ## The smallest rectangle holding the whole shape: where its visible
  ## top-left is, and how big it really is, inside a window with a margin.
  ## Empty (all zero) for an empty shape.
  if rects.len == 0: return
  var x0 = rects[0].x
  var y0 = rects[0].y
  var x1 = rects[0].x + rects[0].w
  var y1 = rects[0].y + rects[0].h
  for r in rects:
    x0 = min(x0, r.x); y0 = min(y0, r.y)
    x1 = max(x1, r.x + r.w); y1 = max(y1, r.y + r.h)
  ShapeRect(x: x0, y: y0, w: x1 - x0, h: y1 - y0)
