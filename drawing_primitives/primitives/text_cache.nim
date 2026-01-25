## Text Rendering Cache
##
## Caches text measurements and rendered textures for performance.
## Uses composite keys (all parameters) to ensure cache correctness.

import raylib
import std/[tables, hashes, strformat]
import std/times as stdtimes  # Avoid conflict with raylib.getTime
import ../../core/types
import text  # For TextStyle, TextMetrics, TextAlign

export text

# ============================================================================
# Cache Key Types
# ============================================================================

type
  MeasurementKey* = object
    ## Cache key for text measurements
    text*: string
    fontFamily*: string
    fontSize*: float32
    bold*: bool
    italic*: bool

  RenderKey* = object
    ## Cache key for rendered text textures
    text*: string
    fontFamily*: string
    fontSize*: float32
    color*: raylib.Color
    bold*: bool
    italic*: bool
    underline*: bool
    align*: TextAlign
    maxWidth*: float32  # For wrapping

  TextureCacheEntry* = object
    texture*: raylib.Texture2D
    lastUsed*: stdtimes.Time
    memoryBytes*: int

# ============================================================================
# Hash Functions (Composite Keys)
# ============================================================================

proc hash*(key: MeasurementKey): Hash =
  ## Combine hashes of all measurement parameters
  var h: Hash = 0
  h = h !& hash(key.text)
  h = h !& hash(key.fontFamily)
  h = h !& hash(key.fontSize)
  h = h !& hash(key.bold)
  h = h !& hash(key.italic)
  result = !$h

proc hash*(key: RenderKey): Hash =
  ## Combine hashes of all render parameters
  var h: Hash = 0
  h = h !& hash(key.text)
  h = h !& hash(key.fontFamily)
  h = h !& hash(key.fontSize)
  h = h !& hash(key.color.r)
  h = h !& hash(key.color.g)
  h = h !& hash(key.color.b)
  h = h !& hash(key.color.a)
  h = h !& hash(key.bold)
  h = h !& hash(key.italic)
  h = h !& hash(key.underline)
  h = h !& hash(key.align)
  h = h !& hash(key.maxWidth)
  result = !$h

# ============================================================================
# Cache Storage
# ============================================================================

type
  TextCache* = object
    measurements*: Table[MeasurementKey, TextMetrics]
    textures*: Table[RenderKey, TextureCacheEntry]
    maxTextureMemoryMB*: int
    maxEntries*: int
    currentMemoryBytes*: int
    measurementHits*: int
    measurementMisses*: int
    textureHits*: int
    textureMisses*: int

var globalTextCache* = TextCache(
  measurements: initTable[MeasurementKey, TextMetrics](),
  textures: initTable[RenderKey, TextureCacheEntry](),
  maxTextureMemoryMB: 100,
  maxEntries: 1000,
  currentMemoryBytes: 0,
  measurementHits: 0,
  measurementMisses: 0,
  textureHits: 0,
  textureMisses: 0
)

# ============================================================================
# Helper: Create Keys from TextStyle
# ============================================================================

proc toMeasurementKey*(text: string, style: TextStyle): MeasurementKey =
  ## Create measurement cache key from text and style
  MeasurementKey(
    text: text,
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    bold: style.bold,
    italic: style.italic
  )

proc toRenderKey*(text: string, style: TextStyle, align: TextAlign, maxWidth: float32 = -1): RenderKey =
  ## Create render cache key from all parameters
  RenderKey(
    text: text,
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    color: style.color,
    bold: style.bold,
    italic: style.italic,
    underline: style.underline,
    align: align,
    maxWidth: maxWidth
  )

# ============================================================================
# Cache Management - Forth Style: Small, Composable Functions
# ============================================================================

proc hasTextures*(cache: TextCache): bool =
  ## Check if cache has any textures
  cache.textures.len > 0

proc findOldestEntry*(cache: TextCache): tuple[key: RenderKey, found: bool] =
  ## Find the least recently used entry
  if not cache.hasTextures:
    return (RenderKey(), false)

  var oldestKey: RenderKey
  var oldestTime = stdtimes.getTime()
  var found = false

  for key, entry in cache.textures.pairs:
    if not found or entry.lastUsed < oldestTime:
      oldestKey = key
      oldestTime = entry.lastUsed
      found = true

  (oldestKey, found)

proc freeTexture*(texture: raylib.Texture2D) =
  ## Free a texture using the real raylib function
  when defined(useGraphics):
    {.emit: "UnloadTexture(`texture`);".}

