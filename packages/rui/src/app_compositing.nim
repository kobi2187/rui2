## Part of app.nim (included, not imported): Painting widget textures and putting them on the screen: the root, overlays, glass, a frozen modal page.

# ============================================================================
# Render Pass
# ============================================================================

proc drawScriptingIndicator() =
  ## An orange frame and a corner label while a script is driving the app.
  ##
  ## Not decoration: a scripted window looks exactly like a hand-driven one, and
  ## somebody watching a test run needs to know which they are looking at before
  ## they reach for the mouse and fight it.
  const
    scriptColor = Color(r: 255, g: 165, b: 0, a: 200)
    indicatorText = "SCRIPTING"
  let screenWidth = getScreenWidth()
  let screenHeight = getScreenHeight()

  for inset in 0'i32 .. 3'i32:
    drawRectangleLines(inset, inset, screenWidth - inset * 2,
                       screenHeight - inset * 2, scriptColor)

  let textWidth = measureText(indicatorText, 14'i32)
  let textX = screenWidth - textWidth - 10
  drawRectangle(textX - 5, 3'i32, textWidth + 10, 20,
                Color(r: 0, g: 0, b: 0, a: 150))
  drawText(indicatorText, textX, 5'i32, 14'i32, scriptColor)

proc compositeRoot(app: App) =
  ## Widget textures hold premultiplied colour (see main_loop), so they reach
  ## the screen through the premultiplied blend too.
  let top = frozenBy(app.tree.root)
  compositingTextures:
    if top != nil and top.cachedTexture.isSome:
      # A modal is open: it carries the frozen page as its backdrop, so it is
      # the whole picture.
      drawRenderTexture(top.cachedTexture.get(), top.bounds.x - top.texturePad,
                        top.bounds.y - top.texturePad)
    elif app.tree.root != nil and app.tree.root.cachedTexture.isSome:
      drawRenderTexture(app.tree.root.cachedTexture.get(),
                        app.tree.root.bounds.x, app.tree.root.bounds.y)
    # Then the overlay layer, in the order shown, above the whole tree. A glass
    # theme's panels frost the page just drawn (backdrop.nim drawFrosted).
    if top != nil and top.cachedTexture.isSome:
      glassPage = unsafeAddr top.cachedTexture.get()
      glassPageOrigin = (top.bounds.x, top.bounds.y)
    elif app.tree.root != nil and app.tree.root.cachedTexture.isSome:
      glassPage = unsafeAddr app.tree.root.cachedTexture.get()
      glassPageOrigin = (app.tree.root.bounds.x, app.tree.root.bounds.y)
    defer: glassPage = nil
    for overlay in overlays():
      if overlay.visible and overlay.cachedTexture.isSome:
        # What it draws behind itself first (glass reads the page under it).
        if overlay.drawBehind != nil:
          overlay.drawBehind(overlay.bounds)
        drawRenderTexture(overlay.cachedTexture.get(),        # out by its effects' margin
                          overlay.bounds.x - overlay.texturePad,
                          overlay.bounds.y - overlay.texturePad)

proc beingScripted(app: App): bool =
  app.scriptManager != nil and app.scriptManager.isBeingScripted()

proc renderFrame(app: App) =
  ## Composite the root's cached texture to the screen.
  ##
  ## The whole tree is already painted by this point -- renderPass built each
  ## widget's texture and composited them upward -- so this is one blit plus
  ## whatever the window itself draws over it.
  perfTime(phScreen):
    beginDrawing()
    app.drawWindowBackground()
    app.compositeRoot()
    if app.beingScripted:
      drawScriptingIndicator()
  if app.probe != nil and app.probe.enabled:
    perfTime(phReadback):
      app.probe.capture()       # exactly what is about to be presented

  when defined(debugUI):
    drawText("FPS: " & $app.currentFPS, 10'i32, 10'i32, 16'i32, DarkGray)
    drawText("Events: " & $app.eventManager.queueLength, 10'i32, 30'i32, 16'i32, DarkGray)

  perfTime(phSwap):
    endDrawing()
