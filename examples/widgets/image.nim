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

let app = newApp("RUI2 - ImageWidget", 460, 360)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 20.0).named("root")

# Write a small PPM->PNG-free sample: raylib can load a BMP we generate here.
let samplePath = getAppDir() / "sample.bmp"
if not fileExists(samplePath):
  # 64x64 BMP, 24-bit, simple gradient.
  var pixels = newSeq[uint8]()
  for y in 0 ..< 64:
    for x in 0 ..< 64:
      pixels.add uint8(x * 4)      # B
      pixels.add uint8(y * 4)      # G
      pixels.add 160'u8            # R
    # rows are already a multiple of 4 bytes (64*3 = 192)
  var header = newSeq[uint8]()
  let dataSize = pixels.len
  let fileSize = 54 + dataSize
  proc le32(v: int): seq[uint8] =
    @[uint8(v and 0xFF), uint8((v shr 8) and 0xFF),
      uint8((v shr 16) and 0xFF), uint8((v shr 24) and 0xFF)]
  header.add @[uint8('B'), uint8('M')]
  header.add le32(fileSize)
  header.add le32(0)
  header.add le32(54)
  header.add le32(40)
  header.add le32(64)
  header.add le32(64)
  header.add @[1'u8, 0'u8]          # planes
  header.add @[24'u8, 0'u8]         # bits per pixel
  header.add le32(0)
  header.add le32(dataSize)
  for _ in 0 ..< 4: header.add le32(2835)
  writeFile(samplePath, cast[string](header & pixels))

root.addChild(newLabel(text = "ImageWidget fit modes", fontSize = 16.0).named("title"))

let row = newHStack(spacing = 12.0).named("row")
for (mode, id) in [(ImageFit.Contain, "contain"),
                   (ImageFit.Fill, "fill"),
                   (ImageFit.Cover, "cover")]:
  let img = newImageWidget(imagePath = samplePath, width = 96.0,
                           height = 96.0, fitMode = mode).named(id)
  img.bounds = Rect(x: 0, y: 0, width: 96, height: 96)
  row.addChild(img)
root.addChild(row)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
