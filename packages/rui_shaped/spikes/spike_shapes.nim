## Spike: three ways to give a raylib window a non-rectangular shape, timed.
##
##   nim c -d:release spike_shapes.nim
##   ./spike_shapes MODE [--frames N] [--animate] [--hold SECONDS]
##
## MODE
##   rect     a plain window, the skin on a solid background (the baseline)
##   a        transparent framebuffer, undecorated: the PNG's alpha is the shape;
##            needs a compositor, clicks on see-through pixels still land here
##   a+input  `a`, plus an X11 input shape from the PNG: clicks fall through
##   b        X11 SHAPE bounding + input region from the PNG mask: no compositor
##            needed, edges hard (a pixel is in or out)
##   c        a shader draws the shape (signed distance, antialiased) on a
##            transparent framebuffer; the input region is the same shape
##            sampled on the CPU
##   c+b      the shader's shape as the bounding region instead: no compositor
##
## --animate moves the hole every frame, so the shape (and for b/c the region
## sent to the X server) changes each frame. Prints one line of numbers.

import raylib
import std/[monotimes, times, strutils, os, math, algorithm, strformat]
import rui_shaped/[x11, mask]

const W = 420
const H = 420

const fragment = """
#version 330
in vec2 fragTexCoord;
out vec4 finalColor;
uniform vec2 hole;
uniform vec2 size;
float sdBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void main() {
  vec2 p = vec2(fragTexCoord.x, fragTexCoord.y) * size;
  float box = sdBox(p - vec2(210.0, 210.0), vec2(190.0, 150.0), 70.0);
  float bump = length(p - vec2(210.0, 70.0)) - 60.0;
  float d = max(min(box, bump), -(length(p - hole) - 40.0));
  float a = clamp(0.5 - d, 0.0, 1.0);
  vec3 c = mix(vec3(0.357, 0.424, 1.0), vec3(0.133, 0.757, 0.639), p.y / size.y);
  finalColor = vec4(c * a, a);      // premultiplied: the compositor blends it
}
"""

