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
## `drawSdfShadow` does the same for a drop shadow: a blurred rounded box, its
## edge a smooth falloff over the blur radius, in place of the stacked rectangles
## that show as bands.
##
## `drawSdfBox` and `drawSdfShadow` return false when they cannot draw -- no
## window yet, or a shader that did not compile -- so callers fall back to the
## triangle or rectangle path and headless tests are unaffected.

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

const sdfShadowFragment = """
#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform vec2 quadSize;     // the quad, in pixels: the box plus room for the blur
uniform vec2 boxSize;      // the casting box, in pixels
uniform vec2 offset;       // how far the shadow sits from the box
uniform float radius;
uniform float spread;      // grows the shadow's box on every side
uniform float blur;        // half-width of the soft edge, in pixels
uniform vec4 shadowColor;

float roundBox(vec2 p, vec2 half_, float r) {
  vec2 q = abs(p) - half_ + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  // Pixels relative to the box's centre, with the shadow's own offset taken out.
  vec2 p = (fragTexCoord - 0.5) * quadSize - offset;
  float d = roundBox(p, boxSize * 0.5 + spread, radius + spread);
  // Half-way at the edge, fading out over the blur: close to a Gaussian shadow.
  float a = shadowColor.a * (1.0 - smoothstep(-blur, blur, d));
  finalColor = vec4(shadowColor.rgb, a);
}
"""

type
  GlShader = object
    shader: Shader
    locs: seq[ShaderLocation]   # in the order the names were given to loadGlShader
    failed: bool                # compiled badly once: do not try again

var
  white: Texture2D              # a 1x1 white texture, stretched to draw a quad
  hasWhite = false
  boxState: ptr GlShader        # created on first use, never freed (see below)
  shadowState: ptr GlShader

proc loadGlShader(slot: var ptr GlShader, fragment: string,
                  names: openArray[string]): ptr GlShader =
  ## Load a fragment shader on first use, once there is a GL context. Held through
  ## a pointer that is never freed: GPU objects released by a global destructor
  ## after the window has closed crash. nil while it cannot be loaded.
  if slot != nil:
    return slot
  if not isWindowReady():
    return nil
  slot = create(GlShader)
  slot.shader = loadShaderFromMemory("", fragment)
  if not isShaderValid(slot.shader):
    slot.failed = true
    return nil
  for name in names:
    slot.locs.add getShaderLocation(slot.shader, name)
  if not hasWhite:
    white = loadTextureFromImage(genImageColor(1, 1, White))
    hasWhite = true
  slot

proc ready(slot: var ptr GlShader, fragment: string,
           names: openArray[string]): ptr GlShader =
  if slot != nil and slot.failed: return nil
  loadGlShader(slot, fragment, names)

proc norm(c: Color): Vector4 =
  Vector4(x: c.r.float32 / 255, y: c.g.float32 / 255, z: c.b.float32 / 255,
          w: c.a.float32 / 255)

proc drawQuad(s: ptr GlShader, quad: Rect) =
  ## The white texture stretched over `quad`, through the shader.
  beginShaderMode(s.shader)
  drawTexture(white, Rectangle(x: 0, y: 0, width: 1, height: 1),
              Rectangle(x: quad.x, y: quad.y, width: quad.width, height: quad.height),
              Vector2(x: 0, y: 0), 0.0, White)
  endShaderMode()

proc drawSdfBox*(rect: Rect, radius, borderWidth: float32,
                 fill, border: Color): bool =
  ## Fill and an inset border in one pass. `radius` is in pixels and is capped
  ## at half the short side.
  if rect.width <= 0 or rect.height <= 0:
    return true
  let s = boxState.ready(sdfFragment,
    ["boxSize", "margin", "radius", "border", "fillColor", "borderColor"])
  if s == nil: return false
  const margin = 1.0'f32
  let r = clamp(radius, 0.0'f32, min(rect.width, rect.height) / 2)
  setShaderValue(s.shader, s.locs[0], Vector2(x: rect.width, y: rect.height))
  setShaderValue(s.shader, s.locs[1], margin)
  setShaderValue(s.shader, s.locs[2], r)
  setShaderValue(s.shader, s.locs[3], max(0.0'f32, borderWidth))
  setShaderValue(s.shader, s.locs[4], norm(fill))
  setShaderValue(s.shader, s.locs[5], norm(border))
  s.drawQuad(Rect(x: rect.x - margin, y: rect.y - margin,
                  width: rect.width + 2 * margin, height: rect.height + 2 * margin))
  true

proc drawSdfShadow*(rect: Rect, radius, offsetX, offsetY, blur, spread: float32,
                    color: Color): bool =
  ## A soft drop shadow of the rounded box `rect`, moved by (offsetX, offsetY),
  ## grown by `spread`, and feathered over `blur` pixels either side of its edge.
  ## False when the shader cannot run here, so the caller draws the old way.
  if rect.width <= 0 or rect.height <= 0 or color.a == 0:
    return true
  let s = shadowState.ready(sdfShadowFragment,
    ["quadSize", "boxSize", "offset", "radius", "spread", "blur", "shadowColor"])
  if s == nil: return false
  # The quad has to reach past the feathered edge and the offset, on every side.
  let pad = blur * 2 + max(abs(offsetX), abs(offsetY)) + max(spread, 0.0'f32)
  let quad = Rect(x: rect.x - pad, y: rect.y - pad,
                  width: rect.width + 2 * pad, height: rect.height + 2 * pad)
  let r = clamp(radius, 0.0'f32, min(rect.width, rect.height) / 2)
  setShaderValue(s.shader, s.locs[0], Vector2(x: quad.width, y: quad.height))
  setShaderValue(s.shader, s.locs[1], Vector2(x: rect.width, y: rect.height))
  setShaderValue(s.shader, s.locs[2], Vector2(x: offsetX, y: offsetY))
  setShaderValue(s.shader, s.locs[3], r)
  setShaderValue(s.shader, s.locs[4], spread)
  setShaderValue(s.shader, s.locs[5], max(blur, 0.5'f32))
  setShaderValue(s.shader, s.locs[6], norm(color))
  s.drawQuad(quad)
  true
