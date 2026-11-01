## The page behind an open modal, as the theme wants it seen.
##
## When a modal opens the App takes a picture of the window as it was (see
## rui_core freeze.nim) and runs it once through `makeBackdrop`: blurred by the
## theme's `backdrop.blur`, its colour faded to `backdrop.saturation`, tinted by
## `backdrop.color`. The modal then draws that still picture behind its panel
## (`drawBackdrop`). The default is the old look -- half-transparent black --
## and themes may soften or frost it.
##
## Pixels stay premultiplied all the way, as widget textures are; the tint only
## covers what was there, so a shaped window's see-through parts stay clear.
## Without a window (headless tests) nothing is drawn but the plain tint.
##
## The theme filters the page; a *painter* draws on it. Set one for the app,
## or for one modal, and it is drawn over the filtered picture as it is taken
## -- once, baked in, so even a busy one costs nothing while the dialog waits:
##
## ```nim
## setBackdropPainter(cautionTape("WAITING FOR YOU"))      # every modal
## setBackdropPainter(saveDialog, backdropCaption("Frozen"))  # just this one
## setBackdropPainter(proc(area: Rect) =                   # your own
##   drawStyledText("Frozen", area.x + 20, area.y + 20, myStyle))
## ```
##
## A painter set while a modal is open shows the next time its picture is
## taken (a resize, a theme change, the next time it opens).

import raylib, rlgl
import rui_core
import theme_sys_core
import widget_primitives
import primitives/[text, sdf, shapes]
import std/[tables, math]

type BackdropPainter* = proc(area: Rect) {.closure.}
  ## Draws over the frozen page, in window coordinates; `area` is the window.

var appPainter: BackdropPainter
var modalPainters = initTable[pointer, BackdropPainter]()

proc setBackdropPainter*(painters: varargs[BackdropPainter]) =
  ## What is drawn over the frozen page behind every modal, in order; none
  ## clears it.
  let all = @painters
  if all.len == 0:
    appPainter = nil
  else:
    appPainter = proc(area: Rect) =
      for p in all: p(area)

proc setBackdropPainter*(modal: Widget, painters: varargs[BackdropPainter]) =
  ## The same for one modal, in place of the app's; none goes back to it.
  let key = cast[pointer](modal)
  let all = @painters
  if all.len == 0:
    modalPainters.del key
  else:
    modalPainters[key] = proc(area: Rect) =
      for p in all: p(area)

proc backdropPainterFor*(modal: Widget): BackdropPainter =
  ## The painter for `modal`'s backdrop: its own, else the app's, else nil.
  modalPainters.getOrDefault(cast[pointer](modal), appPainter)

# ----------------------------------------------------------------------------
# Ready-made painters
# ----------------------------------------------------------------------------

