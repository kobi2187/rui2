## A theme's tiled picture behind everything (rui_drawing theme_background.nim):
## a theme file's `background:` section, its keys checked, its image path taken
## relative to the theme file, and written back by toYaml. (The tiling itself is
## checked on real pixels by tests/gl/theme_background.nim.)

import std/[unittest, options, os]
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

suite "background patterns made in code":
  test "a pattern key names a pattern and its ink, and reads back":
    let ink = Color(r: 0x11, g: 0x22, b: 0x33, a: 0x44)
    let key = patternKey("halftone", ink)
    check key == "pattern:halftone/#11223344"
    let (name, back, ok) = parsePattern(key)
    check ok and name == "halftone" and back == ink
    check parsePattern("pattern:grid/#FF0000").ink == Color(r: 255, g: 0, b: 0, a: 255)
    check not parsePattern("pattern:wobble/#FF0000").ok      # no such pattern
    check not parsePattern("pattern:grid/#FF00").ok          # not a colour
    check not parsePattern("paper.png").ok

  test "every pattern is a tile of ink over transparent":
    let ink = Color(r: 10, g: 20, b: 30, a: 40)
    for name in patternNames:
      let img = patternImage(name, ink)
      check img.width > 1 and img.height > 1
      var inked, clear = 0
      for y in 0'i32 ..< img.height:
        for x in 0'i32 ..< img.width:
          let c = getImageColor(img, x, y)
          if c.a == 0: inc clear
          elif c.r == ink.r and c.g == ink.g and c.b == ink.b: inc inked
      check inked > 0                 # something is drawn
      check clear > inked             # and it is a texture, not a fill

  test "a brand's pattern becomes its background picture; every one is faint or none":
    let t = brandTheme(comicSpec())
    check t.hasBackgroundPicture
    check t.assets.backgroundPattern.get.isPattern
    check parsePattern(t.assets.backgroundPattern.get).name == "halftone"
    check not brandTheme(swissSpec()).hasBackgroundPicture
    # Text sits on these: no character theme's texture is stronger than 20%
    # (blueprint's grid is drawn in a blue that is itself close to the canvas).
    for (key, theme) in characterThemes():
      if theme.hasBackgroundPicture and key != "blueprint":
        check parsePattern(theme.assets.backgroundPattern.get).ink.a <= 51

  test "a pattern key round-trips through a theme file":
    let t = brandTheme(woodshopSpec())
    let again = parseTheme(t.toYaml, tffYaml, noExtends)
    check again.assets.backgroundPattern == t.assets.backgroundPattern
