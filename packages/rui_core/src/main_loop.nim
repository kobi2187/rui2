## Main Loop - Two-Pass Rendering
##
## Pass 1: Layout - Calculate positions/sizes, mark dirty if changed
## Pass 2: Render - Draw dirty widgets to textures, use cache for clean ones
##
## Texture Caching:
## - Each widget renders to its own RenderTexture2D
## - Children are rendered first (bottom-up)
## - Parent composites children's textures into its own
## - Cached Texture2D is reused when widget is clean

import types
import std/[algorithm, math, options]
import raylib
import rlgl
from rlgl import setBlendFactorsSeparate, BlendFactor, BlendFuncOrEq


# ============================================================================
# Texture Management Helpers
# ============================================================================


proc createWidgetTexture*(widget: Widget): RenderTexture2D =
  ## Create a render texture for the widget
  ## Size is based on widget's bounds
  let width = max(1, widget.bounds.width.int32)
  let height = max(1, widget.bounds.height.int32)
  # Colour only. raylib's own loadRenderTexture also attaches a 32-bit depth
  # renderbuffer, which a 2D widget never reads: about as much memory again,
  # per widget, for nothing (10,000 widgets held 341 MB of colour alone).
  let fbo = rlgl.loadFramebuffer()
  if fbo == 0:
    return loadRenderTexture(width, height)    # let raylib report it
  rlgl.enableFramebuffer(fbo)
  let tex = rlgl.loadTexture(nil, width, height,
                             int32(PixelFormat.UncompressedR8g8b8a8), 1)
  rlgl.framebufferAttach(fbo, tex, FramebufferAttachType.ColorChannel0,
                         FramebufferAttachTextureType.Texture2d, 0)
  rlgl.disableFramebuffer()
  result = RenderTexture2D(
    id: fbo,
    texture: Texture(id: tex, width: width, height: height, mipmaps: 1,
                     format: PixelFormat.UncompressedR8g8b8a8))

proc freeWidgetTexture*(widget: Widget) =
  ## Free the cached render texture if present.
  ## Resetting the Option destroys the held RenderTexture (naylib RAII).
  if widget.cachedTexture.isSome:
    widget.cachedTexture = none(RenderTexture2D)

# ----------------------------------------------------------------------------
# Blending
#
# Widget textures start transparent and are composited onto their parent. With
# ordinary alpha blending that is wrong twice over: drawing a 35%-opaque shape
# into a transparent texture stores alpha 0.35 * 0.35, and compositing then
# multiplies the colour by alpha again. Anything translucent on a widget with no
# opaque background of its own came out a fraction of its intended strength --
# a standalone ScrollBar's thumb was all but invisible.
#
# So textures hold premultiplied colour. Drawing into one blends colour as
# usual but alpha additively-over (`paintingIntoTexture`); drawing one onto
# anything uses raylib's premultiplied mode (`compositingTextures`). Opaque
# content comes out exactly as before.
# ----------------------------------------------------------------------------

template paintingIntoTexture*(body: untyped) =
  setBlendFactorsSeparate(SrcAlpha, OneMinusSrcAlpha, One, OneMinusSrcAlpha,
                          FuncAdd, FuncAdd)
  beginBlendMode(BlendMode.CustomSeparate)
  body
  endBlendMode()

template compositingTextures*(body: untyped) =
  beginBlendMode(BlendMode.AlphaPremultiply)
  body
  endBlendMode()

proc drawRenderTexture*(tex: RenderTexture2D, x, y: float32) =
  ## Blit a cached render target with its top-left corner at (x, y).
  ##
  ## OpenGL stores framebuffer contents bottom-up, so a render texture drawn
  ## with a plain drawTexture() comes out vertically mirrored. A negative source
  ## height flips it back. Without this the whole tree composited upside down:
  ## glyphs looked upright (two flips cancel) but every widget appeared mirrored
  ## about the window's vertical centre, so a top-aligned stack rendered from the
  ## bottom up in reverse order.
  ##
  ## The position is snapped to whole pixels: layout can leave a widget on a
  ## half pixel (a centred child, say), and a texture blitted there is
  ## resampled, which smears its text into a doubled ghost.
  let w = tex.texture.width.float32
  let h = tex.texture.height.float32
  drawTexture(tex.texture,
              Rectangle(x: 0, y: 0, width: w, height: -h),
              Vector2(x: round(x), y: round(y)),
              White)