proc main() =
  ## Everything with a GPU object lives here, so it is unloaded when main
  ## returns -- before closeWindow takes the GL context away.
  let mode = if paramCount() >= 1: paramStr(1) else: "rect"
  var frames = 300
  var animate = false
  var hold = 0.0
  var i = 2
  while i <= paramCount():
    case paramStr(i)
    of "--frames": inc i; frames = parseInt(paramStr(i))
    of "--animate": animate = true
    of "--hold": inc i; hold = parseFloat(paramStr(i))
    else: discard
    inc i

  let transparent = mode in ["a", "a+input", "c"]
  let osBounding = mode in ["b", "c+b"]
  let osInput = mode in ["a+input", "b", "c", "c+b"]
  let useShader = mode in ["c", "c+b"]

  var flags = flags(WindowUndecorated)
  if mode == "rect": flags = flags(WindowResizable)
  if transparent: flags = flags(WindowUndecorated, WindowTransparent)
  setConfigFlags(flags)
  setTraceLogLevel(TraceLogLevel.Warning)
  initWindow(W, H, "shaped " & mode)
  setTargetFPS(0)                      # as fast as it goes: we are timing it

  # --- the shape, three ways to know it --------------------------------------

  var skin = loadImage("assets/skin.png")
  # The compositor blends a window's pixels as premultiplied colour; a straight-
  # alpha PNG drawn as is leaves a light fringe along every soft edge.
  imageAlphaPremultiply(skin)
  var skinTex = loadTextureFromImage(skin)
  var skinMask: AlphaMask
  block:
    let colors = loadImageColors(skin)
    var rgba = newSeq[uint8](W * H * 4)
    for k in 0 ..< W * H:
      rgba[k * 4 + 3] = colors[k].a
    skinMask = maskFromRGBA(W, H, rgba)

  proc holeAt(t: float32): (float32, float32) =
    ## Where the hole is: still, or circling when animated.
    if not animate: (300'f32, 210'f32)
    else: (210'f32 + 90 * cos(t * 1.7), 210'f32 + 60 * sin(t * 1.7))

  proc sdf(x, y: float32, hx, hy: float32): float32 =
    ## The skin as a signed distance (negative inside): a rounded box with a
    ## round bump on top, minus the hole. The shader computes the same thing.
    let cx = x - 210
    let cy = y - 210
    let qx = abs(cx) - (190 - 70)
    let qy = abs(cy) - (150 - 70)
    let box = sqrt(max(qx, 0) ^ 2 + max(qy, 0) ^ 2) + min(max(qx, qy), 0) - 70
    let bump = sqrt((x - 210) ^ 2 + (y - 70) ^ 2) - 60
    let hole = sqrt((x - hx) ^ 2 + (y - hy) ^ 2) - 40
    max(min(box, bump), -hole)



  var shader: Shader
  var holeLoc, sizeLoc: ShaderLocation
  if useShader:
    shader = loadShaderFromMemory("", fragment)
    holeLoc = getShaderLocation(shader, "hole")
    sizeLoc = getShaderLocation(shader, "size")
    setShaderValue(shader, sizeLoc, Vector2(x: W.float32, y: H.float32))

  # --- the X11 side -----------------------------------------------------------

  let x = x11()
  var dpy: ptr Display
  var win: XWindow
  var compositor, argb, shapeExt = false
  var depth = 0
  if x.ok:
    dpy = x.openDisplay(nil)
    if dpy != nil:
      win = cast[ptr XWindow](getWindowHandle())[]
      compositor = x.compositorRunning(dpy)
      argb = x.hasArgbVisual(dpy)
      depth = x.windowDepth(dpy, win)
      if x.shapeOk:
        var ev, er: cint
        shapeExt = x.shapeQuery(dpy, ev.addr, er.addr) != 0

  proc applyRegion(rects: seq[ShapeRect], kind: cint): float =
    ## Send `rects` as the window's `kind` shape; returns the time to the
    ## server's acknowledgement (XSync), in microseconds.
    var xr = newSeq[XRectangle](rects.len)
    for k, r in rects:
      xr[k] = XRectangle(x: r.x.cshort, y: r.y.cshort, width: r.w.cushort, height: r.h.cushort)
    let t0 = getMonoTime()
    x.shapeRects(dpy, win, kind, 0, 0, (if xr.len > 0: xr[0].addr else: nil),
                 xr.len.cint, ShapeSet, Unsorted)
    discard x.sync(dpy, 0)
    float((getMonoTime() - t0).inNanoseconds) / 1000.0

  proc currentRects(t: float32): (seq[ShapeRect], float) =
    ## The shape as rectangles now, and how long building them took (us).
    let t0 = getMonoTime()
    let rects = if useShader or animate:
                  let (hx, hy) = holeAt(t)
                  maskFromFunc(W, H, proc(px, py: float32): float32 =
                    clamp(0.5'f32 - sdf(px, py, hx, hy), 0, 1)).toRects
                else: skinMask.toRects
    (rects, float((getMonoTime() - t0).inNanoseconds) / 1000.0)

  var regionUs, buildUs: seq[float]
  var rectCount = 0
  proc reshape(t: float32) =
    if not (osBounding or osInput) or not shapeExt: return
    let (rects, built) = currentRects(t)
    rectCount = rects.len
    buildUs.add built
    var sent = 0.0
    if osBounding: sent += applyRegion(rects, ShapeBounding)
    if osInput: sent += applyRegion(rects, ShapeInput)
    regionUs.add sent

  reshape(0)

  # --- the frames -------------------------------------------------------------

  var frameUs: seq[float]
  let start = getMonoTime()
  var n = 0
  while not windowShouldClose() and (n < frames or
        (hold > 0 and (getMonoTime() - start).inMilliseconds.float < hold * 1000)):
    let t = float32((getMonoTime() - start).inMilliseconds) / 1000
    if isMouseButtonPressed(MouseButton.Left):
      let p = getMousePosition()
      echo "click ", int(p.x), " ", int(p.y)       # which clicks reach the app
    let f0 = getMonoTime()
    if animate and n > 0: reshape(t)
    beginDrawing()
    if transparent: clearBackground(Color(r: 0, g: 0, b: 0, a: 0))
    else: clearBackground(Color(r: 40, g: 40, b: 48, a: 255))
    if useShader:
      let (hx, hy) = holeAt(t)
      setShaderValue(shader, holeLoc, Vector2(x: hx, y: hy))
      beginShaderMode(shader)
      drawTexture(skinTex, Rectangle(x: 0, y: 0, width: W.float32, height: H.float32),
                     Rectangle(x: 0, y: 0, width: W.float32, height: H.float32),
                     Vector2(x: 0, y: 0), 0, White)       # the quad the shader paints
      endShaderMode()
    else:
      beginBlendMode(BlendMode.AlphaPremultiply)
      drawTexture(skinTex, 0, 0, White)
      endBlendMode()
    endDrawing()
    frameUs.add float((getMonoTime() - f0).inNanoseconds) / 1000.0
    inc n

  proc median(xs: seq[float]): float =
    if xs.len == 0: return 0
    var s = xs
    s.sort()
    s[s.len div 2]

  proc p95(xs: seq[float]): float =
    if xs.len == 0: return 0
    var s = xs
    s.sort()
    s[min(s.high, int(s.len.float * 0.95))]

  echo &"mode={mode} animate={animate} frames={frameUs.len} " &
       &"frame_med_us={median(frameUs):.0f} frame_p95_us={p95(frameUs):.0f} " &
       &"region_rects={rectCount} region_build_med_us={median(buildUs):.0f} " &
       &"region_send_med_us={median(regionUs):.0f} " &
       &"x11={x.ok} shape_ext={shapeExt} compositor={compositor} argb_visual={argb} window_depth={depth}"

main()
closeWindow()
