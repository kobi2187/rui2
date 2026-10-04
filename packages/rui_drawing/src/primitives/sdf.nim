## Rounded boxes by signed distance, in a raylib shader.
##
## raylib draws a rounded rectangle as a fan of triangles, which has hard,
## aliased edges (the window's MSAA never reaches a widget's own render
## texture) and a fixed corner tessellation. Here the box is one quad and the
## fragment shader works out, per pixel, how far it is from the box's edge:
## the edge fades over one pixel at any radius, a border of any width is the
## same distance field offset inwards, and fill and border are blended in one
## pass with no seam between them.
##
## The colours it outputs are straight (not premultiplied), which is what
## widget textures are painted with (see main_loop's `paintingIntoTexture`).
##
## `drawSdfBox` returns false when it cannot draw -- no window yet, or a shader
## that did not compile -- so callers fall back to the triangle path and
## headless tests are unaffected.

import raylib
import rui_core

const sdfFragment = """
#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform vec2 boxSize;      // the box, in pixels
uniform float margin;      // transparent pixels around it, for the soft edge
uniform float radius;
uniform float border;
uniform vec4 fillColor;
uniform vec4 borderColor;

float roundBox(vec2 p, vec2 half_, float r) {
  vec2 q = abs(p) - half_ + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 p = (fragTexCoord - 0.5) * (boxSize + 2.0 * margin);
  float d = roundBox(p, boxSize * 0.5, radius);
  float outer = 1.0 - smoothstep(-0.5, 0.5, d);          // inside the box
  float inner = 1.0 - smoothstep(-0.5, 0.5, d + border); // inside the border
  // Blend fill over border in premultiplied space (no dark fringe), then
  // hand back straight colour and the box's coverage as alpha.
  float a = borderColor.a * (1.0 - inner) + fillColor.a * inner;
  vec3 c = borderColor.rgb * borderColor.a * (1.0 - inner) +
           fillColor.rgb * fillColor.a * inner;
  finalColor = vec4(c / max(a, 0.0001), a * outer);
}
"""

type
  SdfState = object
    shader: Shader
    white: Texture2D
    boxSize, margin, radius, border, fillColor, borderColor: ShaderLocation

var
  state: ptr SdfState     # created on first use, never freed (see below)
  failed = false

proc ready(): bool =
  ## Load the shader on first use, once there is a GL context. Held through a
  ## pointer that is never freed: GPU objects released by a global destructor
  ## after the window has closed crash.
  if state != nil:
    return true
  if failed or not isWindowReady():
    return false
  let sh = loadShaderFromMemory("", sdfFragment)
  if not isShaderValid(sh):
    failed = true
    return false
  state = create(SdfState)
  state.shader = sh
  state.white = loadTextureFromImage(genImageColor(1, 1, White))
  template loc(name: string): ShaderLocation = getShaderLocation(state.shader, name)
  state.boxSize = loc("boxSize")
  state.margin = loc("margin")
  state.radius = loc("radius")
  state.border = loc("border")
  state.fillColor = loc("fillColor")
  state.borderColor = loc("borderColor")
  true

proc norm(c: Color): Vector4 =
  Vector4(x: c.r.float32 / 255, y: c.g.float32 / 255, z: c.b.float32 / 255,
          w: c.a.float32 / 255)

proc drawSdfBox*(rect: Rect, radius, borderWidth: float32,
                 fill, border: Color): bool =
  ## Fill and an inset border in one pass. `radius` is in pixels and is capped
  ## at half the short side.
  if rect.width <= 0 or rect.height <= 0:
    return true
  if not ready():
    return false
  const margin = 1.0'f32
  let r = clamp(radius, 0.0'f32, min(rect.width, rect.height) / 2)
  let s = state
  setShaderValue(s.shader, s.boxSize, Vector2(x: rect.width, y: rect.height))
  setShaderValue(s.shader, s.margin, margin)
  setShaderValue(s.shader, s.radius, r)
  setShaderValue(s.shader, s.border, max(0.0'f32, borderWidth))
  setShaderValue(s.shader, s.fillColor, norm(fill))
  setShaderValue(s.shader, s.borderColor, norm(border))
  beginShaderMode(s.shader)
  drawTexture(s.white, Rectangle(x: 0, y: 0, width: 1, height: 1),
              Rectangle(x: rect.x - margin, y: rect.y - margin,
                        width: rect.width + 2 * margin,
                        height: rect.height + 2 * margin),
              Vector2(x: 0, y: 0), 0.0, White)
  endShaderMode()
  true
