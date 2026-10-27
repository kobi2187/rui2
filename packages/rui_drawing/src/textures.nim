## Pictures from files, loaded once: shared by everything that shows one (an
## Image, an Avatar), so the same picture in twenty rows is one upload.
##
## Loading happens on the first draw, never in a constructor: building a widget
## must not need a GL context. Nothing is evicted -- naylib's Texture is
## move-only, and a picture a widget still shows must not be unloaded under it
## -- so the cache is bounded by the distinct paths an app ever shows. A path
## that fails to load is remembered and not tried again.

import std/[tables, sets]
import raylib

var
  loaded {.global.}: Table[string, Texture2D]
  failed {.global.}: HashSet[string]

proc textureFor*(path: string): ptr Texture2D =
  ## The picture at `path`, loading it the first time; nil when it cannot be
  ## loaded (no file, not a picture) or there is no window yet.
  if path.len == 0 or path in failed: return nil
  if path notin loaded:
    if not isWindowReady(): return nil
    try:
      let t = loadTexture(path)
      if t.id == 0:
        failed.incl path
        return nil
      loaded[path] = t
    except CatchableError:
      failed.incl path
      return nil
  addr loaded[path]

proc textureFailed*(path: string): bool =
  ## Tried, and could not be loaded.
  path in failed
