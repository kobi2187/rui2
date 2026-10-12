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

import types, perf
import std/[algorithm, math, options, hashes]
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

var onDispose*: proc(widget: Widget) {.closure.}
  ## Called once with the root of every `disposeTree`, so whatever keeps its own
  ## references (the App's focus manager) can let go of anything inside it.

proc freeWidgetTexture*(widget: Widget) =
  ## Free the cached render texture if present.
  ## Resetting the Option destroys the held RenderTexture (naylib RAII).
  if widget.cachedTexture.isSome:
    # The colour attachment is a texture `createWidgetTexture` made by hand, and
    # releasing the RenderTexture frees only its framebuffer: unload the texture
    # too, or every repaint leaks one.
    rlgl.unloadTexture(widget.cachedTexture.get.texture.id)
    widget.cachedTexture = none(RenderTexture2D)

proc freeTextureTree*(widget: Widget) =
  ## Free the cached textures of `widget` and everything under it.
  for child in widget.children: freeTextureTree(child)
  freeWidgetTexture(widget)

proc disposeTree*(widget: Widget) =
  ## Release `widget` and everything under it for good: run each disposer (links
  ## forget it, the tree forgets its ids), drop the refresh hook and the cached
  ## textures. Call after `removeChild`; the widget is not usable afterwards.
  if onDispose != nil: onDispose(widget)
  proc release(w: Widget) =
    for child in w.children: release(child)
    for dispose in w.disposers: dispose()
    w.disposers.setLen(0)
    w.onRefresh = nil
    freeWidgetTexture(w)
  release(widget)

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
    # A hidden child (an inactive tab page) is never laid out by the pass, so
    # its flag would stay set and keep the whole tree "dirty" for ever.
    if child.visible and child.anyChildLayoutDirty():
      return true

  return false

proc anyChildDirty*(widget: Widget): bool =
  ## Check if any child (recursively) needs rendering. A culled subtree is off
  ## screen, so its dirt does not count: it is painted when it comes into view.
  if widget.isDirty:
    return true

  for child in widget.children:
    # A floating child is painted by the overlay layer, which asks it for
    # itself. Counting it here made a hidden one (a closed ComboBox's list) keep
    # its parent dirty for ever, since nothing clears a dirty flag on a widget
    # that is never painted: the whole window repainted at 60 fps.
    #
    # Likewise a hidden one -- an inactive tab page -- which renderPass skips:
    # it is painted when it is shown, and until then its dirt is nobody's.
    if child.visible and not child.culled and not child.floating and
       child.anyChildDirty():
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
  # Ended: what this pass measured is good only while its widget stays
  # clean. Without this, a widget marked dirty after the pass would answer
  # from this pass's memory until the next one began.
  inc layoutPassNumber

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

proc renderChildrenFirst(widget: Widget, view: Option[Rect],
                         changed: var seq[Rect]): bool =
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
    if child.floating:
      discard                          # painted on the overlay layer
    elif childView.isSome and child.visible and
       not overlapsView(child.bounds, childView.get()):
      child.culled = true
    else:
      if child.culled:
        child.culled = false
        result = true                  # back in view: re-composite it
      let wasDirty = child.isDirty and child.visible
      if renderPassIn(child, childView):
        result = true
      if wasDirty: changed.add child.damage

  if widget.hasOverlay and widget.children.len > 1:
    var sortedChildren = widget.children
    sortedChildren.sort(proc(a, b: Widget): int =
      cmp(a.zIndex, b.zIndex))          # Ascending: lower z-index renders first
    for child in sortedChildren:
      visit(child)
  else:
    for child in widget.children:
      visit(child)

proc compositeChildren(widget: Widget, originalX, originalY: float32,
                       only = none(Rect)) =
  ## Blit each child's cached texture into this widget's, in coordinates
  ## relative to this widget's top-left -- which is where bounds.x/y have been
  ## zeroed to for the duration.
  for child in widget.children:
    if not child.visible or child.culled or child.floating or
       child.cachedTexture.isNone:
      continue
    let dest = Rect(x: child.bounds.x - originalX,
                    y: child.bounds.y - originalY,
                    width: child.bounds.width, height: child.bounds.height)
    if only.isSome and not overlapsView(dest, only.get()):
      continue                         # a partial update: this one is outside it
    perfCount(pcBlits)
    perfCount(pcBlitPixels, int(dest.width * dest.height))
    if widget.childClip.isSome:
      drawRenderTexturePart(child.cachedTexture.get(), dest,
                            widget.childClip.get())
    else:
      drawRenderTexture(child.cachedTexture.get(), dest.x, dest.y)

var partialRepaint* = true
  ## Repaint only the damaged area of a widget whose children repainted, instead
  ## of clearing and re-blitting all of it. Off: every repaint is a
  ## full one (for comparing, and for finding a bug that only the partial path has).

proc paintSignature(widget: Widget): int =
  ## What a partial update must not outlive: the children (which ones, in what
  ## order, where, drawn or not) and the widget's own size and viewport.
  var h: Hash = 0
  h = h !& hash(widget.children.len)
  h = h !& hash(widget.bounds.width) !& hash(widget.bounds.height)
  if widget.childClip.isSome:
    let c = widget.childClip.get
    h = h !& hash(c.x) !& hash(c.y) !& hash(c.width) !& hash(c.height)
  for child in widget.children:
    h = h !& hash(child.id) !& hash(child.bounds.x) !& hash(child.bounds.y) !&
        hash(child.bounds.width) !& hash(child.bounds.height) !&
        hash(child.visible) !& hash(child.culled) !& hash(child.floating) !&
        hash(child.zIndex) !& hash(child.cachedTexture.isSome)
  !$h

