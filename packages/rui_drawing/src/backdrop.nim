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

import raylib, rlgl
import rui_core
import theme_sys_core

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

proc makeBackdrop*(picture: RenderTexture2D, theme: Theme): RenderTexture2D =
  ## `picture` (the window as it was) in `theme`'s backdrop look, as a new
  ## texture the same size. Without the shader, the plain tint over it.
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
