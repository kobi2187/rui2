## A theme's tiled picture behind everything (rui_drawing theme_background.nim):
## a theme file's `background:` section, its keys checked, its image path taken
## relative to the theme file, and written back by toYaml. (The tiling itself is
## checked on real pixels by tests/gl/theme_background.nim.)

import std/[unittest, options, os]
import rui

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
