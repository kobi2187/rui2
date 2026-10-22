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
import primitives/[text, sdf]
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
