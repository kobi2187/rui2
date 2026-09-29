## ImageWidget
##
## Displaying an image file, with the fit modes. Generates its own sample
## image on first run so the example is self-contained.
##
##   nim c -r -d:useGraphics examples/widgets/image.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]
from raylib import genImageGradientLinear, exportImage

let app = newApp("RUI2 - ImageWidget", 460, 360)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

# A generated sample, so the example needs no asset. PNG, not BMP: the raylib
# naylib builds has no BMP loader, which is why this used to show "Load
# failed" three times. Twice as wide as it is tall, so the fit modes differ.
let samplePath = getAppDir() / "sample.png"
if not fileExists(samplePath):
  let sample = genImageGradientLinear(128, 64, 90,
                                      Color(r: 60, g: 110, b: 200, a: 255),
                                      Color(r: 240, g: 170, b: 60, a: 255))
  discard exportImage(sample, samplePath)

root.addChild(newLabel(text = "ImageWidget fit modes", fontSize = 16.0).named("title"))

let row = newHStack(spacing = 12.0).named("row")
for (mode, id) in [(ImageFit.Contain, "contain"),
                   (ImageFit.Fill, "fill"),
                   (ImageFit.Cover, "cover")]:
  let img = newImageWidget(imagePath = samplePath, width = 96.0,
                           height = 96.0, fitMode = mode).named(id).frame(width = 96, height = 96)
  row.addChild(img)
root.addChild(row)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