proc unloadTexture*(cache: var TextCache, entry: TextureCacheEntry) =
  ## Unload texture from memory
  when defined(useGraphics):
    freeTexture(entry.texture)
  cache.currentMemoryBytes -= entry.memoryBytes

proc removeEntry*(cache: var TextCache, key: RenderKey) =
  ## Remove entry from cache
  let entry = cache.textures[key]
  cache.unloadTexture(entry)
  cache.textures.del(key)

proc evictLRU*(cache: var TextCache) =
  ## Evict least recently used texture entry
  let (key, found) = cache.findOldestEntry()
  if found:
    cache.removeEntry(key)

proc maxCacheBytes*(cache: TextCache): int =
  ## Calculate maximum cache size in bytes
  cache.maxTextureMemoryMB * 1024 * 1024

proc wouldExceedMemory*(cache: TextCache, newBytes: int): bool =
  ## Check if adding newBytes would exceed memory limit
  cache.currentMemoryBytes + newBytes > cache.maxCacheBytes()

proc atMaxEntries*(cache: TextCache): bool =
  ## Check if cache is at maximum entry count
  cache.textures.len >= cache.maxEntries

proc evictUntilSpace*(cache: var TextCache, newBytes: int) =
  ## Evict until we have space for newBytes
  while cache.wouldExceedMemory(newBytes) and cache.hasTextures:
    cache.evictLRU()

proc evictUntilBelowMax*(cache: var TextCache) =
  ## Evict until below maximum entry count
  while cache.atMaxEntries:
    cache.evictLRU()

proc evictIfNeeded*(cache: var TextCache, newEntryBytes: int) =
  ## Evict entries if needed to make space
  cache.evictUntilSpace(newEntryBytes)
  cache.evictUntilBelowMax()

proc unloadAllTextures*(cache: var TextCache) =
  ## Unload all cached textures
  when defined(useGraphics):
    for entry in cache.textures.values:
      freeTexture(entry.texture)

proc resetCounters*(cache: var TextCache) =
  ## Reset all cache counters
  cache.currentMemoryBytes = 0

proc clearAllEntries*(cache: var TextCache) =
  ## Clear all cache tables
  cache.measurements.clear()
  cache.textures.clear()

proc clearCache*(cache: var TextCache) =
  ## Clear entire cache and free resources
  cache.unloadAllTextures()
  cache.clearAllEntries()
  cache.resetCounters()

# ============================================================================
# Cached Measurement - Forth Style
# ============================================================================

proc hasMeasurement*(cache: TextCache, key: MeasurementKey): bool =
  ## Check if measurement is cached
  key in cache.measurements

proc recordHit*(cache: var TextCache) =
  ## Record cache hit
  cache.measurementHits += 1

proc recordMiss*(cache: var TextCache) =
  ## Record cache miss
  cache.measurementMisses += 1

proc getCachedMeasurement*(cache: TextCache, key: MeasurementKey): TextMetrics =
  ## Retrieve cached measurement
  cache.measurements[key]

proc storeMeasurement*(cache: var TextCache, key: MeasurementKey, metrics: TextMetrics) =
  ## Store measurement in cache
  cache.measurements[key] = metrics

proc measurementCacheFull*(cache: TextCache): bool =
  ## Check if measurement cache exceeds max
  cache.measurements.len > cache.maxEntries

proc collectOldMeasurements*(cache: TextCache): seq[MeasurementKey] =
  ## Collect oldest half of measurements for removal
  result = @[]
  let halfSize = cache.measurements.len div 2
  var count = 0
  for k in cache.measurements.keys:
    result.add(k)
    count += 1
    if count > halfSize:
      break

proc removeOldMeasurements*(cache: var TextCache, keys: seq[MeasurementKey]) =
  ## Remove measurements by key
  for k in keys:
    cache.measurements.del(k)

proc pruneMeasurements*(cache: var TextCache) =
  ## Remove oldest measurements if cache is full
  if cache.measurementCacheFull():
    let toRemove = cache.collectOldMeasurements()
    cache.removeOldMeasurements(toRemove)

proc computeMeasurement*(text: string, style: TextStyle): TextMetrics =
  ## Compute text measurement (delegates to measureText)
  measureText(text, style)