proc intersect*(a, b: Rect): Rect =
  ## The overlapping part of two rectangles, or a zero-sized rect when they do
  ## not overlap. Width and height are floored at 0 rather than going negative,
  ## so `result.width <= 0` is the "nothing to draw" test.
  let x = max(a.x, b.x)
  let y = max(a.y, b.y)
  let right = min(a.x + a.width, b.x + b.width)
  let bottom = min(a.y + a.height, b.y + b.height)
  Rect(x: x, y: y, width: max(0.0'f32, right - x), height: max(0.0'f32, bottom - y))

proc drawRenderTexturePart*(tex: RenderTexture2D, dest: Rect, clip: Rect) =
  ## Blit the part of a cached render target that falls inside `clip`.
  ##
  ## `dest` is where the whole texture would go; `clip` is in the same
  ## coordinate space. Nothing is drawn when they do not overlap.
  ##
  ## This exists because raylib's BeginScissorMode is unusable here: it computes
  ## its GL rectangle as `GetScreenHeight() - (y + height)`, using the *screen*
  ## height, so inside beginTextureMode -- where the bound framebuffer is a
  ## widget's own render texture -- it clips the wrong region unless the texture
  ## happens to be screen-sized. Clipping by source rectangle is arithmetic, not
  ## GL state, and is correct at any texture size.
  ##
  ## Like drawRenderTexture, the texture lands on whole pixels, and so does the
  ## clip, so the source rectangle is whole texels and nothing is resampled.
  let dest = Rect(x: round(dest.x), y: round(dest.y),
                  width: tex.texture.width.float32,
                  height: tex.texture.height.float32)
  let clipL = round(clip.x)
  let clipT = round(clip.y)
  let clip = Rect(x: clipL, y: clipT,
                  width: round(clip.x + clip.width) - clipL,
                  height: round(clip.y + clip.height) - clipT)
  let visible = intersect(dest, clip)
  if visible.width <= 0 or visible.height <= 0:
    return

  let texH = tex.texture.height.float32

  # The source rectangle, in upright coordinates: how far into the texture the
  # visible part starts.
  let sx = visible.x - dest.x
  let uy = visible.y - dest.y

  # Then flipped. With a negative source height raylib samples stored rows
  # [sy, sy + sh] and turns them over, and the framebuffer stores them
  # bottom-up -- so the upright rows [uy, uy + sh] live at sy = texH - uy - sh.
  let sy = texH - uy - visible.height

  drawTexture(tex.texture,
              Rectangle(x: sx, y: sy, width: visible.width, height: -visible.height),
              Rectangle(x: visible.x, y: visible.y,
                        width: visible.width, height: visible.height),
              Vector2(x: 0, y: 0), 0.0, White)

proc compositeChildTexture*(child: Widget, offsetX, offsetY: float32) =
  ## Draw a child's cached texture at its position relative to parent
  ## Called during parent rendering
  if child.cachedTexture.isSome and child.visible:
    # Extract the Texture2D from RenderTexture2D for drawing (borrow, no copy)
    let relX = child.bounds.x - offsetX
    let relY = child.bounds.y - offsetY
    drawRenderTexture(child.cachedTexture.get(), relX, relY)

# ============================================================================
# Dirty Tracking Helpers
# ============================================================================

proc anyChildLayoutDirty*(widget: Widget): bool =
  ## Check if any child (recursively) needs layout
  if widget.layoutDirty:
    return true

  for child in widget.children:
    if child.anyChildLayoutDirty():
      return true

  return false

proc anyChildDirty*(widget: Widget): bool =
  ## Check if any child (recursively) needs rendering. A culled subtree is off
  ## screen, so its dirt does not count: it is painted when it comes into view.
  if widget.isDirty:
    return true

  for child in widget.children:
    if not child.culled and child.anyChildDirty():
      return true

  return false

# ============================================================================
# Pass 1: Layout
# ============================================================================

proc invalidateForBoundsChange(widget: Widget) =
  ## Invalidate precisely what a change of bounds actually affected.
  ##
  ## A widget renders into its own texture with its origin forced to (0, 0), so
  ## that texture's content depends on the widget's SIZE and never on where it
  ## sits. Position matters only to the parent, which composites children at
  ## relative offsets. The two cases are therefore different:
  ##
  ##   resized  -> re-render this widget, and re-composite the parent
  ##   moved    -> keep this widget's texture; only re-composite the parent
  ##
  ## The comparison is against `previousBounds` -- the bounds this widget had
  ## when the last pass finished -- rather than against a snapshot taken around
  ## the layout call, because that call does not always run. A parent's layout()
  ## moves and resizes its children directly, without their own layoutDirty ever
  ## being set, so a child's change would otherwise never be noticed by anything.
  ##
  ## The old rule was `bounds != oldBounds -> isDirty`, inside the layoutDirty
  ## block. It re-rendered a whole subtree that had merely slid sideways, and it
  ## never marked the parent at all -- so a child moved by its parent's layout
  ## left the parent compositing it at the old offset.
  if widget.bounds == widget.previousBounds:
    return
  let resized = widget.bounds.width != widget.previousBounds.width or
                widget.bounds.height != widget.previousBounds.height
  if resized:
    widget.isDirty = true
  if widget.parent != nil:
    widget.parent.isDirty = true
  widget.previousBounds = widget.bounds

