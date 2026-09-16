## MapWidget geometry — projection, panning, marker hit-testing
##
## All of this used to live inside mapwidget.nim's event handlers and render
## body, where it could only be exercised by opening a window. It is plain
## procs over plain values now, so a table of coordinates is enough.

import std/unittest
import std/math
import rui
import modern/map_projection
import modern/map_render

proc testView(zoom = 1.0, lat = 0.0, lon = 0.0): MapView =
  MapView(center: MapCoord(lat: lat, lon: lon), zoom: zoom,
          projection: mpMercator,
          originX: 0.0, originY: 0.0, width: 400.0, height: 300.0)

suite "projection":

  test "the centre coordinate lands in the middle of the widget":
    let v = testView(lat = 51.5, lon = -0.12)
    let p = v.worldToScreen(MapCoord(lat: 51.5, lon: -0.12))
    check abs(p.x - 200.0) < 0.01
    check abs(p.y - 150.0) < 0.01

  test "screenToWorld undoes worldToScreen":
    let v = testView(zoom = 4.0, lat = 40.0, lon = -74.0)
    let original = MapCoord(lat: 42.0, lon: -71.0)
    let p = v.worldToScreen(original)
    let back = v.screenToWorld(p.x, p.y)
    check abs(back.lat - original.lat) < 0.001
    check abs(back.lon - original.lon) < 0.001

  test "east is right and north is up":
    let v = testView()
    let centre = v.worldToScreen(MapCoord(lat: 0.0, lon: 0.0))
    check v.worldToScreen(MapCoord(lat: 0.0, lon: 10.0)).x > centre.x
    check v.worldToScreen(MapCoord(lat: 10.0, lon: 0.0)).y < centre.y

  test "Mercator does not blow up at the poles":
    # tan() is undefined at 90 degrees; the projection clamps to 85.05.
    let v = testView()
    let north = v.worldToScreen(MapCoord(lat: 90.0, lon: 0.0))
    check north.y.float.isNaN == false
    check north.y.float.classify != fcInf
    check north.y == v.worldToScreen(MapCoord(lat: 85.05112878, lon: 0.0)).y

  test "zooming in doubles the pixels per degree":
    let near = testView(zoom = 2.0)
    let far = testView(zoom = 1.0)
    let dNear = near.worldToScreen(MapCoord(lat: 0.0, lon: 10.0)).x - 200.0
    let dFar = far.worldToScreen(MapCoord(lat: 0.0, lon: 10.0)).x - 200.0
    check abs(dNear - dFar * 2.0) < 0.01

suite "panning":
  ## The bug this guards: unprojecting the drag through the *live* view feeds
  ## each frame's new centre into the next frame's calculation, so the map
  ## accelerates away from the pointer instead of staying stuck to it.

  test "a drag that has not moved does not move the centre":
    let v = testView(zoom = 3.0, lat = 10.0, lon = 20.0)
    let c = v.pannedCenter(v.center, 100.0, 100.0, 100.0, 100.0)
    check abs(c.lat - 10.0) < 1e-9
    check abs(c.lon - 20.0) < 1e-9

  test "dragging right moves the map west":
    let v = testView(zoom = 3.0)
    let c = v.pannedCenter(v.center, 200.0, 150.0, 260.0, 150.0)
    check c.lon < 0.0

  test "dragging down moves the map north":
    let v = testView(zoom = 3.0)
    let c = v.pannedCenter(v.center, 200.0, 150.0, 200.0, 200.0)
    check c.lat > 0.0

  test "the grabbed point stays under the pointer":
    let v = testView(zoom = 3.0, lat = 5.0, lon = 5.0)
    let grabbed = v.screenToWorld(120.0, 90.0)
    var moved = v
    moved.center = v.pannedCenter(v.center, 120.0, 90.0, 240.0, 210.0)
    let nowUnder = moved.screenToWorld(240.0, 210.0)
    check abs(nowUnder.lat - grabbed.lat) < 0.001
    check abs(nowUnder.lon - grabbed.lon) < 0.001

  test "panning past a pole clamps instead of wrapping":
    let v = testView(zoom = 1.0, lat = 80.0)
    let c = v.pannedCenter(v.center, 200.0, 300.0, 200.0, 0.0)
    check c.lat <= 90.0
    check c.lat >= -90.0

suite "marker hit-testing":
  proc marker(id: string, lat, lon: float64, size = 10.0'f32): MapMarker =
    MapMarker(id: id, coord: MapCoord(lat: lat, lon: lon), size: size,
              color: RED)

  test "nothing under the pointer is the empty id, not a crash":
    let v = testView()
    check v.markerAt([], 10.0, 10.0) == ""
    check v.markerAt([marker("a", 0.0, 0.0)], 5.0, 5.0) == ""

  test "a marker at the centre is found at the centre":
    let v = testView()
    check v.markerAt([marker("a", 0.0, 0.0)], 200.0, 150.0) == "a"

  test "the hit box is at least 8px even for a tiny marker":
    let v = testView()
    let tiny = [marker("t", 0.0, 0.0, size = 1.0'f32)]
    check v.markerAt(tiny, 206.0, 150.0) == "t"
    check v.markerAt(tiny, 216.0, 150.0) == ""

  test "the first matching marker wins when two overlap":
    let v = testView()
    check v.markerAt([marker("first", 0.0, 0.0), marker("second", 0.0, 0.0)],
                     200.0, 150.0) == "first"

suite "map drawing helpers":

  test "a highlighted marker is a quarter larger":
    let m = MapMarker(id: "a", size: 12.0)
    check markerRadius(m, highlighted = false) == 12.0'f32
    check markerRadius(m, highlighted = true) == 15.0'f32

  test "a marker with no size of its own gets the default":
    let m = MapMarker(id: "a", size: 0.0)
    check markerRadius(m, highlighted = false) == 10.0'f32

  test "the readout says lat, lon and zoom":
    check coordinateReadout(51.5074, -0.1278, 12.0) == "51.5074, -0.1278  z12.0"

  test "visibility is inclusive of the edges":
    let b = Rect(x: 0, y: 0, width: 100, height: 100)
    check Point(x: 0.0, y: 0.0).isVisible(b)
    check Point(x: 100.0, y: 100.0).isVisible(b)
    check not Point(x: 101.0, y: 50.0).isVisible(b)
