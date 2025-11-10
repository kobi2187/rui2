# Forth-Style Refactoring Guide

## Philosophy

Code should be composed of small, obvious, readable, and composable functions. Each function does ONE thing and does it clearly.

Inspired by Forth's philosophy:
- **Small words** - Functions should be 3-10 lines
- **Obvious names** - Names describe exactly what they do
- **Composable** - Functions build on other functions
- **Readable flow** - Code reads like English

## Before and After Example

### Before: Complex Function

```nim
proc evictLRU*(cache: var TextCache) =
  ## Evict least recently used texture entries when cache is full
  if cache.textures.len == 0:
    return

  var oldestKey: RenderKey
  var oldestTime = stdtimes.getTime()
  var foundAny = false

  for key, entry in cache.textures.pairs:
    if not foundAny or entry.lastUsed < oldestTime:
      oldestKey = key
      oldestTime = entry.lastUsed
      foundAny = true

  if foundAny:
    let entry = cache.textures[oldestKey]
    when defined(useGraphics):
      UnloadTexture(entry.texture)
    cache.currentMemoryBytes -= entry.memoryBytes
    cache.textures.del(oldestKey)
```

### After: Forth-Style Functions

```nim
# Predicates - Answer questions
proc hasTextures*(cache: TextCache): bool =
  cache.textures.len > 0

# Queries - Find information
proc findOldestEntry*(cache: TextCache): tuple[key: RenderKey, found: bool] =
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

# Actions - Do specific things
proc unloadTexture*(cache: var TextCache, entry: TextureCacheEntry) =
  when defined(useGraphics):
    UnloadTexture(entry.texture)
  cache.currentMemoryBytes -= entry.memoryBytes

proc removeEntry*(cache: var TextCache, key: RenderKey) =
  let entry = cache.textures[key]
  cache.unloadTexture(entry)
  cache.textures.del(key)

# Composition - Build from smaller parts
proc evictLRU*(cache: var TextCache) =
  let (key, found) = cache.findOldestEntry()
  if found:
    cache.removeEntry(key)
```

## Refactoring Principles

### 1. **Predicate Functions** - Answer Yes/No

```nim
# Good: Predicate functions return bool
proc hasTextures*(cache: TextCache): bool
proc isEmpty*(cache: TextCache): bool
proc isFull*(cache: TextCache): bool
proc wouldExceedMemory*(cache: TextCache, bytes: int): bool

# Usage reads naturally
if cache.hasTextures and cache.wouldExceedMemory(newBytes):
  cache.evict()
```

### 2. **Query Functions** - Find Information

```nim
# Good: Query functions return data
proc findOldestEntry*(cache: TextCache): tuple[key: Key, found: bool]
proc getCachedValue*(cache: TextCache, key: Key): Value
proc calculateSize*(cache: TextCache): int

# Clear what they return
let (key, found) = cache.findOldestEntry()
```

### 3. **Action Functions** - Do One Thing

```nim
# Good: Action functions do one specific thing
proc recordHit*(cache: var TextCache)
proc recordMiss*(cache: var TextCache)
proc storeMeasurement*(cache: var TextCache, key: Key, value: Value)
proc removeEntry*(cache: var TextCache, key: Key)

# Each does exactly what it says
cache.recordHit()
cache.storeMeasurement(key, value)
```

### 4. **Composition Functions** - Build from Parts

```nim
# Good: High-level functions compose lower-level ones
proc measureTextCached*(text: string, style: TextStyle, cache: var TextCache): TextMetrics =
  let key = toMeasurementKey(text, style)

  if cache.hasMeasurement(key):
    cache.recordHit()
    return cache.getCachedMeasurement(key)

  cache.recordMiss()
  let metrics = computeMeasurement(text, style)
  cache.storeMeasurement(key, metrics)
  cache.pruneMeasurements()

  metrics
```

Reads like: "Check cache, if hit return it, else compute, store, prune, return"

### 5. **Factor Out Calculations**

```nim
# Before: Calculation buried in function
proc evictIfNeeded*(cache: var TextCache, newBytes: int) =
  let maxBytes = cache.maxTextureMemoryMB * 1024 * 1024
  while cache.currentMemoryBytes + newBytes > maxBytes:
    cache.evictLRU()

# After: Calculation is a function
proc maxCacheBytes*(cache: TextCache): int =
  cache.maxTextureMemoryMB * 1024 * 1024

proc wouldExceedMemory*(cache: TextCache, newBytes: int): bool =
  cache.currentMemoryBytes + newBytes > cache.maxCacheBytes()

proc evictIfNeeded*(cache: var TextCache, newBytes: int) =
  while cache.wouldExceedMemory(newBytes):
    cache.evictLRU()
```

### 6. **Factor Out Conditions**

```nim
# Before: Complex condition
if cache.measurements.len > cache.maxEntries:
  # evict logic

# After: Condition is a predicate
proc measurementCacheFull*(cache: TextCache): bool =
  cache.measurements.len > cache.maxEntries

if cache.measurementCacheFull():
  # evict logic
```

### 7. **Factor Out Loops**