proc propagateLayoutDirty*(widget: Widget): bool {.discardable.} =
  ## Before a pass: a widget whose subtree has a layout-dirty widget is
  ## layout-dirty itself, because its children's sizes may have changed and
  ## it has to place them again. Returns whether `widget` ended up dirty.
  ##
  ## Bound values are pulled in here (`onRefresh`), on the way down, so every
  ## measurement in the pass sees the new content.
  if widget.layoutDirty and widget.onRefresh != nil:
    widget.onRefresh()
  for child in widget.children:
    if child.propagateLayoutDirty():
      widget.layoutDirty = true
  widget.layoutDirty

proc layoutWalk(widget: Widget) =
  if widget.layoutDirty:
    # Call layout() via dynamic dispatch
    # - Composites have overridden implementation (generated by defineWidget)
    # - Primitives use base Widget version (no-op)
    widget.layout()
    widget.layoutDirty = false

  widget.invalidateForBoundsChange()
  #
  # A widget renders into its own texture with its origin forced to (0, 0), so
  # that texture's content depends on the widget's SIZE and never on where it
  # sits. Position matters only to the parent, which composites children at
  # relative offsets. The two cases are therefore different:
  #
  #   resized  -> re-render this widget, and re-composite the parent
  #   moved    -> keep this widget's texture; only re-composite the parent
  #
  # The comparison is against `previousBounds` -- the bounds this widget had
  # when the last pass finished -- rather than against a local snapshot taken
  # inside the block above, because the block above does not always run. A
  # parent's layout() moves and resizes its children directly, without their
  # own layoutDirty ever being set, so a child's change would otherwise never
  # be noticed by anything.
  #
  # The old rule was `bounds != oldBounds -> isDirty`, inside that block. It
  # re-rendered a whole subtree that had merely slid sideways, and it never
  # marked the parent at all -- so a child moved by its parent's layout left
  # the parent compositing it at the old offset.
  # Recurse to children (both primitives and composites can have children)
  for child in widget.children:
    child.layoutWalk()

proc layoutPass*(widget: Widget) =
  ## Lay out every layout-dirty widget under `widget`, parents before
  ## children. A parent arranges its children with `arrange`, which lays a
  ## child out and marks it clean, so the walk does not lay it out twice.
  ## If a widget's bounds change it is marked for re-rendering.
  inc layoutPassNumber
  widget.propagateLayoutDirty()
  widget.layoutWalk()

# ============================================================================
# Pass 2: Render
# ============================================================================

var renderView*: Option[Rect]
  ## What is on screen, in the same (absolute) space as widget bounds. The App
  ## sets it each frame. While it is set, widgets wholly outside it -- and
  ## outside every scroll area's viewport on the way down -- are not painted.
  ## `none` paints everything, which is what tests and benchmarks of the full
  ## pipeline want.

proc overlapsView*(bounds, view: Rect): bool =
  ## Whether `bounds` touches `view` at all. Edges that merely meet do not.
  bounds.x < view.x + view.width and bounds.x + bounds.width > view.x and
  bounds.y < view.y + view.height and bounds.y + bounds.height > view.y

proc renderPassIn(widget: Widget, view: Option[Rect]): bool

