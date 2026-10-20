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
## The same goes for strokes and triangles: `drawSdfSegment` is a line with round
## ends, for checkmarks and crosses, and `drawSdfTriangle` a filled triangle, for
## arrows. raylib's own line and triangle calls rasterise without anti-aliasing,
## and a widget's render texture gets no MSAA, so those came out stair-stepped.
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

const sdfSegmentFragment = """
#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform vec2 quadSize;    // the quad, in pixels
uniform vec2 segA;        // the segment's ends, in quad pixels
uniform vec2 segB;
uniform float halfWidth;
uniform vec4 strokeColor;

float segmentDistance(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
  return length(pa - ba * h);
}

void main() {
  vec2 p = fragTexCoord * quadSize;
  float d = segmentDistance(p, segA, segB) - halfWidth;
  float cover = 1.0 - smoothstep(-0.5, 0.5, d);
  finalColor = vec4(strokeColor.rgb, strokeColor.a * cover);
}
"""

const sdfTriangleFragment = """
#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform vec2 quadSize;
uniform vec2 p0;          // the corners, in quad pixels
uniform vec2 p1;
uniform vec2 p2;
uniform vec4 fillColor;

// Signed distance to a triangle: negative inside (Inigo Quilez's formulation,
// which does not care about the winding order).
float triangleDistance(vec2 p, vec2 a, vec2 b, vec2 c) {
  vec2 e0 = b - a, e1 = c - b, e2 = a - c;
  vec2 v0 = p - a, v1 = p - b, v2 = p - c;
  vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
  vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
  vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
  float s = sign(e0.x * e2.y - e0.y * e2.x);
  vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)),
                   vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))),
                   vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
  return -sqrt(d.x) * sign(d.y);
}

void main() {
  vec2 p = fragTexCoord * quadSize;
  float d = triangleDistance(p, p0, p1, p2);
  float cover = 1.0 - smoothstep(-0.5, 0.5, d);
  finalColor = vec4(fillColor.rgb, fillColor.a * cover);
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
  segmentState: ptr GlShader
  triangleState: ptr GlShader

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

proc drawSdfSegment*(a, b: Vector2, thickness: float32, color: Color): bool =
  ## A line from `a` to `b`, `thickness` wide, with round ends and smooth edges.
  ## False when the shader cannot run here, so the caller draws the old way.
  if thickness <= 0 or color.a == 0:
    return true
  let s = segmentState.ready(sdfSegmentFragment,
    ["quadSize", "segA", "segB", "halfWidth", "strokeColor"])
  if s == nil: return false
  let pad = thickness / 2 + 2
  let x0 = min(a.x, b.x) - pad
  let y0 = min(a.y, b.y) - pad
  let quad = Rect(x: x0, y: y0,
                  width: abs(a.x - b.x) + 2 * pad, height: abs(a.y - b.y) + 2 * pad)
  setShaderValue(s.shader, s.locs[0], Vector2(x: quad.width, y: quad.height))
  setShaderValue(s.shader, s.locs[1], Vector2(x: a.x - x0, y: a.y - y0))
  setShaderValue(s.shader, s.locs[2], Vector2(x: b.x - x0, y: b.y - y0))
  setShaderValue(s.shader, s.locs[3], thickness / 2)
  setShaderValue(s.shader, s.locs[4], norm(color))
  s.drawQuad(quad)
  true

proc drawSdfTriangle*(p0, p1, p2: Vector2, color: Color): bool =
  ## A filled triangle with smooth edges, whatever its winding.
  ## False when the shader cannot run here.
  if color.a == 0:
    return true
  let s = triangleState.ready(sdfTriangleFragment,
    ["quadSize", "p0", "p1", "p2", "fillColor"])
  if s == nil: return false
  const pad = 2.0'f32
  let x0 = min(p0.x, min(p1.x, p2.x)) - pad
  let y0 = min(p0.y, min(p1.y, p2.y)) - pad
  let x1 = max(p0.x, max(p1.x, p2.x)) + pad
  let y1 = max(p0.y, max(p1.y, p2.y)) + pad
  let quad = Rect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
  setShaderValue(s.shader, s.locs[0], Vector2(x: quad.width, y: quad.height))
  setShaderValue(s.shader, s.locs[1], Vector2(x: p0.x - x0, y: p0.y - y0))
  setShaderValue(s.shader, s.locs[2], Vector2(x: p1.x - x0, y: p1.y - y0))
  setShaderValue(s.shader, s.locs[3], Vector2(x: p2.x - x0, y: p2.y - y0))
  setShaderValue(s.shader, s.locs[4], norm(color))
  s.drawQuad(quad)
  true