```nim
# Before: Loop logic inline
var toRemove: seq[Key] = @[]
var count = 0
for k in cache.measurements.keys:
  toRemove.add(k)
  count += 1
  if count > cache.measurements.len div 2:
    break
for k in toRemove:
  cache.measurements.del(k)

# After: Loop is a function
proc collectOldMeasurements*(cache: TextCache): seq[Key] =
  result = @[]
  let halfSize = cache.measurements.len div 2
  var count = 0
  for k in cache.measurements.keys:
    result.add(k)
    count += 1
    if count > halfSize:
      break

proc removeOldMeasurements*(cache: var TextCache, keys: seq[Key]) =
  for k in keys:
    cache.measurements.del(k)

# Usage
let toRemove = cache.collectOldMeasurements()
cache.removeOldMeasurements(toRemove)
```

## Naming Conventions

### Predicates (return bool)
- `has*` - hasTextures, hasMeasurement
- `is*` - isEmpty, isFull, isValid
- `can*` - canEvict, canStore
- `would*` - wouldExceedMemory, wouldFit
- `at*` - atMaxEntries, atCapacity

### Queries (return data)
- `find*` - findOldestEntry, findByKey
- `get*` - getCachedValue, getStats
- `calculate*` - calculateSize, calculateHash
- `collect*` - collectOldEntries, collectStats

### Actions (mutate state)
- `record*` - recordHit, recordMiss
- `store*` - storeMeasurement, storeValue
- `remove*` - removeEntry, removeOld
- `clear*` - clearCache, clearEntries
- `reset*` - resetCounters, resetState
- `unload*` - unloadTexture, unloadResources
- `evict*` - evictLRU, evictOld
- `prune*` - pruneMeasurements, pruneCache

### Composition (high-level operations)
- Use descriptive verbs that describe the operation
- `measureTextCached`, `evictIfNeeded`, `clearCache`

## Function Size Guidelines

### Target: 3-10 lines per function

```nim
# Perfect: 3 lines
proc hasTextures*(cache: TextCache): bool =
  cache.textures.len > 0

# Good: 5-7 lines
proc evictLRU*(cache: var TextCache) =
  let (key, found) = cache.findOldestEntry()
  if found:
    cache.removeEntry(key)

# Acceptable: 8-10 lines (if clear)
proc findOldestEntry*(cache: TextCache): tuple[key: RenderKey, found: bool] =
  if not cache.hasTextures:
    return (RenderKey(), false)

  var oldestKey: RenderKey
  var oldestTime = getTime()
  var found = false

  for key, entry in cache.textures.pairs:
    if not found or entry.lastUsed < oldestTime:
      oldestKey = key
      oldestTime = entry.lastUsed
      found = true

  (oldestKey, found)

# Too long: 15+ lines - refactor!
```

## Cyclomatic Complexity

### Target: Complexity ≤ 5

**Complexity = 1 + (# of decision points)**

Decision points: if, elif, for, while, case, and, or

```nim
# Complexity = 1 (no decisions)
proc recordHit*(cache: var TextCache) =
  cache.hits += 1

# Complexity = 2 (one if)
proc evictLRU*(cache: var TextCache) =
  let (key, found) = cache.findOldestEntry()
  if found:  # +1
    cache.removeEntry(key)

# Complexity = 4 (three decision points)
proc cacheValue*(cache: var TextCache, key: Key, value: Value) =
  if cache.isFull():  # +1
    cache.evict()

  if cache.hasKey(key):  # +1
    cache.update(key, value)
  else:  # (elif counts as +0, part of same if)
    cache.insert(key, value)
```

If complexity > 5, factor out some conditions:

```nim
# Before: Complexity = 6
proc process(cache: var Cache, item: Item) =
  if item.isValid and cache.hasSpace:  # +2 (and)
    if item.needsProcessing:  # +1
      if item.priority > 5:  # +1
        cache.addHigh(item)
      else:
        cache.addLow(item)
    else:
      cache.addRaw(item)

# After: Complexity = 2 per function
proc canProcess*(item: Item, cache: Cache): bool =
  item.isValid and cache.hasSpace

proc isHighPriority*(item: Item): bool =
  item.priority > 5

proc process(cache: var Cache, item: Item) =
  if not cache.canProcess(item):  # +1
    return

  if item.needsProcessing:  # +1
    if item.isHighPriority():
      cache.addHigh(item)
    else:
      cache.addLow(item)
  else:
    cache.addRaw(item)
```

## Benefits

1. **Testability** - Small functions are easy to test
2. **Debuggability** - Clear where problems occur
3. **Reusability** - Small functions can be reused
4. **Readability** - Code reads like documentation
5. **Maintainability** - Easy to modify one function
6. **Composability** - Build complex from simple

## Example Refactoring Checklist

When you see a function > 20 lines:

- [ ] Factor out predicates (bool returns)
- [ ] Factor out queries (data lookups)
- [ ] Factor out calculations
- [ ] Factor out loops into collect/process pairs
- [ ] Factor out complex conditions
- [ ] Factor out repeated patterns
- [ ] Give each function ONE clear purpose
- [ ] Name functions to describe what they do
- [ ] Compose high-level functions from low-level ones

## Summary

**Forth philosophy**: Each word (function) does one thing. Complex operations are compositions of simple words.

**RUI2 practice**: Keep functions small (3-10 lines), obvious (clear names), and composable (build from simpler parts).

Result: Code that's easy to read, test, debug, and modify.