proc renderChildrenFirst(widget: Widget, view: Option[Rect]): bool =
  ## Bottom-up: a parent composites its children's cached textures, so those
  ## have to exist before it paints. Returns whether any descendant came back
  ## into view, in which case this widget has to composite again even though
  ## nothing in it changed.
  ##
  ## An overlay parent sorts by zIndex, which is how a MenuBar's dropdown paints
  ## over the controls that follow it in the child list. Only when it says so --
  ## sorting every container every frame would cost more than it buys.
  ##
  ## Culling: what the children can show is `view` cut down by this widget's
  ## own viewport (a ScrollView's `childClip`, which is widget-local, so it is
  ## moved to absolute space here).
  var childView = view
  if view.isSome and widget.childClip.isSome:
    let c = widget.childClip.get()
    childView = some(intersect(view.get(),
      Rect(x: widget.bounds.x + c.x, y: widget.bounds.y + c.y,
           width: c.width, height: c.height)))

  template visit(child: Widget) =
    if childView.isSome and child.visible and
       not overlapsView(child.bounds, childView.get()):
      child.culled = true
    else:
      if child.culled:
        child.culled = false
        result = true                  # back in view: re-composite it
      if renderPassIn(child, childView):
        result = true

  if widget.hasOverlay and widget.children.len > 1:
    var sortedChildren = widget.children
    sortedChildren.sort(proc(a, b: Widget): int =
      cmp(a.zIndex, b.zIndex))          # Ascending: lower z-index renders first
    for child in sortedChildren:
      visit(child)
  else:
    for child in widget.children:
      visit(child)

proc compositeChildren(widget: Widget, originalX, originalY: float32) =
  ## Blit each child's cached texture into this widget's, in coordinates
  ## relative to this widget's top-left -- which is where bounds.x/y have been
  ## zeroed to for the duration.
  for child in widget.children:
    if not child.visible or child.culled or child.cachedTexture.isNone:
      continue
    let dest = Rect(x: child.bounds.x - originalX,
                    y: child.bounds.y - originalY,
                    width: child.bounds.width, height: child.bounds.height)
    if widget.childClip.isSome:
      drawRenderTexturePart(child.cachedTexture.get(), dest,
                            widget.childClip.get())
    else:
      drawRenderTexture(child.cachedTexture.get(), dest.x, dest.y)

proc renderToTexture(widget: Widget) =
  ## Paint this widget and its children into a fresh cached texture.
  freeWidgetTexture(widget)
  let renderTex = createWidgetTexture(widget)

  beginTextureMode(renderTex)
  clearBackground(Color(r: 0, g: 0, b: 0, a: 0))   # Transparent background

  # `render` draws at widget.bounds, and the texture's origin is the widget's
  # top-left, so bounds.x/y are zeroed for the duration. This is why anything a
  # widget draws outside its own bounds is silently clipped, and why a popup has
  # to grow its bounds rather than just drawing further down.
  let originalX = widget.bounds.x
  let originalY = widget.bounds.y
  widget.bounds.x = 0
  widget.bounds.y = 0
  paintingIntoTexture:
    widget.render()
  widget.bounds.x = originalX
  widget.bounds.y = originalY

  compositingTextures:
    compositeChildren(widget, originalX, originalY)

  endTextureMode()
  widget.cachedTexture = some(renderTex)
  widget.isDirty = false

proc renderPassIn(widget: Widget, view: Option[Rect]): bool =
  ## Render dirty widgets to textures, bottom-up.
  ##
  ## A clean widget keeps the texture it already has, which is the whole point
  ## of the cache: only what changed is repainted, and its ancestors re-composite
  ## from textures rather than re-drawing subtrees. The result says whether a
  ## widget below came back into view (see renderChildrenFirst).
  if not widget.visible:
    return false
  let revealed = renderChildrenFirst(widget, view)
  if revealed:
    widget.isDirty = true
  if widget.isDirty:
    renderToTexture(widget)
  revealed

proc renderPass*(widget: Widget) =
  ## Render dirty widgets to textures, bottom-up, skipping what is off screen
  ## when `renderView` is set. The root is never culled.
  discard renderPassIn(widget, renderView)

# ============================================================================
# Main Frame Function
# ============================================================================

proc runFrame*(rootWidget: Widget) =
  ## Execute one frame:
  ## 1. Layout pass (if needed)
  ## 2. Render pass (if needed)
  ##
  ## Call this from your main loop after handling input.

  # Pass 1: Layout
  if rootWidget.layoutDirty or rootWidget.anyChildLayoutDirty():
    rootWidget.layoutPass()

  # Pass 2: Render
  if rootWidget.isDirty or rootWidget.anyChildDirty():
    rootWidget.renderPass()

# ============================================================================
# Usage Example
# ============================================================================

when false:
  # In your main loop:
  proc mainLoop() =
    let rootWidget = createUI()

    while not windowShouldClose():
      # 1. Handle input
      let event = pollEvent()
      if event.isSome:
        rootWidget.handleInput(event.get())

      # 2. Update layout & render (two passes)
      rootWidget.runFrame()

      # 3. Composite to screen
      # (For now, render() draws directly. Later, composite cached textures)

      # 4. Present
      swapBuffers()
