## Part of app.nim (included, not imported): The layout pass and the tree walks that follow it (hit-testing, the script registry).

# ============================================================================
# Layout Pass
# ============================================================================

proc rebuildHitTestTree(app: App) =
  ## Rebuild the hit-test system from the current widget tree
  ## Called after layout pass when widget bounds have been updated
  app.hitTestSystem.clear()
  if app.tree.root != nil:
    proc insertAll(widget: Widget) =
      # A floating widget is on the overlay layer, hit-tested there.
      if widget.visible and not widget.floating:
        app.hitTestSystem.insertWidget(widget)
        for child in widget.children:
          insertAll(child)
    insertAll(app.tree.root)

proc refreshLayout*(app: App) =
  ## The layout pass, and the two tree walks that depend on it.
  ##
  ## No GL: laying out, hit-testing and the scripting registry are all plain
  ## tree work. Only the render pass needs a window, which is why this is
  ## separate -- it is the whole frame minus the one part that cannot run
  ## headless.
  if app.tree.root == nil:
    return

  var layoutWillRun: bool
  let top = frozenBy(app.tree.root)
  if top != nil:
    # A modal is open: the page behind it stands still (freeze.nim). It is
    # laid out only when it has to be pictured again -- just after the modal
    # opened, after a resize or a theme change -- and then without the modal,
    # so the picture shows the page alone. The rest of the time only the
    # modal is laid out.
    if needsPagePass(top, app.tree.root):
      top.visible = false
      app.tree.root.layoutPass()
      top.visible = true
      pagePassed(top, app.tree.root)
      # Rare (an open, a resize, a theme change), and the modal may have
      # been laid out with the page, which leaves nothing dirty to say so:
      # the hit-test tree is rebuilt with the modal in it.
      layoutWillRun = true
    layoutWillRun = layoutWillRun or top.layoutDirty or top.anyChildLayoutDirty()
    top.layoutPass()
  else:
    # Does anything actually need laying out this frame? Asked before
    # layoutPass, because it clears the flags it checks.
    layoutWillRun = app.tree.root.layoutDirty or app.tree.root.anyChildLayoutDirty()
    app.tree.root.layoutPass()
  syncDecorations(cast[pointer](app), app.tree.root,
                  Rect(x: 0, y: 0, width: app.window.width.float32,
                       height: app.window.height.float32))
  for overlay in overlays():
    overlay.layoutPass()

  # Both of these walk the whole tree, and both only have anything to do when
  # bounds moved or a widget appeared -- so they are gated on layout having
  # run. They used to happen unconditionally on every frame, outside the dirty
  # guard, 60 times a second whether or not anything had changed. Measured at
  # 53.5us for a 201-widget tree, growing linearly with the tree.
  if not layoutWillRun:
    return
  app.rebuildHitTestTree()
  # Re-register so scripting selectors can find widgets by stringId. This has
  # to follow layout because a widget can be added during it.
  app.tree.registerWidgetRecursive(app.tree.root)

proc windowArea(app: App): Rect =
  Rect(x: 0, y: 0, width: getScreenWidth().float32, height: getScreenHeight().float32)

proc drawWindowBackground(app: App) =
  ## What is behind the widget tree. The window surround follows the active
  ## theme rather than a hardcoded RayWhite, so a dark theme does not leave a
  ## light border around the UI.
  when defined(ruiShaped):
    if app.shapeWanted:
      # See-through (or the backdrop, clipped away by an OS shape), then the
      # skin behind the widgets.
      clearBackground(app.shaped.clearColor)
      if app.shapeSkin.isSome:
        beginBlendMode(BlendMode.AlphaPremultiply)
        drawTexture(app.shapeSkin.get, 0, 0, White)
        endBlendMode()
    else:
      clearBackground(currentTheme.canvasColor())
      drawThemeBackground(currentTheme, app.windowArea)
  else:
    clearBackground(currentTheme.canvasColor())
    drawThemeBackground(currentTheme, app.windowArea)   # the theme's tiled picture, if any

proc takePicture(app: App, modal: Widget) =
  ## The window as it is -- background and page, without `modal` -- through
  ## the theme's backdrop look, kept as the picture `modal` draws behind it.
  ## Needs a window; without one the modal falls back to a plain tint.
  if not isWindowReady() or app.tree.root.cachedTexture.isNone:
    return
  var screen = loadRenderTexture(getScreenWidth(), getScreenHeight())
  beginTextureMode(screen)
  app.drawWindowBackground()
  compositingTextures:
    drawRenderTexture(app.tree.root.cachedTexture.get(),
                      app.tree.root.bounds.x, app.tree.root.bounds.y)
  endTextureMode()
  setBackdrop(modal, makeBackdrop(screen, currentTheme, backdropPainterFor(modal)))
  # It is drawn inside the modal's texture: repaint that with it.
  modal.isDirty = true

proc updateLayoutAndRender(app: App): bool =
  ## Lay out, then paint whatever is dirty into the widget textures. Returns
  ## whether anything was painted -- which is what decides if the frame needs
  ## presenting at all.
  if app.tree.root == nil:
    return false
  perfTime(phLayout):
    app.refreshLayout()
    app.syncFocusRings()
  # What the window shows: anything wholly outside it is not painted until it
  # scrolls into view.
  renderView = some(Rect(x: 0, y: 0, width: getScreenWidth().float32,
                         height: getScreenHeight().float32))
  let top = frozenBy(app.tree.root)
  if top != nil:
    # Frozen behind a modal: the page is painted only to be pictured, and the
    # modal is the only thing that paints itself from frame to frame.
    if needsPicture(top):
      top.visible = false
      if app.tree.root.isDirty or app.tree.root.anyChildDirty():
        app.tree.root.renderPass()
      top.visible = true
      app.takePicture(top)
      result = true
    if top.isDirty or top.anyChildDirty():
      top.renderPass()
      result = true
  elif app.tree.root.isDirty or app.tree.root.anyChildDirty():
    app.tree.root.renderPass()
    result = true
  for overlay in overlays():
    if overlay.isDirty or overlay.anyChildDirty():
      overlay.renderPass()
      result = true
  # Showing or hiding an overlay repaints no texture, but the screen changes.
  if overlayVersion() != app.overlaysSeen:
    app.overlaysSeen = overlayVersion()
    result = true
  app.tree.anyDirty = false