proc measureTextCached*(text: string, style: TextStyle, cache: var TextCache): TextMetrics =
  ## Measure text with caching
  let key = toMeasurementKey(text, style)

  # Check cache
  if cache.hasMeasurement(key):
    cache.recordHit()
    return cache.getCachedMeasurement(key)

  # Cache miss
  cache.recordMiss()

  # Compute and cache
  let metrics = computeMeasurement(text, style)
  cache.storeMeasurement(key, metrics)
  cache.pruneMeasurements()

  metrics

proc measureTextCached*(text: string, style: TextStyle): TextMetrics =
  ## Convenience wrapper using global cache
  measureTextCached(text, style, globalTextCache)

# ============================================================================
# Cached Texture Rendering (for Pango backend)
# ============================================================================

proc getCachedTexture*(key: RenderKey, cache: var TextCache): Option[raylib.Texture2D] =
  ## Retrieve cached texture if available
  if key in cache.textures:
    cache.textureHits += 1
    cache.textures[key].lastUsed = stdtimes.getTime()
    return some(cache.textures[key].texture)

  cache.textureMisses += 1
  return none(raylib.Texture2D)

proc cacheTexture*(key: RenderKey, texture: raylib.Texture2D, cache: var TextCache) =
  ## Cache a rendered texture
  when defined(useGraphics):
    let memoryBytes = texture.width * texture.height * 4  # RGBA

    # Evict if needed
    cache.evictIfNeeded(memoryBytes)

    # Add to cache
    cache.textures[key] = TextureCacheEntry(
      texture: texture,
      lastUsed: stdtimes.getTime(),
      memoryBytes: memoryBytes
    )
    cache.currentMemoryBytes += memoryBytes

# ============================================================================
# Cache Statistics
# ============================================================================

proc getCacheStats*(cache: TextCache): tuple[
  measurementSize: int,
  measurementHitRate: float,
  textureSize: int,
  textureHitRate: float,
  memoryMB: float
] =
  ## Get cache performance statistics
  let totalMeasurements = cache.measurementHits + cache.measurementMisses
  let totalTextures = cache.textureHits + cache.textureMisses

  result.measurementSize = cache.measurements.len
  result.measurementHitRate = if totalMeasurements > 0:
    cache.measurementHits.float / totalMeasurements.float
  else:
    0.0

  result.textureSize = cache.textures.len
  result.textureHitRate = if totalTextures > 0:
    cache.textureHits.float / totalTextures.float
  else:
    0.0

  result.memoryMB = cache.currentMemoryBytes.float / (1024 * 1024)

proc printCacheStats*(cache: TextCache) =
  ## Print cache statistics for debugging
  let stats = getCacheStats(cache)
  echo "=== Text Cache Statistics ==="
  echo &"Measurements: {stats.measurementSize} entries"
  echo &"  Hit rate: {stats.measurementHitRate * 100:.1f}%"
  echo &"Textures: {stats.textureSize} entries"
  echo &"  Hit rate: {stats.textureHitRate * 100:.1f}%"
  echo &"  Memory: {stats.memoryMB:.2f} MB"

# ============================================================================
# Usage Example
# ============================================================================

when isMainModule:
  import std/[strformat]

  # Create test data
  let style1 = TextStyle(
    fontFamily: "Arial",
    fontSize: 16,
    color: raylib.Color(r: 255, g: 255, b: 255, a: 255),
    bold: false,
    italic: false,
    underline: false
  )

  let style2 = TextStyle(
    fontFamily: "Arial",
    fontSize: 16,
    color: raylib.Color(r: 255, g: 0, b: 0, a: 255),  # Different color!
    bold: false,
    italic: false,
    underline: false
  )

  # Test measurement caching
  echo "Testing measurement cache..."
  let m1 = measureTextCached("Hello", style1, globalTextCache)
  let m2 = measureTextCached("Hello", style1, globalTextCache)  # Cache hit
  let m3 = measureTextCached("Hello", style2, globalTextCache)  # Cache miss (different style)
  let m4 = measureTextCached("World", style1, globalTextCache)  # Cache miss (different text)

  # Test key hashing
  let key1 = toMeasurementKey("Hello", style1)
  let key2 = toMeasurementKey("Hello", style1)
  let key3 = toMeasurementKey("Hello", style2)

  echo &"key1 hash: {hash(key1)}"
  echo &"key2 hash: {hash(key2)}"
  echo &"key3 hash: {hash(key3)}"
  echo &"key1 == key2: {key1 == key2}"
  echo &"key1 == key3: {key1 == key3}"

  globalTextCache.printCacheStats()

  echo "\n✓ Text cache implementation complete!"
