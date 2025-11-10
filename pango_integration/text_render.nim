## Text Rendering API using Pango
## Provides a simple drawText interface that uses Pango for rendering
##
## This replaces Raylib's drawText with Pango-powered rendering

import raylib
import std/[tables, hashes, options]
import ./pangowrapper

type
  TextStyle* = object
    fontSize*: int32
    color*: Color
    maxWidth*: int32  # -1 for unlimited

  CachedText = object
    texture: Texture2D  # The final rendered texture
    width: int32
    height: int32
    lastUsed: int  # frame counter

var
  textCache = initTable[Hash, CachedText]()
  frameCounter = 0
  maxCacheSize = 1000

proc hash(text: string, style: TextStyle): Hash =
  ## Hash text and style for caching
  var h: Hash = 0
  h = h !& hash(text)
  h = h !& hash(style.fontSize)
  h = h !& hash(style.color.r)
  h = h !& hash(style.color.g)
  h = h !& hash(style.color.b)
  h = h !& hash(style.maxWidth)
  !$h

proc evictOldCacheEntries() =
  ## Remove least recently used entries if cache is too large
  if textCache.len > maxCacheSize:
    var oldestKey: Hash
    var oldestFrame = frameCounter

    for key, entry in textCache.pairs:
      if entry.lastUsed < oldestFrame:
        oldestFrame = entry.lastUsed
        oldestKey = key

    # Free the texture and remove entry
    unloadTexture(textCache[oldestKey].texture)
    textCache.del(oldestKey)

proc drawText*(text: string, x, y: float32, fontSize: int32 = 20, color: Color = BLACK) =
  ## Draw text using Pango rendering
  ## Text is cached for performance

  inc frameCounter

  let style = TextStyle(
    fontSize: fontSize,
    color: color,
    maxWidth: -1  # unlimited width for simple drawText
  )

  let cacheKey = hash(text, style)

  # Check cache
  if cacheKey in textCache:
    # Use cached texture
    textCache[cacheKey].lastUsed = frameCounter
    let cached = textCache[cacheKey]
    drawTexture(cached.texture, x.int32, y.int32, color)
  else:
    # Create new layout and extract texture
    let result = initTextLayout(text, maxWidth = style.maxWidth)
    if result.isOk:
      var layout = result.get()

      # Extract the texture (we own it now)
      let texture = layout.texture
      let width = layout.width
      let height = layout.height

      # Free the layout (but not the texture - we're keeping it)
      freeTextLayout(layout)

      # Cache the texture
      evictOldCacheEntries()
      textCache[cacheKey] = CachedText(
        texture: texture,
        width: width,
        height: height,
        lastUsed: frameCounter
      )

      # Draw it
      drawTexture(texture, x.int32, y.int32, color)
    else:
      # Fallback to raylib if Pango fails
      raylib.drawText(text.cstring, x.int32, y.int32, fontSize, color)

proc drawTextEx*(text: string, x, y: float32, style: TextStyle) =
  ## Draw text with explicit style (fontSize, color, maxWidth)

  inc frameCounter

  let cacheKey = hash(text, style)

  # Check cache
  if cacheKey in textCache:
    textCache[cacheKey].lastUsed = frameCounter
    let cached = textCache[cacheKey]
    drawTexture(cached.texture, x.int32, y.int32, style.color)
  else:
    # Create new layout and extract texture
    let result = initTextLayout(text, maxWidth = style.maxWidth)
    if result.isOk:
      var layout = result.get()

      # Extract the texture
      let texture = layout.texture
      let width = layout.width
      let height = layout.height

      # Free the layout (keeping the texture)
      freeTextLayout(layout)

      # Cache the texture
      evictOldCacheEntries()
      textCache[cacheKey] = CachedText(
        texture: texture,
        width: width,
        height: height,
        lastUsed: frameCounter
      )

      # Draw it
      drawTexture(texture, x.int32, y.int32, style.color)
    else:
      # Fallback
      raylib.drawText(text.cstring, x.int32, y.int32, style.fontSize, style.color)

proc measureText*(text: string, fontSize: int32 = 20): int32 =
  ## Measure text width using Pango
  ## Returns width in pixels

  # Check cache first
  let style = TextStyle(fontSize: fontSize, color: BLACK, maxWidth: -1)
  let cacheKey = hash(text, style)

  if cacheKey in textCache:
    return textCache[cacheKey].width

  # Not cached, need to render
  let result = initTextLayout(text, maxWidth = -1)
  if result.isOk:
    var layout = result.get()
    let width = layout.width
    freeTextLayout(layout)
    return width
  else:
    # Fallback to raylib measurement
    return raylib.measureText(text.cstring, fontSize)

proc clearTextCache*() =
  ## Clear all cached text textures
  ## Call this when changing font or when memory is tight
  for entry in textCache.values:
    unloadTexture(entry.texture)
  textCache.clear()

## Usage:
##
## Instead of:
##   raylib.drawText("Hello", 100, 100, 20, BLACK)
##
## Use:
##   import pango_integration/text_render
##   drawText("Hello", 100, 100, 20, BLACK)
##
## Or with explicit style:
##   let style = TextStyle(fontSize: 24, color: RED, maxWidth: 300)
##   drawTextEx("Long text that wraps", 100, 100, style)
