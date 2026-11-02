## Background tiles that ship with rui: small PNGs built into the program, so
## a theme can use one by name wherever it would name a picture file.
##
## ```yaml
## background:
##   image: "tile:wood"        # a tile that ships with rui
##   opacity: 0.5
## background:
##   image: textures/brick.png # or any PNG of your own, relative to the theme file
## ```
##
## Full-colour tiles: `wood` (light oak planks), `wood-dark` (walnut), `brick`,
## `parchment`, `paper`, `pinstripes`, `brushed-metal`. See-through tiles, white on transparent, coloured by
## the background's `tint`: `halftone`, `scanlines`, `graph`, `grid`, `bubbles`.
##
## They are made by tools/make_tiles.py and each repeats without a seam. A
## tile is decoded on the CPU (no window needed); textures.nim uploads it once,
## as it does a file.

import std/strutils
import raylib

const TilePrefix* = "tile:"

const tileFiles = [
  ("wood", staticRead("../tiles/wood.png")),
  ("wood-dark", staticRead("../tiles/wood-dark.png")),
  ("brick", staticRead("../tiles/brick.png")),
  ("parchment", staticRead("../tiles/parchment.png")),
  ("paper", staticRead("../tiles/paper.png")),
  ("halftone", staticRead("../tiles/halftone.png")),
  ("scanlines", staticRead("../tiles/scanlines.png")),
  ("graph", staticRead("../tiles/graph.png")),
  ("grid", staticRead("../tiles/grid.png")),
  ("bubbles", staticRead("../tiles/bubbles.png")),
  ("pinstripes", staticRead("../tiles/pinstripes.png")),
  ("brushed-metal", staticRead("../tiles/brushed-metal.png"))]

proc tileNames*(): seq[string] =
  for (name, _) in tileFiles: result.add name

proc isTile*(path: string): bool = path.startsWith(TilePrefix)

proc tileImage*(path: string): Image =
  ## The tile `tile:<name>` names, decoded. Raises ValueError for a name that
  ## does not ship.
  let name = if path.isTile: path[TilePrefix.len .. ^1] else: path
  for (n, data) in tileFiles:
    if n == name:
      return loadImageFromMemory(".png", data.toOpenArrayByte(0, data.high))
  raise newException(ValueError, "no tile called '" & name & "' ships with rui; there are " &
                     tileNames().join(", "))