proc textureFits(widget: Widget): bool =
  widget.cachedTexture.isSome and
    widget.cachedTexture.get.texture.width == max(1, widget.bounds.width.int32) and
    widget.cachedTexture.get.texture.height == max(1, widget.bounds.height.int32)

proc ensureTextureFor(widget: Widget) =
  ## Give `widget` a render texture of its current size, keeping the one it has
  ## when that already fits. Repainting used to free and recreate it every time:
  ## a framebuffer and a texture of the widget's whole area, per repaint, per
  ## ancestor -- megabytes a frame for a ticking label. The content is cleared
  ## before painting either way, so a reused texture shows nothing stale.
  if textureFits(widget): return
  perfTime(phTexAlloc):
    freeWidgetTexture(widget)
    widget.cachedTexture = some(createWidgetTexture(widget))
  perfCount(pcTextures)

proc unionOf(rects: seq[Rect]): Rect =
  result = rects[0]
  for r in rects:
    let x0 = min(result.x, r.x)
    let y0 = min(result.y, r.y)
    let x1 = max(result.x + result.width, r.x + r.width)
    let y1 = max(result.y + result.height, r.y + r.height)
    result = Rect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)

proc partialRegion(widget: Widget, changed: seq[Rect]): Option[Rect] =
  ## The widget-local rectangle to repaint instead of the whole texture: what
  ## the changed children damaged, a pixel wider each way (blits are rounded to
  ## whole pixels), inside the texture. none: nothing to repaint.
  let damage = unionOf(changed)
  let texW = widget.bounds.width
  let texH = widget.bounds.height
  let lx = max(0'f32, floor(damage.x - widget.bounds.x) - 1)
  let ly = max(0'f32, floor(damage.y - widget.bounds.y) - 1)
  let rx = min(texW, ceil(damage.x + damage.width - widget.bounds.x) + 1)
  let ry = min(texH, ceil(damage.y + damage.height - widget.bounds.y) + 1)
  if rx <= lx or ry <= ly: return none(Rect)
  some(Rect(x: lx, y: ly, width: rx - lx, height: ry - ly))

proc renderToTexture(widget: Widget, changed: seq[Rect], partialOk: bool) =
  ## Paint this widget and its children into its cached texture.
  ##
  ## When the widget itself did not change (`ownDirty` is false: it is dirty only
  ## because a child repainted), nothing about its children's arrangement did
  ## (`paintSig`), and its texture still fits, only the area the changed children
  ## cover is redone: scissor to it, clear it, draw the widget's own `render`
  ## (clipped to it by the GPU) and blit the children that reach into it. The
  ## blend is per pixel, so the result is identical to a full repaint, at the
  ## cost of the damaged area instead of the widget's whole.
  let sig = paintSignature(widget)
  var region = none(Rect)
  if partialRepaint and partialOk and not widget.ownDirty and changed.len > 0 and
     widget.paintSig == sig and textureFits(widget):
    region = partialRegion(widget, changed)
    if region.isNone:                    # changed children outside the widget
      widget.isDirty = false
      return
  widget.paintSig = sig
  ensureTextureFor(widget)
  perfCount(pcPainted)
  let repainted = region.get(Rect(x: 0, y: 0, width: widget.bounds.width,
                                  height: widget.bounds.height))
  perfCount(pcPixels, int(repainted.width * repainted.height))

  beginTextureMode(widget.cachedTexture.get())
  if region.isSome:
    # scissor boxes count from the bottom of the framebuffer, textures included
    rlgl.drawRenderBatchActive()
    rlgl.enableScissorTest()
    rlgl.scissor(repainted.x.int32,
                 int32(widget.cachedTexture.get.texture.height.float32 -
                       (repainted.y + repainted.height)),
                 repainted.width.int32, repainted.height.int32)
  clearBackground(Color(r: 0, g: 0, b: 0, a: 0))   # Transparent background

  # `render` draws at widget.bounds, and the texture's origin is the widget's
  # top-left, so bounds.x/y are zeroed for the duration. This is why anything a
  # widget draws outside its own bounds is silently clipped, and why a popup has
  # to grow its bounds rather than just drawing further down.
  let originalX = widget.bounds.x
  let originalY = widget.bounds.y
  widget.bounds.x = 0
  widget.bounds.y = 0
  perfTime(phRender):
    paintingIntoTexture:
      widget.render()
  widget.bounds.x = originalX
  widget.bounds.y = originalY

  perfTime(phCompose):
    compositingTextures:
      compositeChildren(widget, originalX, originalY,
        region)                       # widget-local, like each child's `dest`

  if region.isSome:
    rlgl.drawRenderBatchActive()
    rlgl.disableScissorTest()
  endTextureMode()
  widget.isDirty = false
  widget.damage = if region.isSome:
                    Rect(x: originalX + repainted.x, y: originalY + repainted.y,
                         width: repainted.width, height: repainted.height)
                  else: widget.bounds

proc renderPassIn(widget: Widget, view: Option[Rect]): bool =
  ## Render dirty widgets to textures, bottom-up.
  ##
  ## A clean widget keeps the texture it already has, which is the whole point
  ## of the cache: only what changed is repainted, and its ancestors re-composite
  ## from textures rather than re-drawing subtrees. The result says whether a
  ## widget below came back into view (see renderChildrenFirst).
  if not widget.visible:
    return false
  var changed: seq[Rect]
  let revealed = renderChildrenFirst(widget, view, changed)
  if revealed:
    widget.isDirty = true
  if changed.len > 0:
    # A child repainted, so this widget's texture is out of date whether or not
    # anyone marked it: whoever set the child dirty by hand (a script's write,
    # say) did not walk up to the root. Dirty through a child, not changed itself.
    widget.isDirtyFlag = true
  if widget.isDirty:
    renderToTexture(widget, changed, partialOk = not revealed)
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
