## MapWidget
##
## Pan, zoom and markers over a graticule. No tiles are fetched -- draw tiles
## before the markers in `render` to point this at a tile server.
##
##   nim c -r -d:useGraphics examples/widgets/map.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, json, strutils]

let app = newApp("RUI2 - Map", 720, 520)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 10.0, padding = 16.0).named("root")
let summary = newLabel(text = "drag to pan, scroll or +/- to zoom",
                       fontSize = 15.0).named("summary")
root.addChild(summary)

proc report(text: string) =
  summary.text = text
  summary.isDirty = true
  summary.layoutDirty = true

let map = newMapWidget(initialCenter = MapCoord(lat: 20.0, lon: 0.0),
                       initialZoom = 2.0, minZoom = 1.0, maxZoom = 12.0,
                       projection = mpMercator, markerShape = msPin,
                       showCoordinates = true, showZoomControls = true,
                       gridLines = true).named("map")
map.bounds = Rect(x: 0, y: 0, width: 680, height: 400)

for (id, title, lat, lon) in [("lon", "London", 51.5074, -0.1278),
                              ("nyc", "New York", 40.7128, -74.0060),
                              ("tky", "Tokyo", 35.6762, 139.6503),
                              ("syd", "Sydney", -33.8688, 151.2093),
                              ("nbo", "Nairobi", -1.2921, 36.8219)]:
  map.addMarker(MapMarker(
    id: id, coord: MapCoord(lat: lat, lon: lon), title: title,
    color: Color(r: 220, g: 70, b: 70, a: 255), size: 8.0, data: newJObject()))

map.onMarkerClick = proc(marker: MapMarker) =
  report(marker.title & " @ " &
         formatFloat(marker.coord.lat, ffDecimal, 3) & ", " &
         formatFloat(marker.coord.lon, ffDecimal, 3))

map.onZoomChanged = proc(newZoom: float) =
  report("zoom " & formatFloat(newZoom, ffDecimal, 1))

root.addChild(map)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
