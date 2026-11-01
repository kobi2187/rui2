## Would packing our many small textures into one atlas be faster?
##
## What rui puts on the GPU: every distinct text run is rendered by Pango into
## its own small texture and uploaded once (pango_text.nim); every widget's
## cached look is a render texture drawn, one texture each, when the window is
## composited. Game engines pack sprites into an atlas instead. This measures
## both halves of that, with N text-sized bitmaps (40-200 x 16-24 px):
##
## - upload: N uploads of N bitmaps, against packing them on the CPU into one
##   atlas and uploading that once;
## - draw: a frame of N quads from N textures (raylib ends a batch, one draw
##   call, at every texture change), against N quads from one atlas (one batch).
##
## Each timing ends with glFinish, so it counts the GPU's work, not just the
## queueing of it. The swap is left out.
##
##   nim c -r -d:release -d:useGraphics tools/atlas_bench.nim
##
## Run it on the machine you care about: under Xvfb the "GPU" is a software
## rasterizer, whose costs are not a real GPU driver's.

import std/[monotimes, times, random, algorithm, strformat, os]
import raylib, rlgl

proc glFinish() {.importc: "glFinish", cdecl.}
proc glGetString(name: uint32): cstring {.importc: "glGetString", cdecl.}
const GL_RENDERER = 0x1F01'u32

type Bitmap = object
  w, h: int32
  pixels: seq[Color]

proc makeBitmaps(n: int): seq[Bitmap] =
  ## Text-like runs: white, the alpha a pattern (as Pango's coverage masks are).
  randomize(42)
  for i in 0 ..< n:
    let w = int32(rand(40 .. 200))
    let h = int32(rand(16 .. 24))
    var px = newSeq[Color](w * h)
    for y in 0 ..< h:
      for x in 0 ..< w:
        px[y * w + x] = Color(r: 255, g: 255, b: 255, a: uint8((x * 7 + y * 13 + i) mod 256))
    result.add Bitmap(w: w, h: h, pixels: px)

proc ms(d: Duration): float = d.inNanoseconds.float / 1e6

type Slot = object
  x, y: int32

proc shelfPack(bms: seq[Bitmap], width: int32): tuple[slots: seq[Slot], height: int32] =
  ## Tallest first, left to right in rows ("shelves"), 1 px apart.
  var order = newSeq[int](bms.len)
  for i in 0 ..< bms.len: order[i] = i
  order.sort(proc(a, b: int): int = cmp(bms[b].h, bms[a].h))
  result.slots.setLen(bms.len)
  var x, y, shelf = 0'i32
  for i in order:
    let b = bms[i]
    if x + b.w > width:
      x = 0
      y += shelf + 1
      shelf = 0
    result.slots[i] = Slot(x: x, y: y)
    x += b.w + 1
    shelf = max(shelf, b.h)
  result.height = y + shelf

proc blit(atlas: var seq[Color], aw: int32, b: Bitmap, s: Slot) =
  for row in 0 ..< b.h:
    copyMem(addr atlas[(s.y + row) * aw + s.x], unsafeAddr b.pixels[row * b.w], b.w * sizeof(Color))

proc run(n: int, frames = 120) =
  let bms = makeBitmaps(n)
  var bytes = 0
  for b in bms: bytes += b.pixels.len * 4

  # --- upload: one each ---
  var each: seq[Texture2D]
  let t0 = getMonoTime()
  for b in bms: each.add loadTextureFromData(b.pixels, b.w, b.h)
  glFinish()
  let uploadEach = ms(getMonoTime() - t0)

  # --- upload: packed ---
  let aw = 2048'i32
  let t1 = getMonoTime()
  let (slots, ah0) = shelfPack(bms, aw)
  let ah = max(1'i32, ah0)
  var atlasPx = newSeq[Color](aw * ah)
  for i, b in bms: blit(atlasPx, aw, b, slots[i])
  let packed = ms(getMonoTime() - t1)
  let t2 = getMonoTime()
  let atlas = loadTextureFromData(atlasPx, aw, ah)
  glFinish()
  let uploadAtlas = ms(getMonoTime() - t2)

  # --- draw ---
  proc frameTime(drawAll: proc()): float =
    var total = 0.0
    for f in 0 ..< frames:
      beginDrawing()
      clearBackground(Black)
      let s = getMonoTime()
      drawAll()
      drawRenderBatchActive()
      glFinish()
      total += ms(getMonoTime() - s)
      endDrawing()
    total / frames.float
  let cols = 6
  proc pos(i: int): Vector2 = Vector2(x: float32((i mod cols) * 130), y: float32((i div cols) mod 30 * 20))
  let drawEach = frameTime(proc() =
    for i in 0 ..< n: drawTexture(each[i], pos(i), White))
  let drawAtlas = frameTime(proc() =
    for i in 0 ..< n:
      let b = bms[i]
      drawTexture(atlas, Rectangle(x: slots[i].x.float32, y: slots[i].y.float32,
                                   width: b.w.float32, height: b.h.float32),
                  pos(i), White))
  echo &"N={n:5}  pixels {bytes div 1024:6} KB  atlas {aw}x{ah} ({100.0 * bytes.float / float(aw * ah * 4):4.0f}% used)"
  echo &"   upload  each {uploadEach:8.2f} ms   atlas {uploadAtlas:7.2f} ms + packing {packed:6.2f} ms"
  echo &"   draw    each {drawEach:8.3f} ms/frame   atlas {drawAtlas:7.3f} ms/frame"

when isMainModule:
  setTraceLogLevel(TraceLogLevel.Warning)
  initWindow(800, 600, "atlas bench")
  setTargetFPS(0)
  echo "GL renderer: ", $glGetString(GL_RENDERER)
  for n in [100, 500, 2000]: run(n)
  closeWindow()
