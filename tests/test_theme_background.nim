## A theme's tiled picture behind everything (rui_drawing theme_background.nim):
## a theme file's `background:` section, its keys checked, its image path taken
## relative to the theme file, and written back by toYaml. (The tiling itself is
## checked on real pixels by tests/gl/theme_background.nim.)

import std/[unittest, options, os, strutils]
import rui
from raylib import getImageColor

proc noExtends(name: string): Theme = raise newException(ValueError, "no extends here")

suite "theme background picture":
  test "a background: section sets the picture, its opacity and scale; keys are checked":
    let t = parseTheme("""
background:
  image: paper.png
  opacity: 0.5
  scale: 2
""", tffYaml, noExtends)
    check t.assets.backgroundPattern == some("paper.png")
    check t.assets.backgroundPatternOpacity == some(0.5'f32)
    check t.assets.backgroundScale == some(2'f32)
    check t.hasBackgroundPicture
    expect ValueError:
      discard parseTheme("background:\n  picture: x.png\n", tffYaml, noExtends)

  test "toYaml writes it back; a theme without one has none":
    var t = newTheme("plain")
    check not t.hasBackgroundPicture
    t.assets.backgroundPattern = some("/tiles/wood.png")
    t.assets.backgroundScale = some(0.5'f32)
    let again = parseTheme(t.toYaml, tffYaml, noExtends)
    check again.assets.backgroundPattern == t.assets.backgroundPattern
    check again.assets.backgroundScale == t.assets.backgroundScale
    check again.assets.backgroundPatternOpacity.isNone

  test "loaded from a file, the image is relative to that file":
    let dir = getTempDir() / "rui_theme_bg"
    createDir dir
    writeFile(dir / "papery.yaml", "name: papery\nbackground:\n  image: tiles/paper.png\n")
    let t = newThemeManager().loadFromFile(dir / "papery.yaml")
    check t.assets.backgroundPattern.get == absolutePath(dir / "tiles/paper.png")

suite "background tiles that ship with rui":
  test "every tile decodes, and a name that does not ship says which do":
    check tileNames().len == 10
    for name in tileNames():
      let img = tileImage("tile:" & name)
      check img.width >= 4 and img.height >= 4
    try:
      discard tileImage("tile:marble")
      check false
    except ValueError as e:
      check "marble" in e.msg and "brick" in e.msg

  test "each tile repeats without a seam: its edges continue into each other":
    # The step across a tile's edge (last column to first, last row to first)
    # is no bigger than the steps inside it.
    proc diff(a, b: Color): int = abs(a.r.int - b.r.int) + abs(a.g.int - b.g.int) +
                                  abs(a.b.int - b.b.int) + abs(a.a.int - b.a.int)
    for name in ["wood", "wood-dark", "parchment", "paper"]:
      let img = tileImage("tile:" & name)
      var inside, across = 0
      for y in 0'i32 ..< img.height:
        across += diff(getImageColor(img, img.width - 1, y), getImageColor(img, 0, y))
        inside += diff(getImageColor(img, img.width div 2 - 1, y), getImageColor(img, img.width div 2, y))
      check across <= inside * 2

  test "see-through tiles are white on transparent, for the tint to colour":
    for name in ["halftone", "scanlines", "graph", "grid", "bubbles"]:
      let img = tileImage("tile:" & name)
      var inked, clear = 0
      for y in 0'i32 ..< img.height:
        for x in 0'i32 ..< img.width:
          let c = getImageColor(img, x, y)
          if c.a == 0: inc clear
          else:
            inc inked
            check c.r == 255 and c.g == 255 and c.b == 255
      check inked > 0 and clear > inked

  test "a brand's background, tint, opacity and scale land in its theme":
    let t = brandTheme(comicSpec())
    check t.assets.backgroundPattern == some("tile:halftone")
    check t.assets.backgroundTint == some(hex"#E63946")
    check t.assets.backgroundPatternOpacity.isSome
    check brandTheme(woodshopSpec()).assets.backgroundPattern == some("tile:wood")
    check not brandTheme(swissSpec()).hasBackgroundPicture

  test "a theme file names a tile and a tint; the tile name is not taken as a path":
    let dir = getTempDir() / "rui_theme_tile"
    createDir dir
    defer: removeDir dir
    writeFile(dir / "bricks.yaml", "name: bricks\nbackground:\n  image: tile:brick\n  tint: \"#FFEEDD\"\n")
    let t = newThemeManager().loadFromFile(dir / "bricks.yaml")
    check t.assets.backgroundPattern == some("tile:brick")
    check t.assets.backgroundTint == some(hex"#FFEEDD")
    let again = parseTheme(t.toYaml, tffYaml, noExtends)
    check again.assets.backgroundPattern == t.assets.backgroundPattern
    check again.assets.backgroundTint == t.assets.backgroundTint