proc stripesIn(band: Rect, stripe: float32, color: Color, offset = 0.0'f32) =
  ## Diagonal stripes (45 degrees, rising to the right) filling `band`. Each
  ## is exactly the band's height; what runs past its ends is cut by the
  ## picture's own edge (a band spans the window).
  let h = band.height
  var x = band.x - h + offset mod (stripe * 2)
  while x < band.x + band.width:
    let a = Vector2(x: x, y: band.y + h)
    let b = Vector2(x: x + h, y: band.y)
    let c = Vector2(x: x + h + stripe, y: band.y)
    let d = Vector2(x: x + stripe, y: band.y + h)
    if not drawSdfTriangle(a, b, c, color): drawTriangle(a, c, b, color)
    if not drawSdfTriangle(a, c, d, color): drawTriangle(a, d, c, color)
    x += stripe * 2

proc hazardStripes*(color = Color(r: 255, g: 196, b: 0, a: 70), stripe = 30.0'f32): BackdropPainter =
  ## Faint diagonal stripes over the whole page: under construction, don't
  ## touch.
  result = proc(area: Rect) = stripesIn(area, stripe, color)

proc cautionTape*(label = "", band = 34.0'f32,
                  tape = Color(r: 255, g: 204, b: 0, a: 255),
                  ink = Color(r: 20, g: 20, b: 20, a: 255)): BackdropPainter =
  ## Barrier tape across the top and bottom of the page -- yellow and black
  ## stripes -- with `label` along it, if given.
  result = proc(area: Rect) =
    for y in [area.y + band * 0.6, area.y + area.height - band * 1.6]:
      let r = Rect(x: area.x, y: y, width: area.width, height: band)
      drawRectangle(Rectangle(x: r.x, y: r.y, width: r.width, height: r.height), tape)
      stripesIn(r, band * 0.55, ink)
      if label.len > 0:
        let style = TextStyle(fontSize: band * 0.5, color: ink, bold: true)
        let w = measureText(label, style).width + band
        var x = area.x + band
        while x < area.x + area.width:
          let plate = Rectangle(x: x - band * 0.3, y: y + band * 0.12,
                                width: w - band * 0.4, height: band * 0.76)
          drawRectangle(plate, tape)
          drawStyledText(label, x, y + (band - style.fontSize) / 2, style)
          x += w * 3

proc backdropCaption*(text: string, size = 22.0'f32,
                      color = Color(r: 255, g: 255, b: 255, a: 200),
                      atTop = true): BackdropPainter =
  ## A word over the page -- "Frozen", "Waiting for your answer" -- centred at
  ## its top (or bottom), clear of the dialog in the middle.
  result = proc(area: Rect) =
    let style = TextStyle(fontSize: size, color: color, bold: true)
    let y = if atTop: area.y + size else: area.y + area.height - size * 2
    drawStyledText(text, area.x + area.width / 2, y, style, centered = true)

const backdropFragment = """
#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform vec2 texel;
uniform float blur;
uniform float saturation;
uniform vec4 tint;
out vec4 finalColor;
void main() {
  vec4 c;
  if (blur < 0.5) {
    c = texture(texture0, fragTexCoord);
  } else {
    // A gaussian over a 13x13 grid spanning +-blur pixels. Run once per
    // modal, so the 169 taps cost nothing anyone waits for.
    float sigma = blur / 2.0;
    vec4 sum = vec4(0.0);
    float weights = 0.0;
    for (int i = -6; i <= 6; i++) {
      for (int j = -6; j <= 6; j++) {
        vec2 o = vec2(float(i), float(j)) * (blur / 6.0);
        float w = exp(-dot(o, o) / (2.0 * sigma * sigma));
        sum += texture(texture0, fragTexCoord + o * texel) * w;
        weights += w;
      }
    }
    c = sum / weights;
  }
  float grey = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  c.rgb = mix(vec3(grey), c.rgb, saturation);
  c.rgb = mix(c.rgb, tint.rgb * c.a, tint.a);   // premultiplied: tint what is there
  finalColor = c;
}
"""

type BackdropShader = object
  shader: Shader
  texel, blur, saturation, tint: ShaderLocation
  failed: bool

var effect: ptr BackdropShader
  ## Loaded on first use; held through a pointer that is never freed, because a
  ## GPU object released by a global destructor after the window closed crashes.

proc loaded(): ptr BackdropShader =
  if effect != nil:
    return (if effect.failed: nil else: effect)
  if not isWindowReady(): return nil
  effect = create(BackdropShader)
  effect.shader = loadShaderFromMemory("", backdropFragment)
  if not isShaderValid(effect.shader):
    effect.failed = true
    return nil
  effect.texel = getShaderLocation(effect.shader, "texel")
  effect.blur = getShaderLocation(effect.shader, "blur")
  effect.saturation = getShaderLocation(effect.shader, "saturation")
  effect.tint = getShaderLocation(effect.shader, "tint")
  effect

proc makeBackdrop*(picture: RenderTexture2D, theme: Theme,
                   painter: BackdropPainter = nil): RenderTexture2D =
  ## `picture` (the window as it was) in `theme`'s backdrop look, with
  ## `painter`'s drawing over it, as a new texture the same size. Without the
  ## shader, the plain tint over it.
  let w = picture.texture.width
  let h = picture.texture.height
  result = loadRenderTexture(w, h)
  setTextureFilter(picture.texture, TextureFilter.Bilinear)
  let tint = theme.backdropColor
  let s = loaded()
  beginTextureMode(result)
  clearBackground(Color(r: 0, g: 0, b: 0, a: 0))
  compositingTextures:
    if s != nil:
      setShaderValue(s.shader, s.texel, Vector2(x: 1.0'f32 / w.float32, y: 1.0'f32 / h.float32))
      setShaderValue(s.shader, s.blur, theme.backdropBlur)
      setShaderValue(s.shader, s.saturation, theme.backdropSaturation)
      setShaderValue(s.shader, s.tint, Vector4(x: tint.r.float32 / 255, y: tint.g.float32 / 255,
                                               z: tint.b.float32 / 255, w: tint.a.float32 / 255))
      beginShaderMode(s.shader)
      drawRenderTexture(picture, 0, 0)
      endShaderMode()
    else:
      drawRenderTexture(picture, 0, 0)
  if s == nil:
    drawRectangle(0, 0, w, h, tint)
  if painter != nil:
    paintingIntoTexture:
      painter(Rect(x: 0, y: 0, width: w.float32, height: h.float32))
  endTextureMode()

proc drawBackdrop*(modal: Widget, bounds: Rect) =
  ## What a modal paints first, over `bounds` (its whole area): the frozen page
  ## when the App has taken it, else the theme's tint over whatever is behind.
  let picture = backdropOf(modal)
  if picture == nil:
    drawRectangle(Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height),
                  currentTheme.backdropColor)
    return
  # The picture is the whole window; the modal covers its root, which may sit
  # inside the window (a shaped one's content area). Already premultiplied, so
  # it goes in through the compositing blend, then painting resumes.
  # While it paints, its own bounds read (0, 0); where it really is, is where
  # its root is (modal.nim's overlayBounds).
  var root = modal
  while root.parent != nil: root = root.parent
  let origin = if root == modal: (x: 0.0'f32, y: 0.0'f32) else: (x: root.bounds.x, y: root.bounds.y)
  drawRenderBatchActive()
  endBlendMode()
  compositingTextures:
    drawRenderTexture(picture[], bounds.x - origin.x, bounds.y - origin.y)
  setBlendFactorsSeparate(SrcAlpha, OneMinusSrcAlpha, One, OneMinusSrcAlpha, FuncAdd, FuncAdd)
  beginBlendMode(BlendMode.CustomSeparate)

# ----------------------------------------------------------------------------
# Frosted glass under a floating panel
# ----------------------------------------------------------------------------
##
## A theme with `glass` (a blur radius) gives floating panels -- menus, open
## lists, popovers -- a translucent fill over the page blurred behind them. The
## App names the page it has just put on the screen (`glassPage`) while it
## composites the overlays; a panel's chrome (`floatingChrome`) calls
## `drawFrosted` for its own shape, then its texture goes over it.

var glassPage*: ptr RenderTexture2D
  ## The page under the overlays this frame, and where its top-left is on the
  ## screen; nil outside compositing. Set by the App.
var glassPageOrigin*: tuple[x, y: float32]

const glassFragment = """
#version 330
in vec2 fragTexCoord;
uniform sampler2D texture0;
uniform vec4 uvRect;       // the page area under the panel: u0, v0, u1, v1
uniform vec2 boxSize;      // the panel, in pixels
uniform vec2 texel;
uniform float radius;
uniform float cut;
uniform float blur;
out vec4 finalColor;

float roundBox(vec2 p, vec2 h, float r) {
  vec2 q = abs(p) - h + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
float cutBox(vec2 p, vec2 h, float c) {
  vec2 q = abs(p) - h;
  float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
  return max(box, (q.x + q.y + c) * 0.70710678);
}

void main() {
  vec2 local = (fragTexCoord - uvRect.xy) / (uvRect.zw - uvRect.xy);
  vec2 p = (local - 0.5) * boxSize;
  float d = cut > 0.0 ? cutBox(p, boxSize * 0.5, cut) : roundBox(p, boxSize * 0.5, radius);
  float inside = 1.0 - smoothstep(-0.5, 0.5, d);
  float sigma = max(blur, 0.5) / 2.0;
  vec4 sum = vec4(0.0);
  float weights = 0.0;
  for (int i = -5; i <= 5; i++) {
    for (int j = -5; j <= 5; j++) {
      vec2 o = vec2(float(i), float(j)) * (blur / 5.0);
      float w = exp(-dot(o, o) / (2.0 * sigma * sigma));
      sum += texture(texture0, fragTexCoord + o * texel) * w;
      weights += w;
    }
  }
  finalColor = (sum / weights) * inside;      // premultiplied, like the page
}
"""

type GlassShader = object
  shader: Shader
  uvRect, boxSize, texel, radius, cut, blur: ShaderLocation
  failed: bool

var glassFx: ptr GlassShader   ## loaded on first use, never freed (see `effect`)

proc glassLoaded(): ptr GlassShader =
  if glassFx != nil:
    return (if glassFx.failed: nil else: glassFx)
  if not isWindowReady(): return nil
  glassFx = create(GlassShader)
  glassFx.shader = loadShaderFromMemory("", glassFragment)
  if not isShaderValid(glassFx.shader):
    glassFx.failed = true
    return nil
  for (field, name) in [(addr glassFx.uvRect, "uvRect"), (addr glassFx.boxSize, "boxSize"),
                        (addr glassFx.texel, "texel"), (addr glassFx.radius, "radius"),
                        (addr glassFx.cut, "cut"), (addr glassFx.blur, "blur")]:
    field[] = getShaderLocation(glassFx.shader, name)
  glassFx

proc drawFrosted*(area: Rect, blur: float32, radius = 0'f32, cut = 0'f32): bool =
  ## The page behind `area` (screen space), blurred `blur` pixels and cut to the
  ## panel's shape (`radius` corners, or `cut` notches). False when there is
  ## nothing to blur (no page named, no shader): the panel is then simply
  ## translucent. Call it in the compositing blend, where the App calls chrome.
  if glassPage == nil or blur <= 0 or area.width <= 0 or area.height <= 0: return false
  let s = glassLoaded()
  if s == nil: return false
  template tex: untyped = glassPage[].texture     # borrowed: a Texture cannot be copied
  let w = tex.width.float32
  let h = tex.height.float32
  # The page's texture is stored bottom-up: its row for screen y is h - y. A
  # negative height flips the source about its rectangle, which then starts at
  # the area's bottom row.
  let sx = area.x - glassPageOrigin.x
  let sy = area.y - glassPageOrigin.y
  let src = Rectangle(x: sx, y: h - sy - area.height, width: area.width, height: -area.height)
  setTextureFilter(tex, TextureFilter.Bilinear)
  setShaderValue(s.shader, s.uvRect, Vector4(x: sx / w, y: (h - sy) / h,
                                             z: (sx + area.width) / w, w: (h - sy - area.height) / h))
  setShaderValue(s.shader, s.boxSize, Vector2(x: area.width, y: area.height))
  setShaderValue(s.shader, s.texel, Vector2(x: 1 / w, y: 1 / h))
  setShaderValue(s.shader, s.radius, clamp(radius, 0'f32, min(area.width, area.height) / 2))
  setShaderValue(s.shader, s.cut, max(0'f32, cut))
  setShaderValue(s.shader, s.blur, blur)
  beginShaderMode(s.shader)
  drawTexture(tex, src, Rectangle(x: area.x, y: area.y, width: area.width, height: area.height),
              Vector2(x: 0, y: 0), 0.0, Color(r: 255, g: 255, b: 255, a: 255))
  endShaderMode()
  true

proc floatingChrome*(shadow = true): proc(bounds: Rect) {.closure.} =
  ## The chrome for a panel that floats above the page, drawn in screen space
  ## so its own texture does not clip it: its soft shadow (unless `shadow` is
  ## false), and in a glass theme the page frosted behind it, the panel's shape.
  result = proc(bounds: Rect) =
    let props = currentTheme.getThemeProps(Default, Normal)
    if shadow: drawFloatingShadow(bounds, props)
    if currentTheme.glass > 0:
      # The page texture is clear where the window's canvas shows, so the sharp
      # page already on the screen is covered first, in the panel's shape.
      let canvas = currentTheme.canvasColor()
      drawBox(bounds, props.cornerRadius.get(4.0), canvas, canvas, 0,
              BoxFinish(cut: props.cornerCut.get(0)))
      discard drawFrosted(bounds, currentTheme.glass, props.cornerRadius.get(4.0),
                          props.cornerCut.get(0))

